local S = require 'quick-c.status'

local M = {}

local queue = {}
local current = nil
local last_task = nil

-- task: { name, target, start(fn), timeout_ms }

local function now()
  local uv = vim.loop
  return (uv and uv.now and uv.now()) or 0
end

local function schedule_next()
  if current or #queue == 0 then
    return
  end
  current = table.remove(queue, 1)
  local t = current
  S.start(t.name, t.target)
  local start_at = now()
  local finished = false
  local timer
  if t.timeout_ms and t.timeout_ms > 0 and vim.loop and vim.loop.new_timer then
    timer = vim.loop.new_timer()
    timer:start(t.timeout_ms, 0, function()
      if finished then return end
      if t.cancel then pcall(t.cancel) end
      finished = true
      local dur = now() - start_at
      vim.schedule(function()
        S.finish(t.name, t.target, 124, dur)
        if t.on_exit then pcall(t.on_exit, 124) end
        current = nil
        schedule_next()
      end)
    end)
  end
  local function done(code)
    if finished then return end
    finished = true
    if timer and not timer:is_closing() then timer:stop(); timer:close() end
    local dur = now() - start_at
    S.finish(t.name, t.target, code, dur)
    if t.on_exit then pcall(t.on_exit, code) end
    current = nil
    schedule_next()
  end
  -- start
  if t.start then
    last_task = t
    t.start(done)
  else
    done(0)
  end
end

function M.enqueue(task)
  table.insert(queue, task)
  schedule_next()
end

function M.cancel_current()
  if not current then return false end
  if current.cancel then pcall(current.cancel) end
  return true
end

function M.retry_last()
  if not last_task then return false end
  -- shallow copy without on_exit wrapper duplication
  local t = {}
  for k, v in pairs(last_task) do t[k] = v end
  table.insert(queue, 1, t)
  schedule_next()
  return true
end

function M.idle()
  return current == nil
end

function M.current()
  return current
end

return M
