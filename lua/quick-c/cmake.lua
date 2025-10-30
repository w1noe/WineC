local U = require 'quick-c.util'
local M = {}

local _cache = {
  root = {},
  targets = {},
}
local _watchers = {}
local function _now()
  return vim.loop.now() / 1000
end

local function _config_stamp(bdir)
  local uv = vim.loop
  local cache = U.join(bdir, 'CMakeCache.txt')
  local st = uv.fs_stat(cache)
  if st and st.mtime then
    return tostring(st.mtime.sec or st.mtime)
  end
  local dir = U.join(bdir, 'CMakeFiles')
  st = uv.fs_stat(dir)
  if st and st.mtime then
    return tostring(st.mtime.sec or st.mtime)
  end
  return '0'
end
local function _ttl()
  return 10
end

local function choose_cmake(config)
  local pref = (config.cmake or {}).prefer
  local function is_exec(x)
    return x and vim.fn.executable(x) == 1
  end
  if type(pref) == 'string' and pref ~= '' then
    if is_exec(pref) then
      return pref
    end
  end
  if is_exec 'cmake' then
    return 'cmake'
  end
  return nil
end

local function stat_file(p)
  local st = vim.loop.fs_stat(p)
  return st and st.type == 'file'
end

local function find_cmakelists(dir)
  local p = U.join(dir, 'CMakeLists.txt')
  return stat_file(p) and p or nil
end

-- Async, breadth-first limited search similar to make_search but simplified
function M.find_root_async(config, start_dir, cb)
  local key = U.norm(start_dir)
  local ent = _cache.root[key]
  if ent and (_now() - ent.t) < _ttl() then
    cb(ent.v)
    return
  end
  local cfg = (config.cmake or {}).search or {}
  local up = tonumber(cfg.up) or 2
  local down = tonumber(cfg.down) or 3
  local ignore = cfg.ignore_dirs or { '.git', 'node_modules', '.cache' }
  local uv = vim.loop

  local seen = {}
  local function is_ignored(name)
    for _, n in ipairs(ignore) do
      if name == n then
        return true
      end
    end
    return false
  end
  local function parent(dir)
    local p = vim.fn.fnamemodify(dir, ':h')
    if p == nil or p == '' then
      return dir
    end
    return p
  end

  local cwd_root = U.norm(vim.fn.getcwd())
  local bases = {}
  do
    local cur = start_dir
    for _ = 0, up do
      local cur_norm = U.norm(cur)
      if not cur_norm:find(cwd_root, 1, true) then
        break
      end
      table.insert(bases, cur)
      local nextp = parent(cur)
      if nextp == cur then
        break
      end
      local next_norm = U.norm(nextp)
      if #next_norm < #cwd_root or not next_norm:find(cwd_root, 1, true) then
        break
      end
      cur = nextp
    end
  end

  local queue = {}
  for _, b in ipairs(bases) do
    table.insert(queue, { dir = b, depth = 0 })
  end

  local function scandir_async(dir, ondone)
    uv.fs_scandir(dir, function(err, req)
      if err or not req then
        ondone {}
        return
      end
      local out = {}
      while true do
        local name, t = uv.fs_scandir_next(req)
        if not name then
          break
        end
        out[#out + 1] = { name = name, type = t }
      end
      ondone(out)
    end)
  end

  local scanning = false
  local found = false
  local batch_size = 40
  -- 并发工作者数：优先 cmake.concurrency，其次 debug.concurrency，最后默认 8
  local parallel = tonumber((config.cmake and config.cmake.concurrency)
    or (config.debug and config.debug.concurrency)
    or 8) or 8
  local function step()
    if scanning or found then
      return
    end
    scanning = true
    local taken = {}
    local n = math.min(batch_size, #queue, parallel)
    for i = 1, n do
      taken[i] = table.remove(queue, 1)
    end
    if #taken == 0 then
      scanning = false
      _cache.root[key] = { v = start_dir, t = _now() }
      cb(start_dir)
      return
    end
    local pending = #taken
    local function on_one_done()
      pending = pending - 1
      if pending == 0 then
        scanning = false
        if not found then
          if #queue == 0 then
            _cache.root[key] = { v = start_dir, t = _now() }
            cb(start_dir)
          else
            vim.defer_fn(step, 1)
          end
        end
      end
    end
    for _, item in ipairs(taken) do
      local dir, depth = item.dir, item.depth
      if find_cmakelists(dir) then
        found = true
        scanning = false
        _cache.root[key] = { v = dir, t = _now() }
        cb(dir)
        return
      end
      if depth < down then
        scandir_async(dir, function(entries)
          if found then
            on_one_done()
            return
          end
          for _, e in ipairs(entries) do
            if e.type == 'directory' then
              if not is_ignored(e.name) then
                local subdir = U.join(dir, e.name)
                local k2 = U.norm(subdir)
                if not seen[k2] then
                  seen[k2] = true
                  table.insert(queue, { dir = subdir, depth = depth + 1 })
                end
              else
                local subdir = U.join(dir, e.name)
                if find_cmakelists(subdir) then
                  found = true
                  scanning = false
                  _cache.root[key] = { v = subdir, t = _now() }
                  cb(subdir)
                  return
                end
              end
            end
          end
          on_one_done()
        end)
      else
        on_one_done()
      end
    end
  end
  step()
end

local function resolve_root_async(config, base_dir, cb)
  M.find_root_async(config, base_dir, function(root)
    cb(root or base_dir)
  end)
end

local function build_dir_for(config, root)
  local b = (config.cmake and config.cmake.build_dir) or 'build'
  if not b or b == '' then
    b = 'build'
  end
  if b:sub(1, 1) == '/' or b:match '^%a:[\\/]' or b:match '^[\\/]' then
    return b
  end
  return U.join(root, b)
end

local function ensure_cmake_watcher(config, root)
  if not root then
    return
  end
  local key = U.norm(root)
  if _watchers[key] then
    return
  end
  local uv = vim.loop
  local h = uv.new_fs_event()
  local ok = pcall(uv.fs_event_start, h, root, {}, function(err, fname)
    if err then
      return
    end
    if fname == 'CMakeLists.txt' then
      local bdir = build_dir_for(config, root)
      local k = U.norm(bdir)
      _cache.targets[k] = nil
    end
  end)
  if not ok then
    pcall(function()
      h:close()
    end)
    return
  end
  _watchers[key] = h
end

local function is_configured(config, root)
  local bdir = build_dir_for(config, root)
  return stat_file(U.join(bdir, 'CMakeCache.txt'))
end

local function configure_args(config, root, bdir)
  local args = { 'cmake', '-S', root, '-B', bdir }
  local cm = choose_cmake(config) or 'cmake'
  args[1] = cm
  local gen = (config.cmake or {}).generator
  if gen and gen ~= '' then
    table.insert(args, '-G')
    table.insert(args, gen)
  end
  local conf = (config.cmake or {}).configure or {}
  if conf.toolchain and conf.toolchain ~= '' then
    table.insert(args, '-DCMAKE_TOOLCHAIN_FILE=' .. conf.toolchain)
  end
  for _, ex in ipairs(conf.extra or {}) do
    table.insert(args, ex)
  end
  return args
end

function M.ensure_configured_async(config, root, on_done)
  local bdir = build_dir_for(config, root)
  if is_configured(config, root) then
    on_done(true, bdir)
    return
  end
  -- Schedule mkdir/jobstart to avoid E5560 in fast event context
  vim.schedule(function()
    pcall(vim.fn.mkdir, bdir, 'p')
    local cmd = configure_args(config, root, bdir)
    local all = {}
    local ok = vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, d)
        if d then
          for _, l in ipairs(d) do
            table.insert(all, l)
          end
        end
      end,
      on_stderr = function(_, d)
        if d then
          for _, l in ipairs(d) do
            table.insert(all, l)
          end
        end
      end,
      on_exit = function(_, code)
        if code == 0 then
          on_done(true, bdir)
        else
          on_done(false, bdir, all)
        end
      end,
    })
    if ok <= 0 then
      on_done(false, bdir, { 'failed to start cmake configure' })
    end
  end)
end

local function cmake_build_cmd(config, bdir, target, extra)
  local cm = choose_cmake(config) or 'cmake'
  local args = { cm, '--build', bdir }
  if target and target ~= '' then
    table.insert(args, '--target')
    table.insert(args, target)
  end
  if extra and extra ~= '' then
    -- pass extra after a separator if needed; keep simple: append as one string will be tokenized by shell
    table.insert(args, '--')
    for tok in tostring(extra):gmatch '%S+' do
      table.insert(args, tok)
    end
  end
  return args
end

function M.build_in_root(config, root, target, run_terminal)
  -- Guard: if no CMakeLists.txt found, warn and return early
  if not find_cmakelists(root) then
    U.notify_warn('未检测到 CMakeLists.txt，当前目录不是 CMake 项目: ' .. tostring(root))
    return
  end
  M.ensure_configured_async(config, root, function(ok, bdir, _)
    if not ok then
      U.notify_err 'CMake 配置失败'
      return
    end
    local cmargs = (config.cmake and config.cmake.args) or {}
    local extra = ''
    local function proceed(arg_extra)
      local args = cmake_build_cmd(config, bdir, target, arg_extra or '')
      local diagcfg = (config.diagnostics and config.diagnostics.quickfix) or {}
      local qf_enabled = (diagcfg.enabled ~= false)
      local view = (config.cmake and config.cmake.view) or 'quickfix'
      if (view == 'terminal') or not qf_enabled then
        local cmdline = table.concat(args, ' ')
        run_terminal(cmdline)
        return
      end
      local all = {}
      local view_mode = view -- 'quickfix' | 'both'
      local outbuf, outwin
      if view_mode == 'both' then
        local outcfg = (config.cmake and config.cmake.output) or {}
        local open = (outcfg.open ~= false)
        local height = tonumber(outcfg.height) or 12
        local name = 'Quick-c: CMake Output'
        local bufnr = vim.fn.bufnr(name)
        if bufnr == -1 or not vim.api.nvim_buf_is_valid(bufnr) then
          outbuf = vim.api.nvim_create_buf(true, false)
          pcall(vim.api.nvim_buf_set_name, outbuf, name)
        else
          outbuf = bufnr
          -- 清空旧内容
          pcall(vim.api.nvim_buf_set_lines, outbuf, 0, -1, false, {})
        end
        -- 设置 buffer 选项
        pcall(vim.api.nvim_buf_set_option, outbuf, 'buftype', 'nofile')
        pcall(vim.api.nvim_buf_set_option, outbuf, 'bufhidden', 'wipe')
        pcall(vim.api.nvim_buf_set_option, outbuf, 'swapfile', false)
        if open then
          local winid = vim.fn.bufwinnr(outbuf)
          if winid ~= -1 then
            outwin = vim.fn.win_getid(winid)
          else
            vim.cmd('botright ' .. height .. 'split')
            outwin = vim.api.nvim_get_current_win()
            vim.api.nvim_win_set_buf(outwin, outbuf)
          end
        end
      end
      local function append_lines(chunk)
        if not chunk or #chunk == 0 then
          return
        end
        for _, l in ipairs(chunk) do
          table.insert(all, l)
        end
        if outbuf and vim.api.nvim_buf_is_valid(outbuf) then
          local existing = vim.api.nvim_buf_line_count(outbuf)
          vim.api.nvim_buf_set_lines(outbuf, existing, existing, false, chunk)
          if outwin and vim.api.nvim_win_is_valid(outwin) then
            vim.api.nvim_win_set_cursor(outwin, { vim.api.nvim_buf_line_count(outbuf), 0 })
          end
        end
      end
      local jid = vim.fn.jobstart(args, {
        stdout_buffered = false,
        stderr_buffered = false,
        on_stdout = function(_, d)
          append_lines(d)
        end,
        on_stderr = function(_, d)
          append_lines(d)
        end,
        on_exit = function(_, code)
          -- parse diagnostics (gcc/clang/msvc)
          local items, has_error, has_warning = U.parse_diagnostics(all)
          if #items > 0 then
            vim.fn.setqflist({}, ' ', { title = 'Quick-c CMake Build', items = items })
            local function should_open()
              if diagcfg.open == 'always' then
                return true
              end
              if diagcfg.open == 'error' and has_error then
                return true
              end
              if diagcfg.open == 'warning' and (has_error or has_warning) then
                return true
              end
              return false
            end
            local function should_jump()
              if diagcfg.jump == 'always' then
                return true
              end
              if diagcfg.jump == 'error' and has_error then
                return true
              end
              if diagcfg.jump == 'warning' and (has_error or has_warning) then
                return true
              end
              return false
            end
            if should_open() then
              if diagcfg.use_telescope then
                local ok_tb, tb = pcall(require, 'telescope.builtin')
                if ok_tb then
                  tb.quickfix()
                else
                  vim.cmd 'copen'
                end
              else
                vim.cmd 'copen'
              end
            end
            if should_jump() then
              local cur = vim.api.nvim_get_current_buf()
              local name = vim.api.nvim_buf_get_name(cur)
              local modified = false
              pcall(function()
                modified = vim.api.nvim_buf_get_option(cur, 'modified')
              end)
              if not (name == '' and modified) then
                pcall(vim.cmd, 'silent! keepalt keepjumps cc')
              end
            end
          else
            if code == 0 then
              vim.fn.setqflist {}
            end
          end
          if code == 0 then
            U.notify_info 'CMake Build OK'
          else
            U.notify_err('CMake Build failed (' .. code .. ')')
          end
        end,
      })
      if jid <= 0 then
        -- fallback to terminal
        local cmdline = table.concat(args, ' ')
        run_terminal(cmdline)
      end
    end
    if cmargs.prompt ~= false then
      local def = cmargs.default or ''
      local key = U.norm(bdir)
      vim.g.quick_c_cmake_last_args = vim.g.quick_c_cmake_last_args or {}
      if cmargs.remember ~= false then
        def = vim.g.quick_c_cmake_last_args[key] or def
      end
      local ui = vim.ui or {}
      if ui.input then
        ui.input({ prompt = 'cmake 构建参数: ', default = def }, function(arg)
          if cmargs.remember ~= false and arg and arg ~= '' then
            vim.g.quick_c_cmake_last_args[key] = arg
          end
          proceed(arg)
        end)
        return
      end
    end
    proceed(extra)
  end)
end

function M.run_build_from_current(config, target, run_terminal)
  local base = vim.fn.fnamemodify(vim.fn.expand '%:p', ':h')
  resolve_root_async(config, base, function(root)
    M.build_in_root(config, root, target, run_terminal)
  end)
end

function M.configure_from_current(config, notify)
  local ninfo = (type(notify) == 'table' and notify.info) or U.notify_info
  local nerr = (type(notify) == 'table' and notify.err) or U.notify_err
  local base = vim.fn.fnamemodify(vim.fn.expand '%:p', ':h')
  resolve_root_async(config, base, function(root)
    M.ensure_configured_async(config, root, function(ok)
      if ok then
        ninfo 'CMake 配置完成'
      else
        nerr 'CMake 配置失败'
      end
    end)
  end)
end

-- List build targets by invoking generator help
local function parse_targets_from_help(lines)
  local seen, out = {}, {}
  local function add(name)
    if not name or name == '' then
      return
    end
    if not seen[name] then
      seen[name] = true
      table.insert(out, name)
    end
  end
  for _, l in ipairs(lines or {}) do
    if type(l) ~= 'string' then
      goto continue
    end
    local s = l:gsub('^%s+', '')
    local a = s:match '^%.+%s+([%w%._%-%+/]+)'
    if a then
      add(a:gsub(':.*$', ''))
      goto continue
    end
    local b = s:match "^target%s+'([^']+)'" or s:match '^target%s+"([^"]+)"'
    if b then
      add(b)
      goto continue
    end
    local c = s:match '^([%w%._%-%+/]+)%s*:%s*'
    if c and c ~= 'all' and c ~= 'help' then
      add(c)
      goto continue
    end
    ::continue::
  end
  table.sort(out)
  return out
end

function M.list_targets_async(config, root, cb)
  ensure_cmake_watcher(config, root)
  M.ensure_configured_async(config, root, function(ok, bdir)
    if not ok then
      cb {}
      return
    end
    local k = U.norm(bdir)
    local cur_stamp = _config_stamp(bdir)
    local ent = _cache.targets[k]
    if ent and ent.stamp == cur_stamp and (_now() - ent.t) < _ttl() then
      cb(ent.v)
      return
    end
    local cmd = { choose_cmake(config) or 'cmake', '--build', bdir, '--target', 'help' }
    local lines = {}
    local jid = vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, d)
        if d then
          for _, l in ipairs(d) do
            table.insert(lines, l)
          end
        end
      end,
      on_stderr = function(_, d)
        if d then
          for _, l in ipairs(d) do
            table.insert(lines, l)
          end
        end
      end,
      on_exit = function()
        local targets = parse_targets_from_help(lines)
        _cache.targets[k] = { v = targets, t = _now(), stamp = cur_stamp }
        cb(targets)
      end,
    })
    if jid <= 0 then
      cb {}
    end
  end)
end

M.choose_cmake = choose_cmake
M.build_dir_for = build_dir_for
M.resolve_root_async = resolve_root_async
return M
