local M = {}

local function is_exec(x)
  return x and x ~= '' and vim.fn.executable(x) == 1
end

local function check_execs()
  local ok = true
  local msgs = {}
  local function add(stat, msg)
    table.insert(msgs, string.format("[%s] %s", stat and "OK" or "WARN", msg))
    if not stat then ok = false end
  end
  -- compilers
  add(is_exec('gcc') or is_exec('clang') or is_exec('cl'), 'Found a C compiler (gcc/clang/cl) in PATH')
  add(is_exec('g++') or is_exec('clang++') or is_exec('cl'), 'Found a C++ compiler (g++/clang++/cl) in PATH')
  -- make tools
  add(is_exec('make') or is_exec('mingw32-make') or is_exec('nmake'), 'Found a make tool (make/mingw32-make/nmake)')
  -- cmake
  add(is_exec('cmake'), 'Found cmake')
  -- dap debugger (optional)
  add(is_exec('codelldb') or is_exec('lldb') or is_exec('lldb-vscode'), 'Found codelldb/lldb (optional, for Debug)')
  return ok, msgs
end

function M.run(config)
  local lines = {}
  table.insert(lines, 'Quick-c Health Report')
  table.insert(lines, '--------------------------------')
  local ok, msgs = check_execs()
  vim.list_extend(lines, msgs)
  table.insert(lines, '--------------------------------')
  table.insert(lines, 'Diagnostics quickfix: open=' .. tostring(((config.diagnostics or {}).quickfix or {}).open))
  table.insert(lines, 'Diagnostics quickfix: jump=' .. tostring(((config.diagnostics or {}).quickfix or {}).jump))
  return ok, lines
end

return M
