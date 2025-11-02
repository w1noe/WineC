local S = {}

local state = {
  phase = 'idle',
  task = nil,
  target = nil,
  started_at = 0,
  last = nil,
}

function S.start(task, target)
  state.phase = 'running'
  state.task = task
  state.target = target
  state.started_at = (vim.loop and vim.loop.now and vim.loop.now()) or 0
end

function S.finish(task, target, code, duration_ms)
  state.last = { task = task, target = target, code = code, duration_ms = duration_ms }
  state.phase = 'idle'
  state.task = nil
  state.target = nil
  state.started_at = 0
end

function S.get()
  return state
end

function S.last_label()
  local l = state.last
  if not l then return nil end
  if l.code == 0 then return 'OK' end
  if l.code == 124 then return 'Timeout' end
  if l.code == 130 then return 'Canceled' end
  return 'Error'
end

return S
