-- plugin/quick-c.lua
pcall(function()
  if not vim.g.quick_c_auto_setup_done and vim.g.quick_c_auto_setup ~= false then
    require('quick-c').setup()
  end
end)
