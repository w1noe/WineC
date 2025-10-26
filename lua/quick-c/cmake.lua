local U = require('quick-c.util')
local M = {}

local function choose_cmake(config)
  local pref = (config.cmake or {}).prefer
  local function is_exec(x) return x and vim.fn.executable(x) == 1 end
  if type(pref) == 'string' and pref ~= '' then
    if is_exec(pref) then return pref end
  end
  if is_exec('cmake') then return 'cmake' end
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
  local cfg = (config.cmake or {}).search or {}
  local up = tonumber(cfg.up) or 2
  local down = tonumber(cfg.down) or 3
  local ignore = cfg.ignore_dirs or { '.git', 'node_modules', '.cache' }
  local uv = vim.loop

  local seen = {}
  local function is_ignored(name)
    for _, n in ipairs(ignore) do if name == n then return true end end
    return false
  end
  local function parent(dir)
    local p = vim.fn.fnamemodify(dir, ':h')
    if p == nil or p == '' then return dir end
    return p
  end

  local cwd_root = U.norm(vim.fn.getcwd())
  local bases = {}
  do
    local cur = start_dir
    for _ = 0, up do
      local cur_norm = U.norm(cur)
      if not cur_norm:find(cwd_root, 1, true) then break end
      table.insert(bases, cur)
      local nextp = parent(cur)
      if nextp == cur then break end
      local next_norm = U.norm(nextp)
      if #next_norm < #cwd_root or not next_norm:find(cwd_root, 1, true) then break end
      cur = nextp
    end
  end

  local queue = {}
  for _, b in ipairs(bases) do table.insert(queue, { dir = b, depth = 0 }) end

  local function scandir_async(dir, ondone)
    uv.fs_scandir(dir, function(err, req)
      if err or not req then ondone({}) return end
      local out = {}
      while true do
        local name, t = uv.fs_scandir_next(req)
        if not name then break end
        out[#out + 1] = { name = name, type = t }
      end
      ondone(out)
    end)
  end

  local scanning = false
  local found = false
  local function step()
    if scanning or found then return end
    scanning = true
    local item = table.remove(queue, 1)
    if not item then scanning = false cb(start_dir) return end
    local dir, depth = item.dir, item.depth
    if find_cmakelists(dir) then scanning = false found = true cb(dir) return end
    if depth < down then
      scandir_async(dir, function(entries)
        for _, e in ipairs(entries) do
          if e.type == 'directory' then
            if not is_ignored(e.name) then
              local subdir = U.join(dir, e.name)
              local key = U.norm(subdir)
              if not seen[key] then seen[key] = true table.insert(queue, { dir = subdir, depth = depth + 1 }) end
            else
              local subdir = U.join(dir, e.name)
              if find_cmakelists(subdir) then scanning = false found = true cb(subdir) return end
            end
          end
        end
        scanning = false
        if not found then vim.defer_fn(step, 1) end
      end)
    else
      scanning = false
      if not found then vim.defer_fn(step, 1) end
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
  if not b or b == '' then b = 'build' end
  if b:sub(1,1) == '/' or b:match('^%a:[\\/]') or b:match('^[\\/]') then
    return b
  end
  return U.join(root, b)
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
  if gen and gen ~= '' then table.insert(args, '-G'); table.insert(args, gen) end
  local conf = (config.cmake or {}).configure or {}
  if conf.toolchain and conf.toolchain ~= '' then
    table.insert(args, '-DCMAKE_TOOLCHAIN_FILE=' .. conf.toolchain)
  end
  for _, ex in ipairs(conf.extra or {}) do table.insert(args, ex) end
  return args
end

function M.ensure_configured_async(config, root, on_done)
  local bdir = build_dir_for(config, root)
  if is_configured(config, root) then on_done(true, bdir) return end
  vim.fn.mkdir(bdir, 'p')
  local cmd = configure_args(config, root, bdir)
  local all = {}
  local ok = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, d) if d then for _, l in ipairs(d) do table.insert(all, l) end end end,
    on_stderr = function(_, d) if d then for _, l in ipairs(d) do table.insert(all, l) end end end,
    on_exit = function(_, code)
      if code == 0 then on_done(true, bdir) else on_done(false, bdir, all) end
    end,
  })
  if ok <= 0 then on_done(false, bdir, { 'failed to start cmake configure' }) end
end

local function cmake_build_cmd(config, bdir, target, extra)
  local cm = choose_cmake(config) or 'cmake'
  local args = { cm, '--build', bdir }
  if target and target ~= '' then table.insert(args, '--target'); table.insert(args, target) end
  if extra and extra ~= '' then
    -- pass extra after a separator if needed; keep simple: append as one string will be tokenized by shell
    table.insert(args, '--')
    for tok in tostring(extra):gmatch('%S+') do table.insert(args, tok) end
  end
  return args
end

function M.build_in_root(config, root, target, run_terminal)
  M.ensure_configured_async(config, root, function(ok, bdir, _)
    if not ok then U.notify_err('CMake 配置失败') return end
    local cmargs = (config.cmake and config.cmake.args) or {}
    local extra = ''
    if cmargs.prompt ~= false then
      local def = cmargs.default or ''
      local key = U.norm(bdir)
      vim.g.quick_c_cmake_last_args = vim.g.quick_c_cmake_last_args or {}
      if cmargs.remember ~= false then def = vim.g.quick_c_cmake_last_args[key] or def end
      local ui = vim.ui or {}
      if ui.input then
        ui.input({ prompt = 'cmake 构建参数: ', default = def }, function(arg)
          if cmargs.remember ~= false and arg and arg ~= '' then vim.g.quick_c_cmake_last_args[key] = arg end
          local cmd = table.concat(cmake_build_cmd(config, bdir, target, arg or ''), ' ')
          run_terminal(cmd)
        end)
        return
      end
    end
    local cmd = table.concat(cmake_build_cmd(config, bdir, target, extra), ' ')
    run_terminal(cmd)
  end)
end

function M.run_build_from_current(config, target, run_terminal)
  local base = vim.fn.fnamemodify(vim.fn.expand('%:p'), ':h')
  resolve_root_async(config, base, function(root)
    M.build_in_root(config, root, target, run_terminal)
  end)
end

function M.configure_from_current(config, notify)
  local base = vim.fn.fnamemodify(vim.fn.expand('%:p'), ':h')
  resolve_root_async(config, base, function(root)
    M.ensure_configured_async(config, root, function(ok)
      if ok then notify.info('CMake 配置完成') else notify.err('CMake 配置失败') end
    end)
  end)
end

-- List build targets by invoking generator help
local function parse_targets_from_help(lines)
  local seen, out = {}, {}
  local function add(name)
    if not name or name == '' then return end
    if not seen[name] then seen[name] = true table.insert(out, name) end
  end
  for _, l in ipairs(lines or {}) do
    if type(l) ~= 'string' then goto continue end
    local s = l:gsub('^%s+', '')
    local a = s:match('^%.+%s+([%w%._%-%+/]+)')
    if a then add(a:gsub(':.*$', '')) goto continue end
    local b = s:match("^target%s+'([^']+)'") or s:match('^target%s+"([^"]+)"')
    if b then add(b) goto continue end
    local c = s:match('^([%w%._%-%+/]+)%s*:%s*')
    if c and c ~= 'all' and c ~= 'help' then add(c) goto continue end
    ::continue::
  end
  table.sort(out)
  return out
end

function M.list_targets_async(config, root, cb)
  M.ensure_configured_async(config, root, function(ok, bdir)
    if not ok then cb({}) return end
    local cmd = { choose_cmake(config) or 'cmake', '--build', bdir, '--target', 'help' }
    local lines = {}
    local jid = vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, d) if d then for _, l in ipairs(d) do table.insert(lines, l) end end end,
      on_stderr = function(_, d) if d then for _, l in ipairs(d) do table.insert(lines, l) end end end,
      on_exit = function()
        local targets = parse_targets_from_help(lines)
        cb(targets)
      end,
    })
    if jid <= 0 then cb({}) end
  end)
end

M.choose_cmake = choose_cmake
M.build_dir_for = build_dir_for
M.resolve_root_async = resolve_root_async
M.list_targets_async = M.list_targets_async

return M
