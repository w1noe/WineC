local M = { _timer = nil }

local function bool(x)
  return not not x
end

local function get_ft(buf)
  local ok, ft = pcall(function()
    return (vim.bo and vim.bo[buf] and vim.bo[buf].filetype) or vim.api.nvim_buf_get_option(buf, 'filetype')
  end)
  return ok and ft or ''
end

local function get_opt(buf, name)
  local ok, v = pcall(function()
    return vim.api.nvim_buf_get_option(buf, name)
  end)
  return ok and v or nil
end

local function should_save(buf, allow_any, allow_fts, ignore_fts)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  local ft = get_ft(buf)
  if ignore_fts[ft] then
    return false
  end
  if not allow_any and not allow_fts[ft] then
    return false
  end
  if not bool(get_opt(buf, 'modified')) then
    return false
  end
  if bool(get_opt(buf, 'readonly')) then
    return false
  end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == nil or name == '' then
    return false
  end
  local bt = get_opt(buf, 'buftype') or ''
  if bt ~= '' then
    return false
  end
  return true
end

function M.setup(config)
  local cfg = (config and config.autosave) or {}
  if cfg.enabled == false then
    return
  end
  local events = cfg.events or { 'TextChanged', 'TextChangedI', 'InsertLeave' }
  local debounce_ms = tonumber(cfg.debounce_ms) or 300
  local only_fts = cfg.filetypes or { 'c', 'cpp' }
  local ignore_fts = {}
  for _, ft in ipairs(cfg.ignore_filetypes or {}) do
    ignore_fts[ft] = true
  end
  local allow_any = (only_fts == nil) or (#only_fts == 0)
  local allow_fts = {}
  for _, ft in ipairs(only_fts or {}) do
    allow_fts[ft] = true
  end
  local uv = vim.loop
  if not M._timer or M._timer:is_closing() then
    M._timer = uv.new_timer()
  end
  local t = M._timer
  local ok_grp, grp = pcall(vim.api.nvim_create_augroup, 'QuickC_Autosave', { clear = true })
  if not ok_grp then
    grp = nil
  end
  local function schedule_save(buf)
    t:stop()
    t:start(debounce_ms, 0, function()
      vim.schedule(function()
        if should_save(buf, allow_any, allow_fts, ignore_fts) then
          pcall(vim.api.nvim_buf_call, buf, function()
            pcall(vim.cmd, 'silent noautocmd write')
          end)
        end
      end)
    end)
  end
  for _, ev in ipairs(events) do
    pcall(vim.api.nvim_create_autocmd, ev, {
      group = grp,
      callback = function(args)
        local buf = (args and args.buf) or vim.api.nvim_get_current_buf()
        schedule_save(buf)
      end,
    })
  end
end

return M
