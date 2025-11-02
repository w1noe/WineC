local U = require 'quick-c.util'

local M = {}

local function strip_quotes(s)
  if type(s) ~= 'string' then return s end
  local a = s:match('^%s*"(.*)"%s*$') or s:match("^%s*'(.*)'%s*$")
  return a or s
end

local function can_execute_prog(p)
  local prog = strip_quotes(p)
  if not prog or prog == '' then return false end
  if vim.fn.executable(prog) == 1 then return true end
  local is_path
  if U.is_windows() then
    is_path = prog:match('[\\/]') or prog:match('%.exe$')
  else
    is_path = prog:sub(1,1) == '/' or prog:match('[\\/]')
  end
  if is_path then
    local st = vim.loop.fs_stat(prog)
    return st and st.type == 'file'
  end
  return false
end

local function choose_probe_make(pref_prog)
  if pref_prog and can_execute_prog(pref_prog) then return pref_prog end
  local cands = { 'make', 'mingw32-make', 'nmake' }
  for _, n in ipairs(cands) do
    if vim.fn.executable(n) == 1 then return n end
  end
  return pref_prog
end

local function parse_line(l, seen, phony)
  local plist = l:match('^%%.PHONY%s*:%s*(.+)')
  if plist then
    for name in plist:gmatch('%S+') do phony[name] = true end
    return nil
  end
  local name = l:match('^([%w%._%-%+/\\][^:%$#=]*)%s*:')
  if not name then return nil end
  name = name:gsub('%s+$','')
  if name:match('%%') then return nil end
  if name:match('^%.') then return nil end
  if name == 'Makefile' or name == 'makefile' or name == 'GNUmakefile' then return nil end
  if seen[name] then return nil end
  seen[name] = true
  return name
end

function M.stream_targets_in_cwd(config, cwd, on_event)
  local mkcfg = config.make or {}
  local streaming = (mkcfg.streaming and mkcfg.streaming.enabled) ~= false
  local batch_size = (mkcfg.streaming and tonumber(mkcfg.streaming.batch_size)) or 100
  local throttle_ms = (mkcfg.streaming and tonumber(mkcfg.streaming.throttle_ms)) or 60
  if not streaming then
    return { cancel = function() end }
  end

  local seen, phony = {}, {}
  local buf = ''
  local pending = {}
  local job_id = -1
  local closed = false
  local flush_timer = nil

  local function emit(kind, payload)
    local ev = payload or {}
    ev.kind = kind
    pcall(on_event, ev)
  end

  local function flush_batch()
    if #pending == 0 then return end
    local out = pending
    pending = {}
    emit('batch', { targets = out, phony = phony })
  end

  local function schedule_flush()
    if throttle_ms <= 0 then flush_batch(); return end
    if flush_timer then return end
    flush_timer = true
    vim.defer_fn(function()
      flush_timer = nil
      flush_batch()
    end, throttle_ms)
  end

  local function handle_chunk(lines)
    if not lines or #lines == 0 then return end
    for i, l in ipairs(lines) do
      if i == 1 then
        l = buf .. (l or '')
      end
      if i == #lines then
        if l:sub(-1) ~= '\n' then
          buf = l
        else
          buf = ''
        end
      end
      local tmp = l:gsub('\r','')
      local added = parse_line(tmp, seen, phony)
      if added then
        table.insert(pending, added)
        if #pending >= batch_size then flush_batch() end
      end
    end
    schedule_flush()
  end

  local function start_with_flag(make_prog, flag, on_finish)
    local args
    if make_prog == 'nmake' then
      if flag == '-qp' then flag = '-n -p' end
      args = { make_prog, flag }
    else
      args = { strip_quotes(make_prog), flag }
    end
    emit('start', {})
    job_id = vim.fn.jobstart(args, {
      cwd = cwd,
      stdout_buffered = false,
      on_stdout = function(_, data)
        handle_chunk(data)
      end,
      on_stderr = function(_, _)
      end,
      on_exit = function(_, code)
        if closed then return end
        flush_batch()
        on_finish(code)
      end,
    })
    if (job_id or 0) <= 0 then
      on_finish(1)
    end
  end

  local pref = (mkcfg and mkcfg.prefer) or nil
  local make_mod = require('quick-c.make')
  local pref_prog = make_mod.choose_make(config)
  local probe = choose_probe_make(pref_prog)
  if not probe then
    emit('error', { message = 'no make found' })
    return { cancel = function() end }
  end

  local function finish(code, tried_fallback)
    if code ~= 0 and not tried_fallback then
      seen, phony, buf, pending = {}, {}, '', {}
      start_with_flag(probe, '-pn', function(code2)
        finish(code2, true)
      end)
      return
    end
    local list = {}
    for k,_ in pairs(seen) do table.insert(list, k) end
    table.sort(list)
    emit('done', { targets = list, phony = phony })
  end

  start_with_flag(probe, '-qp', function(code)
    finish(code, false)
  end)

  local function cancel()
    if closed then return end
    closed = true
    if job_id and job_id > 0 then pcall(vim.fn.jobstop, job_id) end
  end

  return { cancel = cancel }
end

return M
