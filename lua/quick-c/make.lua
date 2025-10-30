local U = require 'quick-c.util'
local M = {}

local target_cache = {
  -- [cwd] = { mtime = <number|nil>, at = <os.time>, targets = {...} }
}

local make_watchers = {}

local function ensure_make_watcher(cwd)
  if not cwd or make_watchers[cwd] then
    return
  end
  local uv = vim.loop
  local h = uv.new_fs_event()
  local ok = pcall(uv.fs_event_start, h, cwd, {}, function(err, fname)
    if err or not fname then
      return
    end
    if fname == 'Makefile' or fname == 'makefile' or fname == 'GNUmakefile' then
      target_cache[cwd] = nil
    end
  end)
  if not ok then
    pcall(function()
      h:close()
    end)
    return
  end
  make_watchers[cwd] = h
end

local function stat_makefile(cwd)
  local names = { 'Makefile', 'makefile', 'GNUmakefile' }
  for _, n in ipairs(names) do
    local p = U.join(cwd, n)
    local st = vim.loop.fs_stat(p)
    if st and st.type == 'file' then
      return st.mtime and st.mtime.sec or st.mtime or 0
    end
  end
  return nil
end

local function strip_quotes(s)
  if type(s) ~= 'string' then
    return s
  end
  local a = s:match '^%s*"(.*)"%s*$' or s:match "^%s*'(.*)'%s*$"
  return a or s
end

local function tbl_is_list(t)
  if type(t) ~= 'table' then
    return false
  end
  if vim.tbl_islist then
    return vim.tbl_islist(t)
  end
  local max = 0
  for k, _ in pairs(t) do
    if type(k) ~= 'number' then
      return false
    end
    if k > max then
      max = k
    end
  end
  for i = 1, max do
    if t[i] == nil then
      return false
    end
  end
  return true
end

local function platform_prefer_keys()
  if U.is_windows() then
    return { 'windows', 'win32', 'win', 'default', 'fallback' }
  end
  local has_mac = vim.fn and vim.fn.has and (vim.fn.has 'macunix' == 1 or vim.fn.has 'mac' == 1)
  if has_mac then
    return { 'mac', 'macos', 'darwin', 'unix', 'posix', 'linux', 'default', 'fallback' }
  end
  return { 'linux', 'unix', 'posix', 'default', 'fallback' }
end

local function normalize_prefer(pref, visited)
  visited = visited or {}
  if type(pref) == 'string' then
    return { pref }
  end
  if type(pref) ~= 'table' or visited[pref] then
    return {}
  end
  visited[pref] = true
  if tbl_is_list(pref) then
    local acc = {}
    for _, v in ipairs(pref) do
      if type(v) == 'string' then
        table.insert(acc, v)
      elseif type(v) == 'table' then
        local nested = normalize_prefer(v, visited)
        for _, n in ipairs(nested) do
          table.insert(acc, n)
        end
      end
    end
    return acc
  end
  local keys = platform_prefer_keys()
  for _, key in ipairs(keys) do
    local val = pref[key]
    if val ~= nil then
      local normalized = normalize_prefer(val, visited)
      if #normalized > 0 then
        return normalized
      end
      if type(val) == 'string' then
        return { val }
      end
    end
  end
  local acc = {}
  for _, val in pairs(pref) do
    if type(val) == 'string' then
      table.insert(acc, val)
    elseif type(val) == 'table' then
      local nested = normalize_prefer(val, visited)
      for _, n in ipairs(nested) do
        table.insert(acc, n)
      end
    end
  end
  return acc
end

local function can_execute_prog(p)
  local prog = strip_quotes(p)
  if not prog or prog == '' then
    return false
  end
  if vim.fn.executable(prog) == 1 then
    return true
  end
  -- If it's a path, check file existence (may still fail to exec, but avoid jobstart crash)
  local is_path
  if U.is_windows() then
    is_path = prog:match '[\\/]' or prog:match '%.exe$'
  else
    is_path = prog:sub(1, 1) == '/' or prog:match '[\\/]'
  end
  if is_path then
    local st = vim.loop.fs_stat(prog)
    return st and st.type == 'file'
  end
  return false
end

-- Choose a make program only for parsing targets (-q/-p), independent from prefer_force
local function choose_probe_make()
  local candidates = { 'make', 'mingw32-make', 'nmake' }
  for _, name in ipairs(candidates) do
    if vim.fn.executable(name) == 1 then
      return name
    end
  end
  return nil
end

function M.choose_make(config)
  local pref = (config.make or {}).prefer
  local force = ((config.make or {}).prefer_force == true)
  local function is_exec(x)
    return x and vim.fn.executable(x) == 1
  end
  local function is_path(x)
    if not x or type(x) ~= 'string' then
      return false
    end
    if U.is_windows() then
      return x:match '[/]' or x:match '%.exe$'
    end
    return x:sub(1, 1) == '/' or x:match '[/]'
  end
  local function quote_if_needed(p)
    if not p then
      return p
    end
    if p:find '%s' then
      return string.format('%q', p)
    end
    return p
  end
  local function path_exists_file(p)
    local st = vim.loop.fs_stat(p)
    return st and st.type == 'file'
  end
  local candidates = normalize_prefer(pref)
  if type(pref) == 'string' and #candidates == 0 then
    candidates = { pref }
  end
  local failures = {}
  local function record_failure(msg)
    failures[#failures + 1] = msg
  end
  for _, name in ipairs(candidates) do
    if type(name) == 'string' then
      if is_path(name) then
        if path_exists_file(name) then
          return quote_if_needed(name)
        elseif force then
          return quote_if_needed(name)
        else
          record_failure('Preferred make program path not found: ' .. tostring(name))
        end
      else
        if is_exec(name) then
          return name
        elseif force then
          return name
        else
          record_failure('Preferred make program not executable: ' .. tostring(name) .. ' (not in PATH)')
        end
      end
    end
  end
  if force and #candidates > 0 and type(candidates[1]) == 'string' then
    local first = candidates[1]
    if is_path(first) then
      return quote_if_needed(first)
    else
      return first
    end
  end
  if next(failures) then
    for _, msg in ipairs(failures) do
      U.notify_warn(msg)
    end
  elseif pref ~= nil and type(pref) ~= 'string' and type(pref) ~= 'table' then
    U.notify_warn 'Preferred make config cannot be parsed. Check structure (string/list/platform table)'
  elseif pref ~= nil and type(pref) == 'table' and #candidates == 0 then
    U.notify_warn 'Preferred make config cannot be parsed. Check structure (string/list/platform table)'
  end
  if is_exec 'make' then
    return 'make'
  end
  if U.is_windows() and is_exec 'mingw32-make' then
    return 'mingw32-make'
  end
  return nil
end

function M.parse_make_targets_in_cwd_async(config, cwd, cb)
  ensure_make_watcher(cwd)
  local pref_prog = M.choose_make(config)
  if not pref_prog then
    cb {}
    return
  end
  local probe = pref_prog
  if not can_execute_prog(pref_prog) then
    local alt = choose_probe_make()
    if alt then
      U.notify_warn(
        'Quick-c: Using available make (' .. alt .. ") for parsing; running still uses '" .. tostring(pref_prog) .. "'"
      )
      probe = alt
    else
      local msg =
        'Quick-c: No make found for parsing (make/mingw32-make/nmake). Check environment or use QuickCMakeCmd'
      U.notify_warn(msg)
      cb {}
      return
    end
  end
  local cache_cfg = (config.make or {}).cache or {}
  local ttl = tonumber(cache_cfg.ttl) or 10
  local cur_mtime = stat_makefile(cwd)
  local entry = target_cache[cwd]
  if entry and entry.targets and entry.at and (os.time() - entry.at <= ttl) and entry.mtime == cur_mtime then
    cb { targets = entry.targets, phony = entry.phony or {} }
    return
  end
  local function parse_lines(lines)
    local targets, seen = {}, {}
    local phony = {}
    for _, l in ipairs(lines) do
      local plist = l:match '^%.PHONY%s*:%s*(.+)'
      if plist then
        for name in plist:gmatch '%S+' do
          phony[name] = true
        end
      else
        local name = l:match '^([%w%._%-%+/\\][^:%$#=]*)%s*:'
        if name then
          name = name:gsub('%s+$', '')
          if
            not name:match '%%'
            and not name:match '^%.'
            and name ~= 'Makefile'
            and name ~= 'makefile'
            and name ~= 'GNUmakefile'
          then
            if not seen[name] then
              seen[name] = true
              table.insert(targets, name)
            end
          end
        end
      end
    end
    table.sort(targets)
    return targets, phony
  end
  local function run_and_collect(flags, done)
    local function launch()
      local lines = {}
      local job = vim.fn.jobstart({ strip_quotes(probe), flags }, {
        cwd = cwd,
        stdout_buffered = true,
        on_stdout = function(_, data)
          if data then
            for _, l in ipairs(data) do
              table.insert(lines, l)
            end
          end
        end,
        on_exit = function()
          done(lines)
        end,
      })
      if job <= 0 then
        done {}
      end
    end
    if vim.in_fast_event and vim.in_fast_event() then
      vim.schedule(launch)
    else
      launch()
    end
  end
  run_and_collect('-qp', function(lines_qp)
    local targets, phony = parse_lines(lines_qp)
    if #targets == 0 then
      -- Fallback to -pn for broader compatibility (e.g., some make variants)
      run_and_collect('-pn', function(lines_pn)
        local t2, p2 = parse_lines(lines_pn)
        target_cache[cwd] = { mtime = cur_mtime, at = os.time(), targets = t2, phony = p2 }
        cb { targets = t2, phony = p2 }
      end)
    else
      target_cache[cwd] = { mtime = cur_mtime, at = os.time(), targets = targets, phony = phony }
      cb { targets = targets, phony = phony }
    end
  end)
end

function M.make_run_in_cwd(config, cwd, target, run_fn)
  local prog = M.choose_make(config)
  if not prog then
    U.notify_err 'make or mingw32-make not found'
    return
  end
  local no_dash_C = (config.make and config.make.no_dash_C) == true
  local cmd
  if no_dash_C then
    cmd = string.format('%s %s', prog, target or '')
  else
    cmd = string.format('%s -C %s %s', prog, U.shell_quote_path(cwd), target or '')
  end
  run_fn(cmd)
end

return M
