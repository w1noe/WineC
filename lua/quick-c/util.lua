local U = {}

function U.is_windows()
  return vim.fn.has 'win32' == 1
end

function U.is_powershell()
  local sh = (vim.o.shell or ''):lower()
  return sh:find 'powershell' or sh:find 'pwsh'
end

function U.join(a, b)
  if a:sub(-1) == '/' or a:sub(-1) == '\\' then
    return a .. b
  end
  local sep = U.is_windows() and '\\' or '/'
  return a .. sep .. b
end

function U.norm(p)
  p = vim.fn.fnamemodify(p, ':p')
  if U.is_windows() then
    p = p:gsub('\\', '/'):lower()
  else
    p = p:gsub('//+', '/')
  end
  if p:sub(-1) == '/' then
    p = p:sub(1, -2)
  end
  return p
end

function U.shell_quote_path(p)
  if U.is_windows() then
    if U.is_powershell() then
      return string.format("'%s'", p)
    else
      return string.format('"%s"', p)
    end
  else
    return string.format("'%s'", p)
  end
end

function U.notify_err(msg)
  vim.notify('Quick-c: ' .. msg, vim.log.levels.ERROR)
end
function U.notify_info(msg)
  vim.notify('Quick-c: ' .. msg, vim.log.levels.INFO)
end
function U.notify_warn(msg)
  vim.notify('Quick-c: ' .. msg, vim.log.levels.WARN)
end

-- Parse compiler diagnostics (gcc/clang/msvc) into quickfix items
function U.parse_diagnostics(lines)
  local items = {}
  local has_error = false
  local has_warning = false
  local function clean_path(p)
    if not p or p == '' then
      return p
    end
    p = p:gsub('^%s+', ''):gsub('%s+$', '')
    p = p:gsub('^"(.+)"$', '%1'):gsub("^'(.-)'$", '%1')
    return p
  end
  for _, l in ipairs(lines or {}) do
    if type(l) ~= 'string' or l == '' then
      goto continue
    end
    local f, ln, col, typ, msg = l:match '^(.+):(%d+):(%d+):%s*(%w+)%s*:%s*(.+)$'
    if f then
      local it = {
        filename = clean_path(f),
        lnum = tonumber(ln),
        col = tonumber(col),
        text = msg,
        type = (typ == 'error' and 'E' or 'W'),
      }
      if it.type == 'E' then
        has_error = true
      else
        has_warning = true
      end
      table.insert(items, it)
      goto continue
    end
    local f2, ln2, typ2, msg2 = l:match '^(.+):(%d+):%s*(%w+)%s*:%s*(.+)$'
    if f2 then
      local it = {
        filename = clean_path(f2),
        lnum = tonumber(ln2),
        col = 1,
        text = msg2,
        type = (typ2 == 'error' and 'E' or 'W'),
      }
      if it.type == 'E' then
        has_error = true
      else
        has_warning = true
      end
      table.insert(items, it)
      goto continue
    end
    local fm, lnm, typm, msgm = l:match '^%s*(.-)%((%d+)%)%s*:%s*(%w+)[^:]*:%s*(.+)$'
    if fm then
      local it = {
        filename = clean_path(fm),
        lnum = tonumber(lnm),
        col = 1,
        text = msgm,
        type = (typm:lower() == 'error' and 'E' or 'W'),
      }
      if it.type == 'E' then
        has_error = true
      else
        has_warning = true
      end
      table.insert(items, it)
      goto continue
    end
    ::continue::
  end
  return items, has_error, has_warning
end

return U
