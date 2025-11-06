local U = require 'quick-c.util'
local T = require 'quick-c.terminal'
local TASK = require 'quick-c.task'
local B = {}
local NAME_CACHE = {}
local LAST_EXE = {}
local LAST_COMPILE_ARGS = {}

local function cleanup_build_logs(base, max_keep)
  local uv = vim.loop
  local ok, req = pcall(uv.fs_scandir, base)
  if not ok or not req then
    return
  end
  local files = {}
  while true do
    local name, t = uv.fs_scandir_next(req)
    if not name then
      break
    end
    if t == 'file' then
      if name ~= 'latest-build.log' and name:match('^build%-.+%.log$') then
        local p = U.join(base, name)
        local st = uv.fs_stat(p) or {}
        local m = (st.mtime and (st.mtime.sec or st.mtime)) or 0
        table.insert(files, { path = p, mtime = m })
      end
    end
  end
  table.sort(files, function(a, b)
    return (a.mtime or 0) > (b.mtime or 0)
  end)
  for i = max_keep + 1, #files do
    pcall(vim.fn.delete, files[i].path)
  end
end

local function write_build_logs(lines)
  local base = vim.fn.stdpath('data') .. '/quick-c/logs'
  vim.fn.mkdir(base, 'p')
  local ts = os.date('%Y%m%d-%H%M%S')
  local latest = base .. '/latest-build.log'
  local dated = base .. '/build-' .. ts .. '.log'
  pcall(vim.fn.writefile, lines, latest)
  pcall(vim.fn.writefile, lines, dated)
  cleanup_build_logs(base, 50)
end

local function ensure_outdir(dir)
  vim.fn.mkdir(dir, 'p')
end

local function sources_key(sources)
  local list = {}
  for _, s in ipairs(sources or {}) do
    table.insert(list, vim.fn.fnamemodify(s, ':p'))
  end
  table.sort(list)
  return table.concat(list, ';')
end

local function gather_sources()
  return { vim.fn.expand '%:p' }
end

local function norm_abs(p)
  if not p or p == '' then
    return nil
  end
  return vim.fn.fnamemodify(p, ':p')
end

local function from_opts_sources(opts)
  if not opts or type(opts) ~= 'table' or not opts.sources then
    return nil
  end
  local list = {}
  for _, s in ipairs(opts.sources) do
    local abs = norm_abs(s)
    if abs and vim.fn.filereadable(abs) == 1 then
      table.insert(list, abs)
    end
  end
  if #list > 0 then
    return list
  end
  return nil
end

local function detect_ft_from_sources(sources)
  -- if any cpp-like file, treat as cpp; else c
  for _, s in ipairs(sources or {}) do
    local ext = (s:match '%.(%w+)$' or ''):lower()
    if ext == 'cpp' or ext == 'cc' or ext == 'cxx' or ext == 'hpp' then
      return 'cpp'
    end
  end
  return 'c'
end

local function default_out_name(is_win, sources)
  local ext = is_win and '.exe' or ''
  if #sources == 1 then
    local base = vim.fn.fnamemodify(sources[1], ':t:r')
    return base .. ext
  else
    local name = 'a.out'
    if is_win and not name:match '%.exe$' then
      name = name .. '.exe'
    end
    return name
  end
end

local function scandir_files(dir)
  local uv = vim.loop
  local ok, req = pcall(uv.fs_scandir, dir)
  if not ok or not req then
    return {}
  end
  local out = {}
  while true do
    local name, t = uv.fs_scandir_next(req)
    if not name then
      break
    end
    if t == 'file' then
      table.insert(out, U.join(dir, name))
    end
  end
  return out
end

-- Async parallel BFS to discover candidate executables
local function discover_candidates_async(config, is_win, start_dir, cb)
  local dbg = (config.debug or {})
  local search = dbg.search or {}
  local up = tonumber(search.up) or 2
  local down = tonumber(search.down) or 2
  local ignore = search.ignore_dirs or { '.git', 'node_modules', '.cache' }
  local concurrency = tonumber(dbg.concurrency) or 8
  local uv = vim.loop
  local seen_dir = {}
  local function is_ignored(name)
    for _, n in ipairs(ignore) do
      if n == name then
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
  local bases = {}
  local preferred = (search and type(search.dirs) == 'table') and search.dirs or nil
  if preferred and #preferred > 0 then
    for _, d in ipairs(preferred) do
      local p = vim.fn.fnamemodify(d, ':p')
      local st = uv.fs_stat(p)
      if st and st.type == 'directory' then
        table.insert(bases, p)
      end
    end
  end
  if #bases == 0 then
    local cwd = vim.fn.getcwd()
    local cwd_root = U.norm(cwd)
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
    for _, d in ipairs { 'build', 'bin', 'out' } do
      table.insert(bases, U.join(cwd, d))
    end
    local outdir = config.outdir
    if outdir and outdir ~= '' and outdir ~= 'source' then
      table.insert(bases, outdir)
    end
  end

  local queue = {}
  for _, b in ipairs(bases) do
    table.insert(queue, { dir = b, depth = 0 })
  end
  local active = 0
  local candidates = {}
  local seen_file = {}
  local function add_file(p)
    local abs = vim.fn.fnamemodify(p, ':p')
    if vim.fn.filereadable(abs) == 1 and not seen_file[abs] then
      seen_file[abs] = true
      table.insert(candidates, abs)
    end
  end
  local function handle_dir(dir, depth)
    active = active + 1
    uv.fs_scandir(dir, function(err, req)
      if not err and req then
        while true do
          local name, t = uv.fs_scandir_next(req)
          if not name then
            break
          end
          if t == 'file' then
            local p = U.join(dir, name)
            if is_win then
              if name:lower():match '%.exe$' then
                add_file(p)
              end
            else
              if name == 'a.out' or not name:match '%.%w+$' then
                add_file(p)
              end
            end
          elseif t == 'directory' and depth < down then
            if not is_ignored(name) then
              local sub = U.join(dir, name)
              local key = U.norm(sub)
              if not seen_dir[key] then
                seen_dir[key] = true
                table.insert(queue, { dir = sub, depth = depth + 1 })
              end
            else
              -- first-layer probe of ignored dir root
              local sub = U.join(dir, name)
              local key = U.norm(sub)
              if not seen_dir[key] then
                seen_dir[key] = true
                table.insert(queue, { dir = sub, depth = depth + 1 })
              end
            end
          end
        end
      end
      active = active - 1
      vim.schedule(function()
        while active < concurrency and #queue > 0 do
          local item = table.remove(queue, 1)
          handle_dir(item.dir, item.depth)
        end
        if active == 0 and #queue == 0 then
          cb(candidates)
        end
      end)
    end)
  end
  -- start workers
  for i = 1, math.min(concurrency, #queue) do
    local item = table.remove(queue, 1)
    handle_dir(item.dir, item.depth)
  end
  if #queue == 0 and active == 0 then
    cb(candidates)
  end
end

local function choose_compiler(config, is_win, ft)
  local function family_of(name)
    if not name or name == '' then
      return nil
    end
    if name == 'cl' then
      return 'cl'
    end
    if name:find 'clang' then
      return 'clang'
    end
    if name:find 'gcc' or name:find 'g%+%+' then
      return 'gcc'
    end
    return nil
  end
  local comp = config.compile or {}
  local prefer = comp.prefer and comp.prefer[ft] or nil
  if prefer and prefer ~= '' then
    if comp.prefer_force then
      return prefer, (family_of(prefer) or (is_win and 'cl' or 'gcc'))
    else
      if vim.fn.executable(prefer) == 1 then
        return prefer, (family_of(prefer) or 'gcc')
      end
    end
  end
  local domain = is_win and config.toolchain.windows or config.toolchain.unix
  local candidates = (ft == 'c') and domain.c or domain.cpp
  for _, name in ipairs(candidates) do
    if vim.fn.executable(name) == 1 then
      return name, (family_of(name) or 'gcc')
    end
  end
  return nil, nil
end

local function build_cmd(config, is_win, ft, sources, out)
  local name, family = choose_compiler(config, is_win, ft)
  if not family then
    return nil
  end

  if family == 'cl' then
    local args = { 'cl', '/Zi', '/Od' }
    for _, s in ipairs(sources) do
      table.insert(args, s)
    end
    table.insert(args, '/Fe:' .. out)
    return args
  elseif family == 'gcc' then
    local cc = name or ((ft == 'c') and 'gcc' or 'g++')
    local cmd = { cc, '-g', '-O0', '-Wall', '-Wextra' }
    for _, s in ipairs(sources) do
      table.insert(cmd, s)
    end
    table.insert(cmd, '-o')
    table.insert(cmd, out)
    return cmd
  else
    local cc = name or ((ft == 'c') and 'clang' or 'clang++')
    local cmd = { cc, '-g', '-O0', '-Wall', '-Wextra' }
    for _, s in ipairs(sources) do
      table.insert(cmd, s)
    end
    table.insert(cmd, '-o')
    table.insert(cmd, out)
    return cmd
  end
end

local function resolve_out_path(config, sources, name)
  local outdir = config.outdir
  if outdir == 'source' then
    local dir = vim.fn.fnamemodify(sources[1], ':p:h')
    return dir .. '/' .. name
  else
    ensure_outdir(outdir)
    return outdir .. '/' .. name
  end
end

-- Parse compiler diagnostics (gcc/clang/msvc) into quickfix items
-- use U.parse_diagnostics

function B.get_output_name_async(config, sources, preset_name, cb, default_override)
  local is_win = U.is_windows()
  if preset_name and preset_name ~= '' then
    cb(preset_name)
    return
  end
  if #sources == 1 then
    cb(default_out_name(is_win, sources))
    return
  end
  local def = 'a.out'
  if is_win and not def:match '%.exe$' then
    def = def .. '.exe'
  end
  if default_override and default_override ~= '' then
    def = default_override
  end
  local ui = vim.ui or {}
  if ui.input then
    ui.input({ prompt = 'Output name: ', default = def }, function(input)
      local name = input
      if not name or name == '' then
        name = def
      end
      if is_win and not name:match '%.exe$' then
        name = name .. '.exe'
      end
      cb(name)
    end)
  else
    cb(def)
  end
end

-- Expand a template list with placeholders into argv list
-- tmpl: array, elements may contain placeholders {sources} {out} {cc} {ft}
local function expand_template_argv(tmpl, vars)
  local out = {}
  for _, part in ipairs(tmpl or {}) do
    if part == '{sources}' then
      for _, s in ipairs(vars.sources or {}) do table.insert(out, s) end
    elseif part == '{out}' then
      table.insert(out, vars.out)
    elseif part == '{cc}' then
      table.insert(out, vars.cc)
    elseif part == '{ft}' then
      table.insert(out, vars.ft)
    else
      local replaced = part
      replaced = replaced:gsub('%%{sources%%}', '{sources}')
      replaced = replaced:gsub('%%{out%%}', '{out}')
      replaced = replaced:gsub('%%{cc%%}', '{cc}')
      replaced = replaced:gsub('%%{ft%%}', '{ft}')
      replaced = replaced:gsub('{out}', vars.out)
      replaced = replaced:gsub('{cc}', vars.cc)
      replaced = replaced:gsub('{ft}', vars.ft)
      if replaced ~= '{sources}' then
        table.insert(out, replaced)
      else
        for _, s in ipairs(vars.sources or {}) do table.insert(out, s) end
      end
    end
  end
  return out
end

local function clone_list(t)
  local o = {}
  for _, v in ipairs(t or {}) do table.insert(o, v) end
  return o
end

local function project_key()
  local root = vim.fn.getcwd()
  return require('quick-c.util').norm(root)
end

-- Let user optionally customize compile command via Telescope/ui
-- cb(argv_or_nil): when nil, use built-in cmd
local function choose_user_compile_cmd_async(config, is_win, ft, sources, exe, builtin_cmd, cb)
  local cc_name = (choose_compiler(config, is_win, ft))
  local cc = cc_name
  local ucfg = (config.compile and config.compile.user_cmd) or {}
  if not ucfg.enabled then
    cb(nil)
    return
  end
  local tel = (ucfg.telescope or {})
  if tel.popup ~= true then
    cb(nil)
    return
  end
  local presets = ucfg.presets or {}
  local entries = {}
  table.insert(entries, { display = '[Use built-in]', kind = 'builtin' })
  table.insert(entries, { display = '[Custom args...]', kind = 'args' })
  for idx, p in ipairs(presets) do
    local disp
    if type(p) == 'table' then
      disp = table.concat(p, ' ')
    else
      disp = tostring(p)
    end
    table.insert(entries, { display = disp, kind = 'preset', value = p, idx = idx })
  end
  local function finalize(choice)
    if not choice then
      cb(nil)
      return
    end
    if choice.kind == 'builtin' then
      cb(clone_list(builtin_cmd))
      return
    end
    if choice.kind == 'preset' then
      local tmpl = choice.value
      if type(tmpl) ~= 'table' then
        -- string template unsupported for robust argv; fall back to builtin
        cb(clone_list(builtin_cmd))
        return
      end
      local argv = expand_template_argv(tmpl, { sources = sources, out = exe, cc = cc or '', ft = ft })
      cb(argv)
      return
    end
    if choice.kind == 'args' then
      local key = project_key()
      local def_cfg = ucfg.default
      local def_from_cfg = ''
      if type(def_cfg) == 'table' then
        def_from_cfg = table.concat(def_cfg, ' ')
      elseif type(def_cfg) == 'string' then
        def_from_cfg = def_cfg
      end
      local def = ''
      if ucfg.remember_last ~= false then
        def = (LAST_COMPILE_ARGS[key] and LAST_COMPILE_ARGS[key] ~= '' and LAST_COMPILE_ARGS[key]) or def_from_cfg or ''
      else
        def = def_from_cfg or ''
      end
      local ui = vim.ui or {}
      if not ui.input then
        cb(clone_list(builtin_cmd))
        return
      end
      ui.input({ prompt = 'extra compile args: ', default = def }, function(arg)
        if ucfg.remember_last ~= false then LAST_COMPILE_ARGS[key] = arg or '' end
        if not arg or arg == '' then
          cb(clone_list(builtin_cmd))
          return
        end
        local argv = clone_list(builtin_cmd)
        for a in string.gmatch(arg, "[^%s]+") do table.insert(argv, a) end
        cb(argv)
      end)
      return
    end
    cb(nil)
  end
  local ok_t = pcall(require, 'telescope')
  if ok_t then
    local pickers = require 'telescope.pickers'
    local finders = require 'telescope.finders'
    local conf = require('telescope.config').values
    pickers
      .new({}, {
        prompt_title = tel.prompt_title or 'Quick-c Compile',
        finder = finders.new_table {
          results = entries,
          entry_maker = function(e)
            return { value = e, display = e.display, ordinal = e.display, kind = e.kind }
          end,
        },
        sorter = conf.generic_sorter {},
        attach_mappings = function(bufnr, map)
          local actions = require 'telescope.actions'
          local action_state = require 'telescope.actions.state'
          local function choose(pbuf)
            local entry = action_state.get_selected_entry()
            actions.close(pbuf)
            finalize(entry and entry.value or nil)
          end
          local function cancel(pbuf)
            actions.close(pbuf)
            finalize(nil)
          end
          map('i', '<CR>', choose)
          map('n', '<CR>', choose)
          map('i', '<Esc>', cancel)
          map('n', '<Esc>', cancel)
          map('n', 'q', cancel)
          map('i', '<C-c>', cancel)
          return true
        end,
      })
      :find()
    return
  end
  local ui = vim.ui or {}
  if ui.select then
    local items = {}
    for _, e in ipairs(entries) do table.insert(items, e.display) end
    ui.select(items, { prompt = tel.prompt_title or 'Quick-c Compile' }, function(sel)
      if not sel then finalize(nil) return end
      for _, e in ipairs(entries) do if e.display == sel then finalize(e) return end end
      finalize(nil)
    end)
    return
  end
  cb(nil)
end

function B.build(config, notify, opts)
  opts = opts or {}
  local timeout_ms = (config.build and config.build.timeout_ms) or 0
  local cli_sources = from_opts_sources(opts)
  local sources = cli_sources or gather_sources()
  if not sources or #sources == 0 then
    notify.warn 'No source files found'
    return
  end
  local ft = vim.bo.filetype
  if ft ~= 'c' and ft ~= 'cpp' then
    ft = detect_ft_from_sources(sources)
  end
  local key = sources_key(sources)
  local cached = NAME_CACHE[key]
  local preset = nil
  local default_override = cached

  local job_id = -1
  local started_at = (vim.loop and vim.loop.now and vim.loop.now()) or 0
  TASK.enqueue {
    name = 'build',
    target = table.concat(sources, ' '),
    timeout_ms = timeout_ms,
    cancel = function()
      if job_id and job_id > 0 then pcall(vim.fn.jobstop, job_id) end
    end,
    start = function(done)
      B.get_output_name_async(config, sources, preset, function(name)
        if not cached and name and name ~= '' then
          NAME_CACHE[key] = name
        end
        local is_win = U.is_windows()
        local exe = resolve_out_path(config, sources, name)
        local builtin_cmd = build_cmd(config, is_win, ft, sources, exe)
        if not builtin_cmd then
          notify.err 'No available compiler found. Check PATH or set compile.prefer in setup()'
          if opts.on_exit then pcall(opts.on_exit, 1, nil) end
          done(1)
          return
        end
        choose_user_compile_cmd_async(config, is_win, ft, sources, exe, builtin_cmd, function(user_argv)
          local cmd = user_argv or builtin_cmd
          local cmdline = table.concat(cmd, ' ')
          local all_stdout, all_stderr = {}, {}
          job_id = vim.fn.jobstart(cmd, {
          stdout_buffered = true,
          stderr_buffered = true,
          detach = false,
          on_stdout = function(_, d)
            if d and #d > 0 then
              for _, line in ipairs(d) do table.insert(all_stdout, line) end
            end
          end,
          on_stderr = function(_, d)
            if d and #d > 0 then
              for _, line in ipairs(d) do table.insert(all_stderr, line) end
            end
          end,
          on_exit = function(_, code)
            local diagcfg = (config.diagnostics and config.diagnostics.quickfix) or {}
            local qf_enabled = (diagcfg.enabled ~= false)
            local lines = {}
            for _, s in ipairs(all_stdout) do table.insert(lines, s) end
            for _, s in ipairs(all_stderr) do table.insert(lines, s) end
            if #lines > 0 then write_build_logs(lines) end
            -- Compute diagnostics summary for notification
            local items = {}
            do
              local parsed = { U.parse_diagnostics(lines) }
              items = parsed[1] or {}
            end
            local err_cnt, warn_cnt = 0, 0
            for _, it in ipairs(items) do
              if it.type == 'E' then err_cnt = err_cnt + 1 else warn_cnt = warn_cnt + 1 end
            end
            if qf_enabled and #lines > 0 then
              local items, has_error, has_warning = U.parse_diagnostics(lines)
              if #items > 0 then
                vim.fn.setqflist({}, ' ', { title = 'Quick-c Build', items = items })
                local function should_open()
                  if diagcfg.open == 'always' then return true end
                  if diagcfg.open == 'error' and has_error then return true end
                  if diagcfg.open == 'warning' and (has_error or has_warning) then return true end
                  return false
                end
                local function should_jump()
                  if diagcfg.jump == 'always' then return true end
                  if diagcfg.jump == 'error' and has_error then return true end
                  if diagcfg.jump == 'warning' and (has_error or has_warning) then return true end
                  return false
                end
                if should_open() then
                  if diagcfg.use_telescope then
                    local ok_qc, qct = pcall(require, 'quick-c.telescope')
                    if ok_qc and qct and qct.telescope_quickfix then
                      pcall(qct.telescope_quickfix, config)
                    else
                      local ok_tb, tb = pcall(require, 'telescope.builtin')
                      if ok_tb and tb and tb.quickfix then
                        pcall(tb.quickfix)
                      else
                        pcall(vim.cmd, 'copen')
                      end
                    end
                  else
                    pcall(vim.cmd, 'copen')
                  end
                  if not (pcall(require, 'telescope')) then
                    local info = vim.fn.getqflist({ winid = 1 }) or {}
                    local wid = info.winid or 0
                    if wid ~= 0 then
                      pcall(vim.api.nvim_win_set_option, wid, 'wrap', true)
                      pcall(vim.api.nvim_win_set_option, wid, 'linebreak', true)
                      pcall(vim.api.nvim_win_set_option, wid, 'breakindent', true)
                    end
                  end
                end
                if should_jump() then
                  local cur = vim.api.nvim_get_current_buf()
                  local nameb = vim.api.nvim_buf_get_name(cur)
                  local modified = false
                  pcall(function() modified = vim.api.nvim_buf_get_option(cur, 'modified') end)
                  if not (nameb == '' and modified) then
                    pcall(vim.cmd, 'silent! keepalt keepjumps cc')
                  end
                end
              else
                if code == 0 then vim.fn.setqflist {} end
              end
            end
            local dur = (((vim.loop and vim.loop.now and vim.loop.now()) or started_at) - started_at)
            local secs = (dur or 0) / 1000
            local msg = {}
            if code == 0 then
              table.insert(msg, string.format('Build OK -> %s', exe))
            else
              table.insert(msg, string.format('Build failed (%d)', code))
            end
            table.insert(msg, string.format('Time: %.2fs | Errors: %d, Warnings: %d', secs, err_cnt, warn_cnt))
            table.insert(msg, 'Cmd: ' .. cmdline)
            local full = table.concat(msg, '\n')
            if code == 0 then notify.info(full) else notify.err(full) end
            if code == 0 then
              local root = vim.fn.getcwd()
              LAST_EXE[U.norm(root)] = exe
            end
            if opts.on_exit then pcall(opts.on_exit, code, exe) end
            done(code)
          end,
        })
          if (job_id or 0) <= 0 then
            notify.err 'Failed to start build process'
            done(1)
          end
        end)
      end, default_override)
    end,
  }
end

function B.run(config, notify, exe_or_opts)
  local opts
  local exe
  if type(exe_or_opts) == 'table' then
    opts = exe_or_opts
  else
    exe = exe_or_opts
  end
  local cli_sources = from_opts_sources(opts)
  local cur = cli_sources or { vim.fn.expand '%:p' }
  local is_win = U.is_windows()
  exe = exe or resolve_out_path(config, cur, default_out_name(is_win, cur))
  if vim.fn.filereadable(exe) ~= 1 then
    notify.warn 'Executable not found. Please build first'
    return
  end
  local cmd
  if is_win then
    if U.is_powershell() then
      cmd = string.format("& '%s'", exe)
    else
      cmd = string.format('"%s"', exe)
    end
  else
    cmd = string.format("'%s'", exe)
  end
  if not T.run_in_betterterm(config, U.is_windows, cmd, notify.warn, notify.err) then
    if not T.run_in_native_terminal(config, U.is_windows, cmd) then
      notify.err 'Unable to run command: cannot open terminal'
    end
  end
end

function B.build_and_run(config, notify, opts)
  opts = opts or {}
  local user_on_exit = opts.on_exit
  opts.on_exit = function(code, exe)
    if user_on_exit then
      pcall(user_on_exit, code, exe)
    end
    if code == 0 then
      -- 关键修复：直接使用构建时得到的 exe 路径运行，避免名称不一致
      B.run(config, notify, exe)
    end
  end
  B.build(config, notify, opts)
end

function B.debug_run(config, notify, exe)
  local cur = { vim.fn.expand '%:p' }
  local is_win = U.is_windows()
  exe = exe or resolve_out_path(config, cur, default_out_name(is_win, cur))
  -- Prefer the most recent successful build exe in this project
  do
    local key = U.norm(vim.fn.getcwd())
    local cached = LAST_EXE[key]
    if (not exe or vim.fn.filereadable(exe) ~= 1) and cached and vim.fn.filereadable(cached) == 1 then
      exe = cached
    end
  end
  if vim.fn.filereadable(exe) ~= 1 then
    -- Try to discover candidates asynchronously and let user pick one
    local cur_dir = vim.fn.fnamemodify(cur[1], ':p:h')
    discover_candidates_async(config, is_win, cur_dir, function(cand)
      if not cand or #cand == 0 then
        notify.warn 'Executable not found. Please build first'
        return
      end
      local function start_debug(sel)
        if not sel or sel == '' then
          return
        end
        exe = sel
        -- fall through to dap.run below
        local ok, dap = pcall(require, 'dap')
        if not ok then
          notify.err 'not found nvim-dap'
          return
        end
        dap.run {
          type = 'codelldb',
          request = 'launch',
          name = 'Quick-c Debug',
          program = exe,
          cwd = vim.fn.getcwd(),
          stopOnEntry = false,
          runInTerminal = true,
          initCommands = { 'settings set target.process.thread.step-avoid-libraries true' },
        }
      end
      local ok_t, telescope = pcall(require, 'telescope')
      if ok_t then
        local pickers = require 'telescope.pickers'
        local finders = require 'telescope.finders'
        local conf = require('telescope.config').values
        local entries = {}
        for _, p in ipairs(cand) do
          local rel = vim.fn.fnamemodify(p, ':.')
          table.insert(entries, { display = rel, value = p, ordinal = rel })
        end
        pickers
          .new({}, {
            prompt_title = 'Select executable to debug',
            finder = finders.new_table {
              results = entries,
              entry_maker = function(e)
                return { value = e.value, display = e.display, ordinal = e.ordinal }
              end,
            },
            sorter = conf.generic_sorter {},
            attach_mappings = function(bufnr, map)
              local actions = require 'telescope.actions'
              local action_state = require 'telescope.actions.state'
              local function choose(pbuf)
                local entry = action_state.get_selected_entry()
                actions.close(pbuf)
                start_debug(entry and (entry.value or entry[1]))
              end
              map('i', '<CR>', choose)
              map('n', '<CR>', choose)
              return true
            end,
          })
          :find()
        return
      end
      local ui = vim.ui or {}
      if ui.select then
        local items = {}
        for _, p in ipairs(cand) do
          table.insert(items, vim.fn.fnamemodify(p, ':.'))
        end
        ui.select(items, { prompt = 'Select executable to debug' }, function(choice)
          if not choice then
            return
          end
          for _, p in ipairs(cand) do
            if vim.fn.fnamemodify(p, ':.') == choice then
              start_debug(p)
              return
            end
          end
        end)
        return
      end
      -- Fallback: use the first candidate
      start_debug(cand[1])
    end)
    return
  end
  local ok, dap = pcall(require, 'dap')
  if not ok then
    notify.err 'nvim-dap not found'
    return
  end
  dap.run {
    type = 'codelldb',
    request = 'launch',
    name = 'Quick-c Debug',
    program = exe,
    cwd = vim.fn.getcwd(),
    stopOnEntry = false,
    runInTerminal = true,
    initCommands = { 'settings set target.process.thread.step-avoid-libraries true' },
  }
end

return B
