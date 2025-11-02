local M = {}
local U = require 'quick-c.util'
local T = require 'quick-c.terminal'
local LAST_ARGS = {}

-- Enhanced quickfix Telescope: show detailed error preview on the right
function M.telescope_quickfix(config)
  local ok_t = pcall(require, 'telescope')
  if not ok_t then
    vim.cmd 'copen'
    return
  end
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local previewers = require 'telescope.previewers'
  local qflist = vim.fn.getqflist({ items = 0, title = 0 })
  local items = (qflist and qflist.items) or {}
  if #items == 0 then
    pickers
      .new({}, {
        prompt_title = 'Quickfix (empty)',
        finder = finders.new_table {
          results = { { display = '[Empty] No diagnostic entries', kind = 'empty' } },
          entry_maker = function(e)
            return { value = e.value, display = e.display, ordinal = e.display, kind = e.kind }
          end,
        },
        sorter = conf.generic_sorter {},
      })
      :find()
    return
  end

  local entries = {}
  for _, it in ipairs(items) do
    local bufnr = it.bufnr
    local filename = bufnr and vim.api.nvim_buf_get_name(bufnr) or it.filename or ''
    local lnum = it.lnum or 0
    local col = it.col or 0
    local text = it.text or ''
    local disp
    if filename ~= '' then
      local rel = vim.fn.fnamemodify(filename, ':.')
      disp = string.format('%s:%d:%d %s', rel, lnum, col, text)
    else
      disp = text ~= '' and text or '[no message]'
    end
    table.insert(entries, {
      display = disp,
      ordinal = disp,
      value = {
        bufnr = bufnr,
        filename = filename,
        lnum = lnum,
        col = col,
        text = text,
      },
    })
  end

  local function make_previewer()
    return previewers.new_buffer_previewer {
      define_preview = function(self, entry)
        local v = entry and entry.value or {}
        local filename = v.filename or ''
        local lnum = tonumber(v.lnum or 0)
        local text = v.text or ''
        local lines = {}
        table.insert(lines, '[Diagnostic Info]')
        if text ~= '' then
          table.insert(lines, text)
        end
        if filename ~= '' then
          table.insert(lines, '')
          table.insert(lines, '[Location] ' .. vim.fn.fnamemodify(filename, ':.'))
          local ok, file_lines = pcall(vim.fn.readfile, filename)
          if ok and file_lines then
            local ctx = 3
            local total = #file_lines
            local s = math.max(1, lnum - ctx)
            local e = math.min(total, lnum + ctx)
            for i = s, e do
              local prefix = (i == lnum) and '>' or ' '
              table.insert(lines, string.format('%s %5d  %s', prefix, i, file_lines[i] or ''))
            end
          else
            table.insert(lines, '[Unable to read source file]')
          end
        end
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        -- enable wrapping for long lines in quickfix preview window
        if self.state and self.state.winid then
          pcall(vim.api.nvim_win_set_option, self.state.winid, 'wrap', true)
          pcall(vim.api.nvim_win_set_option, self.state.winid, 'linebreak', true)
          pcall(vim.api.nvim_win_set_option, self.state.winid, 'breakindent', true)
        end
      end,
    }
  end

  pickers
    .new({}, {
      prompt_title = 'Quickfix (Enhanced)',
      finder = finders.new_table {
        results = entries,
        entry_maker = function(e)
          return { value = e.value, display = e.display, ordinal = e.ordinal }
        end,
      },
      sorter = conf.generic_sorter {},
      previewer = make_previewer(),
      attach_mappings = function(bufnr, map)
        local actions = require 'telescope.actions'
        local action_state = require 'telescope.actions.state'
        local function open_loc(pbuf)
          local sel = action_state.get_selected_entry()
          actions.close(pbuf)
          if not sel or not sel.value or not sel.value.filename or sel.value.filename == '' then
            return
          end
          local target = sel.value.filename
          local lnum = sel.value.lnum or 1
          local col = (sel.value.col or 1) - 1
          vim.cmd('edit ' .. vim.fn.fnameescape(target))
          pcall(vim.api.nvim_win_set_cursor, 0, { lnum, math.max(0, col) })
        end
        map('i', '<CR>', open_loc)
        map('n', '<CR>', open_loc)
        return true
      end,
    })
    :find()
end

-- Build logs Telescope: browse persisted logs with preview, for repeated viewing
function M.telescope_build_logs(config)
  local ok_t = pcall(require, 'telescope')
  if not ok_t then
    vim.notify('telescope.nvim not found', vim.log.levels.ERROR)
    return
  end
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local previewers = require 'telescope.previewers'
  local base = vim.fn.stdpath('data') .. '/quick-c/logs'
  local uv = vim.loop
  local files = {}
  local function scandir(dir)
    local ok, req = pcall(uv.fs_scandir, dir)
    if not ok or not req then
      return
    end
    while true do
      local name, t = uv.fs_scandir_next(req)
      if not name then
        break
      end
      if t == 'file' and name:match('^build%-.+%.log$') or name == 'latest-build.log' then
        table.insert(files, U.join(base, name))
      end
    end
  end
  scandir(base)
  -- collect stats (mtime) and build display strings
  local stats = {}
  for _, p in ipairs(files) do
    local st = uv.fs_stat(p) or {}
    local mtime = (st.mtime and (st.mtime.sec or st.mtime)) or 0
    local rel = vim.fn.fnamemodify(p, ':.')
    if rel == p then
      rel = vim.fn.fnamemodify(p, ':t')
    end
    local timestr = os.date('%Y-%m-%d %H:%M:%S', mtime)
    table.insert(stats, { path = p, rel = rel, mtime = mtime, timestr = timestr })
  end
  table.sort(stats, function(a, b)
    return (a.mtime or 0) > (b.mtime or 0)
  end)
  if #stats == 0 then
    vim.notify('No build logs available', vim.log.levels.WARN)
    return
  end
  local entries = {}
  for _, it in ipairs(stats) do
    local disp = string.format('%s  %s', it.timestr, it.rel)
    table.insert(entries, { display = disp, value = it.path, ordinal = it.rel .. ' ' .. it.timestr })
  end
  pickers
    .new({}, {
      prompt_title = 'Quick-c Build Logs',
      finder = finders.new_table {
        results = entries,
        entry_maker = function(e)
          return { value = e.value, display = e.display, ordinal = e.ordinal }
        end,
      },
      sorter = conf.generic_sorter {},
      previewer = previewers.new_buffer_previewer {
        define_preview = function(self, entry)
          local path = entry and entry.value or nil
          if not path or path == '' then
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { '[No log]' })
            return
          end
          local ok, lines = pcall(vim.fn.readfile, path, '', 2000)
          if not ok or not lines then
            lines = { '[Unable to read log file]' }
          end
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
          pcall(vim.api.nvim_buf_set_option, self.state.bufnr, 'filetype', 'log')
          -- enable wrapping for long lines in preview window
          if self.state and self.state.winid then
            pcall(vim.api.nvim_win_set_option, self.state.winid, 'wrap', true)
            pcall(vim.api.nvim_win_set_option, self.state.winid, 'linebreak', true)
            pcall(vim.api.nvim_win_set_option, self.state.winid, 'breakindent', true)
          end
        end,
      },
      attach_mappings = function(bufnr, map)
        local actions = require 'telescope.actions'
        local action_state = require 'telescope.actions.state'
        local function open_log(pbuf)
          local sel = action_state.get_selected_entry()
          actions.close(pbuf)
          if not sel or not sel.value then
            return
          end
          vim.cmd('tabnew ' .. vim.fn.fnameescape(sel.value))
        end
        map('i', '<CR>', open_log)
        map('n', '<CR>', open_log)
        return true
      end,
    })
    :find()
end

-- Telescope picker for make: select cwd (resolved outside) -> list targets -> run
-- External dependencies are injected to avoid circular requires.
-- Args:
--   config: plugin config table
--   resolve_make_cwd_async(base, cb)
--   parse_make_targets_in_cwd_async(cwd, cb)
--   make_run_in_cwd(target, cwd)
--   choose_make(): string|nil
--   shell_quote_path(path): string
--   run_make_in_terminal(cmdline): nil
function M.telescope_make(
  config,
  resolve_make_cwd_async,
  parse_make_targets_in_cwd_async,
  make_run_in_cwd,
  choose_make,
  shell_quote_path,
  run_make_in_terminal
)
  if not (config.make and config.make.enabled ~= false) then
    vim.notify('Make feature not enabled', vim.log.levels.WARN)
    return
  end
  local ok_t = pcall(require, 'telescope')
  if not ok_t then
    vim.notify('telescope.nvim not found', vim.log.levels.ERROR)
    return
  end

  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values

  -- Always use current file directory as base; relative make.cwd will be resolved inside resolver
  local base = vim.fn.fnamemodify(vim.fn.expand '%:p', ':h')
  resolve_make_cwd_async(base, function(cwd)
    parse_make_targets_in_cwd_async(cwd, function(res)
      local targets, phony_set = {}, {}
      if type(res) == 'table' and res.targets then
        targets = res.targets or {}
        phony_set = res.phony or {}
      else
        targets = res or {}
      end
      if #targets == 0 then
        local pickers = require 'telescope.pickers'
        local finders = require 'telescope.finders'
        local conf = require('telescope.config').values
        local previewers = require 'telescope.previewers'
        pickers
          .new({}, {
            prompt_title = 'Make Targets (' .. cwd .. ')',
            finder = finders.new_table {
              results = { { display = '[No Make targets found]', kind = 'empty' } },
              entry_maker = function(e)
                return { value = e.value, display = e.display, ordinal = e.display, kind = e.kind }
              end,
            },
            sorter = conf.generic_sorter {},
            previewer = previewers.new_buffer_previewer {
              define_preview = function(self)
                local lines = {
                  '[Empty State]',
                  'No Make targets found. You can:',
                  '1) Verify Makefile exists in directory',
                  '2) Run make -qp in project root to check output',
                  '3) Adjust quick-c make.search or make.cwd config',
                }
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
              end,
            },
          })
          :find()
        return
      end
      local telcfg = (config.make and config.make.telescope) or {}
      local mktargets = (config.make and config.make.targets) or {}
      local mkargs = (config.make and config.make.args) or {}
      local phony_only = false

      local function build_entries()
        local entries = {}
        table.insert(entries, { display = '[Custom args...]', kind = 'args' })
        local list = {}
        if mktargets.prioritize_phony ~= false then
          local a, b = {}, {}
          for _, t in ipairs(targets) do
            if phony_set[t] then
              table.insert(a, t)
            else
              table.insert(b, t)
            end
          end
          list = {}
          if phony_only then
            list = a
          else
            for _, t in ipairs(a) do
              table.insert(list, t)
            end
            for _, t in ipairs(b) do
              table.insert(list, t)
            end
          end
        else
          list = targets
        end
        for _, t in ipairs(list) do
          local disp = phony_set[t] and (t .. ' [PHONY]') or t
          table.insert(entries, { display = disp, value = t, kind = 'target', phony = phony_set[t] or false })
        end
        return entries
      end

      local entries = build_entries()
      local title = (config.make.telescope and config.make.telescope.prompt_title) or 'Make Targets'
      pickers
        .new({}, {
          prompt_title = title .. ' (' .. cwd .. ')',
          finder = finders.new_table {
            results = entries,
            entry_maker = function(e)
              return { value = e.value, display = e.display, ordinal = e.display, kind = e.kind, phony = e.phony }
            end,
          },
          sorter = conf.generic_sorter {},
          previewer = (function()
            if telcfg.preview == false then
              return nil
            end
            local previewers = require 'telescope.previewers'
            local conf_t = require('telescope.config').values
            local uv = vim.loop
            local names = { 'Makefile', 'makefile', 'GNUmakefile' }
            local function find_makefile(dir)
              for _, n in ipairs(names) do
                local p = U.join(dir, n)
                local st = uv.fs_stat(p)
                if st and st.type == 'file' then
                  return p
                end
              end
              return nil
            end
            return previewers.new_buffer_previewer {
              define_preview = function(self, entry)
                local path = find_makefile(cwd)
                if not path or path == '' then
                  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { '[No Makefile found]' })
                  return
                end
                -- Normalize to absolute path
                local abspath = vim.fn.fnamemodify(path, ':p')
                local st = uv.fs_stat(abspath) or {}
                local max_bytes = telcfg.max_preview_bytes or (200 * 1024)
                local max_lines = telcfg.max_preview_lines or 2000
                local set_ft = (telcfg.set_filetype ~= false)
                local target_line_idx = nil
                local function escape_lua_magic(s)
                  local matches = { ['^']='%^', ['$']='%$', ['(']='%(', [')']='%)', ['%']='%%', ['.']='%.', ['[']='%[', [']']='%]', ['*']='%*', ['+']='%+', ['-']='%-', ['?']='%?' }
                  return (s:gsub('.', matches))
                end
                local function to_vim_pat(target)
                  -- Build Vim regex: ^\s*<escaped_target>\s*:
                  local escaped = vim.fn.escape(target, '\\^$.*[]')
                  return '^\\s*' .. escaped .. '\\s*:'
                end
                if st.size and st.size > max_bytes then
                  local ok, lines = pcall(vim.fn.readfile, abspath, '', max_lines)
                  if not ok or not lines then
                    lines = { '[Preview truncated: failed to read file]' }
                  end
                  table.insert(
                    lines,
                    1,
                    string.format(
                      '[Preview truncated: %d bytes > %d bytes, showing first %d lines]',
                      st.size or 0,
                      max_bytes,
                      max_lines
                    )
                  )
                  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
                  -- try to locate target within loaded lines
                  if entry and entry.kind == 'target' and type(entry.value) == 'string' then
                    local pat = '^%s*' .. escape_lua_magic(entry.value) .. '%s*:'
                    for i = 1, #lines do
                      if type(lines[i]) == 'string' and lines[i]:match(pat) then
                        target_line_idx = i
                        break
                      end
                    end
                  end
                else
                  local ok =
                    pcall(conf_t.buffer_previewer_maker, abspath, self.state.bufnr, { bufname = self.state.bufname })
                  if not ok then
                    local ok2, lines = pcall(vim.fn.readfile, abspath)
                    if not ok2 or not lines then
                      lines = { '[Failed to read Makefile]' }
                    end
                    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
                    if entry and entry.kind == 'target' and type(entry.value) == 'string' then
                      local pat = '^%s*' .. escape_lua_magic(entry.value) .. '%s*:'
                      for i = 1, #lines do
                        if type(lines[i]) == 'string' and lines[i]:match(pat) then
                          target_line_idx = i
                          break
                        end
                      end
                    end
                  end
                end
                if set_ft then
                  pcall(vim.api.nvim_buf_set_option, self.state.bufnr, 'filetype', 'make')
                end
                -- enable wrapping for long lines in preview window
                if self.state and self.state.winid then
                  pcall(vim.api.nvim_win_set_option, self.state.winid, 'wrap', true)
                  pcall(vim.api.nvim_win_set_option, self.state.winid, 'linebreak', true)
                  pcall(vim.api.nvim_win_set_option, self.state.winid, 'breakindent', true)
                end
                -- place cursor at target definition if found (defer to ensure window/layout is ready)
                local function jump(i, lua_pat, vim_pat)
                  if not (self.state and self.state.winid and i) then
                    -- fallback: if i not provided, try pattern search later
                    if self.state and self.state.winid and (vim_pat or lua_pat) then
                      local vpat = vim_pat
                      if not vpat and entry and entry.kind == 'target' and type(entry.value) == 'string' then
                        vpat = to_vim_pat(entry.value)
                      end
                      vim.defer_fn(function()
                        pcall(vim.api.nvim_win_call, self.state.winid, function()
                          if vpat then
                            pcall(vim.fn.setreg, '/', vpat)
                            pcall(vim.fn.search, vpat, 'w')
                            pcall(vim.cmd, 'normal! zz')
                          end
                        end)
                      end, 50)
                    end
                    return
                  end
                  vim.defer_fn(function()
                    pcall(vim.api.nvim_win_set_cursor, self.state.winid, { i, 0 })
                    pcall(vim.api.nvim_win_call, self.state.winid, function()
                      pcall(vim.cmd, 'normal! zz')
                    end)
                    pcall(vim.api.nvim_buf_add_highlight, self.state.bufnr, -1, 'Search', i - 1, 0, -1)
                  end, 50)
                end
                local vpat_final = nil
                if entry and entry.kind == 'target' and type(entry.value) == 'string' then
                  vpat_final = to_vim_pat(entry.value)
                end
                if target_line_idx then
                  jump(target_line_idx, nil, vpat_final)
                else
                  if entry and entry.kind == 'target' and type(entry.value) == 'string' then
                    local buflines = vim.api.nvim_buf_get_lines(self.state.bufnr, 0, -1, false)
                    local pat = '^%s*' .. escape_lua_magic(entry.value) .. '%s*:'
                    for i = 1, #buflines do
                      if type(buflines[i]) == 'string' and buflines[i]:match(pat) then
                        jump(i, pat, vpat_final)
                        break
                      end
                    end
                  end
                end
                -- Always run a second-chance search after Telescope finishes drawing
                if vpat_final then
                  vim.defer_fn(function()
                    if self.state and self.state.winid then
                      pcall(vim.api.nvim_win_call, self.state.winid, function()
                        pcall(vim.fn.setreg, '/', vpat_final)
                        pcall(vim.fn.search, vpat_final, 'w')
                        pcall(vim.cmd, 'normal! zz')
                      end)
                    end
                  end, 120)
                end
              end,
            }
          end)(),
          attach_mappings = function(bufnr, map)
            local actions = require 'telescope.actions'
            local action_state = require 'telescope.actions.state'
            local function run_with_args(target)
              local def = mkargs.default or ''
              if mkargs.remember ~= false then
                def = LAST_ARGS[cwd] or def
              end
              local ui = vim.ui or {}
              if not ui.input then
                make_run_in_cwd(target, cwd)
                return
              end
              ui.input({ prompt = 'make args: ', default = def }, function(arg)
                if arg and arg ~= '' then
                  if mkargs.remember ~= false then
                    LAST_ARGS[cwd] = arg
                  end
                  local prog = choose_make()
                  if not prog then
                    vim.notify('make or mingw32-make not found', vim.log.levels.ERROR)
                    return
                  end
                  local no_dash_C = (config.make and config.make.no_dash_C) == true
                  local cmd
                  if no_dash_C then
                    cmd = string.format('%s %s %s', prog, target or '', arg)
                  else
                    cmd = string.format('%s -C %s %s %s', prog, shell_quote_path(cwd), target or '', arg)
                  end
                  run_make_in_terminal(cmd)
                else
                  make_run_in_cwd(target, cwd)
                end
              end)
            end

            local function choose(pbuf)
              local entry = action_state.get_selected_entry()
              if not entry then
                actions.close(pbuf)
                return
              end
              actions.close(pbuf)
              if entry.kind == 'args' then
                local def = mkargs.default or ''
                if mkargs.remember ~= false then
                  def = LAST_ARGS[cwd] or def
                end
                local ui = vim.ui or {}
                if not ui.input then
                  return
                end
                ui.input({ prompt = 'make args: ', default = def }, function(arg)
                  if not arg or arg == '' then
                    return
                  end
                  if mkargs.remember ~= false then
                    LAST_ARGS[cwd] = arg
                  end
                  local prog = choose_make()
                  if not prog then
                    vim.notify('make or mingw32-make not found', vim.log.levels.ERROR)
                    return
                  end
                  local no_dash_C = (config.make and config.make.no_dash_C) == true
                  local cmd
                  if no_dash_C then
                    cmd = string.format('%s %s', prog, arg)
                  else
                    cmd = string.format('%s -C %s %s', prog, shell_quote_path(cwd), arg)
                  end
                  run_make_in_terminal(cmd)
                end)
                return
              end
              if mkargs.prompt ~= false then
                run_with_args(entry.value)
              else
                make_run_in_cwd(entry.value, cwd)
              end
            end
            map('i', '<CR>', choose)
            map('n', '<CR>', choose)
            local function toggle_phony_only()
              phony_only = not phony_only
              local picker = action_state.get_current_picker(bufnr)
              local new_entries = build_entries()
              picker:refresh(
                finders.new_table {
                  results = new_entries,
                  entry_maker = function(e)
                    return { value = e.value, display = e.display, ordinal = e.display, kind = e.kind, phony = e.phony }
                  end,
                },
                { reset_prompt = false }
              )
            end
            map('i', '<C-p>', toggle_phony_only)
            map('n', '<C-p>', toggle_phony_only)
            return true
          end,
        })
        :find()
    end)
  end)
end

-- Telescope picker for CMake: resolve root -> ensure configured -> list targets -> run
function M.telescope_cmake(config)
  local ok_t = pcall(require, 'telescope')
  if not ok_t then
    vim.notify('telescope.nvim not found', vim.log.levels.ERROR)
    return
  end
  local CM = require 'quick-c.cmake'
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local base = vim.fn.fnamemodify(vim.fn.expand '%:p', ':h')
  CM.resolve_root_async(config, base, function(root)
    CM.list_targets_async(config, root, function(targets)
      if not targets or #targets == 0 then
        local pickers = require 'telescope.pickers'
        local finders = require 'telescope.finders'
        local conf = require('telescope.config').values
        local previewers = require 'telescope.previewers'
        local entries = { { display = '[Configure]', kind = 'configure' } }
        pickers
          .new({}, {
            prompt_title = 'CMake Targets (' .. root .. ')',
            finder = finders.new_table {
              results = entries,
              entry_maker = function(e)
                return { value = e.value, display = e.display, ordinal = e.display, kind = e.kind }
              end,
            },
            sorter = conf.generic_sorter {},
            previewer = previewers.new_buffer_previewer {
              define_preview = function(self)
                local lines = {
                  '[Empty State]',
                  'No CMake targets found:',
                  '- Generator may not support --target help',
                  '- Or not configured yet (select [Configure] first)',
                }
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
              end,
            },
            attach_mappings = function(bufnr, map)
              local actions = require 'telescope.actions'
              local action_state = require 'telescope.actions.state'
              local function choose(pbuf)
                local entry = action_state.get_selected_entry()
                actions.close(pbuf)
                if entry.kind == 'configure' then
                  CM.ensure_configured_async(config, root, function(ok)
                    if ok then
                      U.notify_info 'CMake configuration complete'
                    else
                      U.notify_err 'CMake configuration failed'
                    end
                  end)
                end
              end
              map('i', '<CR>', choose)
              map('n', '<CR>', choose)
              return true
            end,
          })
          :find()
        return
      end
      local entries = {}
      table.insert(entries, { display = '[configure]', kind = 'configure' })
      for _, t in ipairs(targets) do
        table.insert(entries, { display = t, value = t, kind = 'target' })
      end
      local title = (config.cmake and config.cmake.telescope and config.cmake.telescope.prompt_title) or 'CMake Targets'
      pickers
        .new({}, {
          prompt_title = title .. ' (' .. root .. ')',
          finder = finders.new_table {
            results = entries,
            entry_maker = function(e)
              return { value = e.value, display = e.display, ordinal = e.display, kind = e.kind }
            end,
          },
          sorter = conf.generic_sorter {},
          previewer = (function()
            local previewers = require 'telescope.previewers'
            local conf_t = require('telescope.config').values
            local uv = vim.loop
            local function find_cmakelists(dir)
              local p = U.join(dir, 'CMakeLists.txt')
              local st = uv.fs_stat(p)
              if st and st.type == 'file' then
                return p
              end
              return nil
            end
            return previewers.new_buffer_previewer {
              define_preview = function(self, entry)
                local path = find_cmakelists(root)
                if not path or path == '' then
                  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { '[No CMakeLists.txt found]' })
                  return
                end
                local abspath = vim.fn.fnamemodify(path, ':p')
                local st = uv.fs_stat(abspath) or {}
                local max_bytes = ((config.cmake and config.cmake.telescope and config.cmake.telescope.max_preview_bytes) or (200 * 1024))
                local max_lines = ((config.cmake and config.cmake.telescope and config.cmake.telescope.max_preview_lines) or 2000)
                local set_ft = true
                local target_line_idx = nil
                local function escape_lua_magic(s)
                  local matches = { ['^']='%^', ['$']='%$', ['(']='%(', [')']='%)', ['%']='%%', ['.']='%.', ['[']='%[', [']']='%]', ['*']='%*', ['+']='%+', ['-']='%-', ['?']='%?' }
                  return (s:gsub('.', matches))
                end
                local function to_vim_pat(target)
                  -- Common CMake target definition patterns
                  -- 1) add_executable/add_library/add_custom_target(<t>
                  -- 2) target_* (<t> ...)
                  local esc = vim.fn.escape(target, '\\^$.*[]')
                  local p1 = [[^\s*\%(add_executable\|add_library\|add_custom_target\)\s*(]] .. [[\s*]] .. esc .. [[\>.*]]
                  local p2 = [[^\s*target_[a-zA-Z_][a-zA-Z0-9_]*\s*(]] .. [[\s*]] .. esc .. [[\>.*]]
                  return [[\v\%(]] .. p1 .. [[\|]] .. p2 .. [[\)]]
                end
                if st.size and st.size > max_bytes then
                  local ok, lines = pcall(vim.fn.readfile, abspath, '', max_lines)
                  if not ok or not lines then
                    lines = { '[Preview truncated: failed to read file]' }
                  end
                  table.insert(lines, 1, string.format('[Preview truncated: %d bytes > %d bytes, showing first %d lines]', st.size or 0, max_bytes, max_lines))
                  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
                  if entry and entry.kind == 'target' and type(entry.value) == 'string' then
                    -- simple heuristic on truncated content
                    local pats = {
                      '^%s*add_executable%s*%(',
                      '^%s*add_library%s*%(',
                      '^%s*add_custom_target%s*%(',
                      '^%s*target_%w+%s*%(',
                    }
                    for i = 1, #lines do
                      local ln = lines[i]
                      if type(ln) == 'string' then
                        for _, p in ipairs(pats) do
                          if ln:match(p) and ln:match('%f[%w_]' .. escape_lua_magic(entry.value) .. '%f[^%w_]') then
                            target_line_idx = i
                            break
                          end
                        end
                        if target_line_idx then break end
                      end
                    end
                  end
                else
                  local ok = pcall(conf_t.buffer_previewer_maker, abspath, self.state.bufnr, { bufname = self.state.bufname })
                  if not ok then
                    local ok2, lines = pcall(vim.fn.readfile, abspath)
                    if not ok2 or not lines then
                      lines = { '[Failed to read CMakeLists.txt]' }
                    end
                    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
                    if entry and entry.kind == 'target' and type(entry.value) == 'string' then
                      local pats = {
                        '^%s*add_executable%s*%(',
                        '^%s*add_library%s*%(',
                        '^%s*add_custom_target%s*%(',
                        '^%s*target_%w+%s*%(',
                      }
                      for i = 1, #lines do
                        local ln = lines[i]
                        if type(ln) == 'string' then
                          for _, p in ipairs(pats) do
                            if ln:match(p) and ln:match('%f[%w_]' .. escape_lua_magic(entry.value) .. '%f[^%w_]') then
                              target_line_idx = i
                              break
                            end
                          end
                          if target_line_idx then break end
                        end
                      end
                    end
                  end
                end
                if set_ft then
                  pcall(vim.api.nvim_buf_set_option, self.state.bufnr, 'filetype', 'cmake')
                end
                -- wrapping for better readability
                if self.state and self.state.winid then
                  pcall(vim.api.nvim_win_set_option, self.state.winid, 'wrap', true)
                  pcall(vim.api.nvim_win_set_option, self.state.winid, 'linebreak', true)
                  pcall(vim.api.nvim_win_set_option, self.state.winid, 'breakindent', true)
                end
                -- deferred jump and fallback search
                local function jump(i, vpat)
                  if not (self.state and self.state.winid and i) then
                    if self.state and self.state.winid and vpat then
                      vim.defer_fn(function()
                        pcall(vim.api.nvim_win_call, self.state.winid, function()
                          pcall(vim.fn.setreg, '/', vpat)
                          pcall(vim.fn.search, vpat, 'w')
                          pcall(vim.cmd, 'normal! zz')
                        end)
                      end, 60)
                    end
                    return
                  end
                  vim.defer_fn(function()
                    pcall(vim.api.nvim_win_set_cursor, self.state.winid, { i, 0 })
                    pcall(vim.api.nvim_win_call, self.state.winid, function()
                      pcall(vim.cmd, 'normal! zz')
                    end)
                    pcall(vim.api.nvim_buf_add_highlight, self.state.bufnr, -1, 'Search', i - 1, 0, -1)
                  end, 50)
                end
                local vpat_final = nil
                if entry and entry.kind == 'target' and type(entry.value) == 'string' then
                  vpat_final = to_vim_pat(entry.value)
                end
                if target_line_idx then
                  jump(target_line_idx, vpat_final)
                elseif vpat_final then
                  jump(nil, vpat_final)
                end
                if vpat_final then
                  vim.defer_fn(function()
                    if self.state and self.state.winid then
                      pcall(vim.api.nvim_win_call, self.state.winid, function()
                        pcall(vim.fn.setreg, '/', vpat_final)
                        pcall(vim.fn.search, vpat_final, 'w')
                        pcall(vim.cmd, 'normal! zz')
                      end)
                    end
                  end, 120)
                end
              end,
            }
          end)(),
          attach_mappings = function(bufnr, map)
            local actions = require 'telescope.actions'
            local action_state = require 'telescope.actions.state'
            local function choose(pbuf)
              local entry = action_state.get_selected_entry()
              if not entry then
                actions.close(pbuf)
                return
              end
              actions.close(pbuf)
              if entry.kind == 'configure' then
                local notify = { err = U.notify_err, warn = U.notify_warn, info = U.notify_info }
                CM.ensure_configured_async(config, root, function(ok)
                  if ok then
                    notify.info 'CMake configured'
                  else
                    notify.err 'CMake configure failed'
                  end
                end)
                return
              end
              local function run_terminal(cmd)
                return T.select_or_run_in_terminal(config, function()
                  return U.is_windows()
                end, cmd, U.notify_warn, U.notify_err)
              end
              CM.build_in_root(config, root, entry.value, run_terminal)
            end
            map('i', '<CR>', choose)
            map('n', '<CR>', choose)
            return true
          end,
        })
        :find()
    end)
  end)
end

-- Telescope picker for Quick-c: select multiple C/C++ sources, then choose action
function M.telescope_quickc_sources(config)
  local ok_t = pcall(require, 'telescope')
  if not ok_t then
    vim.notify('telescope.nvim not found', vim.log.levels.ERROR)
    return
  end
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local cwd = vim.fn.getcwd()
  local function list_sources()
    local results = {}
    local patterns = { '**/*.c', '**/*.cpp', '**/*.cc', '**/*.cxx' }
    local seen = {}
    for _, pat in ipairs(patterns) do
      local files = vim.fn.glob(pat, true, true)
      for _, f in ipairs(files) do
        local p = vim.fn.fnamemodify(f, ':p')
        if vim.fn.filereadable(p) == 1 and not seen[p] then
          table.insert(results, p)
          seen[p] = true
        end
      end
    end
    return results
  end
  local files = list_sources()
  if #files == 0 then
    vim.notify('No C/C++ source files found in current working directory', vim.log.levels.WARN)
    return
  end
  local function to_entries(abs_list)
    local entries = {}
    for _, abs in ipairs(abs_list) do
      local rel = vim.fn.fnamemodify(abs, ':.')
      table.insert(entries, { display = rel, value = abs, ordinal = rel })
    end
    return entries
  end
  local entries = to_entries(files)
  pickers
    .new({}, {
      prompt_title = 'Quick-c: Select sources (' .. cwd .. ')',
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
        local function do_action()
          local picker = action_state.get_current_picker(bufnr)
          local multi = picker:get_multi_selection()
          local sel = action_state.get_selected_entry()
          local srcs = {}
          if multi and #multi > 0 then
            for _, e in ipairs(multi) do
              table.insert(srcs, e.value or e[1] or e.path or e)
            end
          elseif sel then
            table.insert(srcs, sel.value or sel[1] or sel.path)
          end
          actions.close(bufnr)
          if not srcs or #srcs == 0 then
            return
          end
          local ui = vim.ui or {}
          local items = {
            {
              name = 'Build',
              fn = function()
                require('quick-c.build').build(
                  config,
                  { err = U.notify_err, warn = U.notify_warn, info = U.notify_info },
                  { sources = srcs }
                )
              end,
            },
            {
              name = 'Run',
              fn = function()
                require('quick-c.build').run(
                  config,
                  { err = U.notify_err, warn = U.notify_warn, info = U.notify_info },
                  { sources = srcs }
                )
              end,
            },
            {
              name = 'Build & Run',
              fn = function()
                require('quick-c.build').build_and_run(
                  config,
                  { err = U.notify_err, warn = U.notify_warn, info = U.notify_info },
                  { sources = srcs }
                )
              end,
            },
          }
          if ui.select then
            ui.select({ items[1].name, items[2].name, items[3].name }, { prompt = '选择操作' }, function(choice)
              if choice == items[1].name then
                items[1].fn()
              end
              if choice == items[2].name then
                items[2].fn()
              end
              if choice == items[3].name then
                items[3].fn()
              end
            end)
          else
            items[1].fn()
          end
        end
        map('i', '<CR>', do_action)
        map('n', '<CR>', do_action)
        return true
      end,
    })
    :find()
end
-- Streaming Make targets picker: incremental updates, <C-p> toggle PHONY-only, <C-c> cancel
function M.telescope_make_stream(config)
  local ok_t = pcall(require, 'telescope')
  if not ok_t then
    vim.notify('telescope.nvim not found', vim.log.levels.ERROR)
    return
  end
  local MK = require 'quick-c.make'
  local MSR = require 'quick-c.make_search'
  local TASK = require 'quick-c.task'
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local base = vim.fn.fnamemodify(vim.fn.expand '%:p', ':h')
  local telcfg = (config.make and config.make.telescope) or {}
  local phony_only = false
  local seen = {}
  local all_targets = {}
  local phony_set = {}
  local handle = nil
  local scan_state = { completed = false }

  local function build_entries()
    local entries = { { display = '[Custom args...]', kind = 'args' } }
    local list
    if (config.make and config.make.targets and config.make.targets.prioritize_phony) ~= false then
      local a, b = {}, {}
      for _, t in ipairs(all_targets) do
        if phony_set[t] then table.insert(a, t) else table.insert(b, t) end
      end
      list = {}
      if phony_only then
        list = a
      else
        for _, t in ipairs(a) do table.insert(list, t) end
        for _, t in ipairs(b) do table.insert(list, t) end
      end
    else
      list = all_targets
    end
    for _, t in ipairs(list) do
      local disp = phony_set[t] and (t .. ' [PHONY]') or t
      table.insert(entries, { display = disp, value = t, kind = 'target', phony = phony_set[t] or false })
    end
    return entries
  end

  local function open_picker(cwd)
    local title = (config.make and config.make.telescope and config.make.telescope.prompt_title) or 'Make Targets'
    local picker
    picker = pickers.new({}, {
      prompt_title = title .. ' (' .. cwd .. ')',
      finder = finders.new_table {
        results = { { display = '[Loading targets…]', kind = 'loading' } },
        entry_maker = function(e)
          return { value = e.value, display = e.display, ordinal = e.display, kind = e.kind, phony = e.phony }
        end,
      },
      sorter = conf.generic_sorter {},
      previewer = (function()
        if telcfg.preview == false then
          return nil
        end
        local previewers = require 'telescope.previewers'
        local conf_t = require('telescope.config').values
        local uv = vim.loop
        local names = { 'Makefile', 'makefile', 'GNUmakefile' }
        local function find_makefile(dir)
          for _, n in ipairs(names) do
            local p = U.join(dir, n)
            local st = uv.fs_stat(p)
            if st and st.type == 'file' then
              return p
            end
          end
          return nil
        end
        local function escape_lua_magic(s)
          local matches = { ['^']='%^', ['$']='%$', ['(']='%(', [')']='%)', ['%']='%%', ['.']='%.', ['[']='%[', [']']='%]', ['*']='%*', ['+']='%+', ['-']='%-', ['?']='%?' }
          return (s:gsub('.', matches))
        end
        local function to_vim_pat(target)
          local escaped = vim.fn.escape(target, '\\^$.*[]')
          return '^\\s*' .. escaped .. '\\s*:'
        end
        return previewers.new_buffer_previewer {
          define_preview = function(self, entry)
            local path = find_makefile(cwd)
            if not path or path == '' then
              vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { '[No Makefile found]' })
              return
            end
            local abspath = vim.fn.fnamemodify(path, ':p')
            local st = uv.fs_stat(abspath) or {}
            local max_bytes = telcfg.max_preview_bytes or (200 * 1024)
            local max_lines = telcfg.max_preview_lines or 2000
            local set_ft = (telcfg.set_filetype ~= false)
            local target_line_idx = nil
            if st.size and st.size > max_bytes then
              local ok, lines = pcall(vim.fn.readfile, abspath, '', max_lines)
              if not ok or not lines then
                lines = { '[Preview truncated: failed to read file]' }
              end
              table.insert(
                lines,
                1,
                string.format('[Preview truncated: %d bytes > %d bytes, showing first %d lines]', st.size or 0, max_bytes, max_lines)
              )
              vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
              if entry and entry.kind == 'target' and type(entry.value) == 'string' then
                local pat = '^%s*' .. escape_lua_magic(entry.value) .. '%s*:'
                for i = 1, #lines do
                  if type(lines[i]) == 'string' and lines[i]:match(pat) then
                    target_line_idx = i
                    break
                  end
                end
              end
            else
              local ok = pcall(conf_t.buffer_previewer_maker, abspath, self.state.bufnr, { bufname = self.state.bufname })
              if not ok then
                local ok2, lines = pcall(vim.fn.readfile, abspath)
                if not ok2 or not lines then
                  lines = { '[Failed to read Makefile]' }
                end
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
                if entry and entry.kind == 'target' and type(entry.value) == 'string' then
                  local pat = '^%s*' .. escape_lua_magic(entry.value) .. '%s*:'
                  for i = 1, #lines do
                    if type(lines[i]) == 'string' and lines[i]:match(pat) then
                      target_line_idx = i
                      break
                    end
                  end
                end
              end
            end
            if set_ft then
              pcall(vim.api.nvim_buf_set_option, self.state.bufnr, 'filetype', 'make')
            end
            local function jump(i, vim_pat)
              if not (self.state and self.state.winid and i) then
                if self.state and self.state.winid and vim_pat then
                  vim.defer_fn(function()
                    pcall(vim.api.nvim_win_call, self.state.winid, function()
                      pcall(vim.fn.setreg, '/', vim_pat)
                      pcall(vim.fn.search, vim_pat, 'w')
                      pcall(vim.cmd, 'normal! zz')
                    end)
                  end, 60)
                end
                return
              end
              vim.defer_fn(function()
                pcall(vim.api.nvim_win_set_cursor, self.state.winid, { i, 0 })
                pcall(vim.api.nvim_win_call, self.state.winid, function()
                  pcall(vim.cmd, 'normal! zz')
                end)
                pcall(vim.api.nvim_buf_add_highlight, self.state.bufnr, -1, 'Search', i - 1, 0, -1)
              end, 50)
            end
            local vpat_final = nil
            if entry and entry.kind == 'target' and type(entry.value) == 'string' then
              vpat_final = to_vim_pat(entry.value)
            end
            if target_line_idx then
              jump(target_line_idx, vpat_final)
            elseif vpat_final then
              jump(nil, vpat_final)
            end
          end,
        }
      end)(),
      attach_mappings = function(bufnr, map)
        local actions = require 'telescope.actions'
        local action_state = require 'telescope.actions.state'
        local function run_with_args(target)
          local mkargs = (config.make and config.make.args) or {}
          local def = mkargs.default or ''
          if mkargs.remember ~= false then
            vim.g.quick_c_make_last_args = vim.g.quick_c_make_last_args or {}
            def = vim.g.quick_c_make_last_args[cwd] or def
          end
          local ui = vim.ui or {}
          if not ui.input then
            require('quick-c.make').make_run_in_cwd(config, cwd, target, function(cmd)
              return require('quick-c.terminal').select_or_run_in_terminal(config, require('quick-c.util').is_windows, cmd, function(msg) vim.notify(msg, vim.log.levels.WARN) end, function(msg) vim.notify(msg, vim.log.levels.ERROR) end)
            end)
            return
          end
          ui.input({ prompt = 'make args: ', default = def }, function(arg)
            if arg and arg ~= '' then
              if mkargs.remember ~= false then vim.g.quick_c_make_last_args[cwd] = arg end
              local prog = require('quick-c.make').choose_make(config)
              if not prog then
                vim.notify('make or mingw32-make not found', vim.log.levels.ERROR)
                return
              end
              local no_dash_C = (config.make and config.make.no_dash_C) == true
              local cmd
              if no_dash_C then cmd = string.format('%s %s %s', prog, target or '', arg) else cmd = string.format('%s -C %s %s %s', prog, require('quick-c.util').shell_quote_path(cwd), target or '', arg) end
              require('quick-c.terminal').select_or_run_in_terminal(config, require('quick-c.util').is_windows, cmd, function(msg) vim.notify(msg, vim.log.levels.WARN) end, function(msg) vim.notify(msg, vim.log.levels.ERROR) end)
            else
              require('quick-c.make').make_run_in_cwd(config, cwd, target, function(cmd)
                return require('quick-c.terminal').select_or_run_in_terminal(config, require('quick-c.util').is_windows, cmd, function(msg) vim.notify(msg, vim.log.levels.WARN) end, function(msg) vim.notify(msg, vim.log.levels.ERROR) end)
              end)
            end
          end)
        end
        local function choose(pbuf)
          local entry = action_state.get_selected_entry()
          actions.close(pbuf)
          if not entry then return end
          if entry.kind == 'args' then
            local mkargs = (config.make and config.make.args) or {}
            local def = mkargs.default or ''
            if mkargs.remember ~= false then vim.g.quick_c_make_last_args = vim.g.quick_c_make_last_args or {}; def = vim.g.quick_c_make_last_args[cwd] or def end
            local ui = vim.ui or {}
            if not ui.input then return end
            ui.input({ prompt = 'make args: ', default = def }, function(arg)
              if not arg or arg == '' then return end
              if mkargs.remember ~= false then vim.g.quick_c_make_last_args[cwd] = arg end
              local prog = require('quick-c.make').choose_make(config)
              if not prog then vim.notify('make or mingw32-make not found', vim.log.levels.ERROR); return end
              local no_dash_C = (config.make and config.make.no_dash_C) == true
              local cmd
              if no_dash_C then cmd = string.format('%s %s', prog, arg) else cmd = string.format('%s -C %s %s', prog, require('quick-c.util').shell_quote_path(cwd), arg) end
              require('quick-c.terminal').select_or_run_in_terminal(config, require('quick-c.util').is_windows, cmd, function(msg) vim.notify(msg, vim.log.levels.WARN) end, function(msg) vim.notify(msg, vim.log.levels.ERROR) end)
            end)
            return
          end
          run_with_args(entry.value)
        end
        map('i', '<CR>', choose)
        map('n', '<CR>', choose)
        local function toggle_phony_only()
          phony_only = not phony_only
          local picker_obj = action_state.get_current_picker(bufnr)
          picker_obj:refresh(
            finders.new_table {
              results = build_entries(),
              entry_maker = function(e)
                return { value = e.value, display = e.display, ordinal = e.display, kind = e.kind, phony = e.phony }
              end,
            },
            { reset_prompt = false }
          )
        end
        map('i', '<C-p>', toggle_phony_only)
        map('n', '<C-p>', toggle_phony_only)
        local function cancel_scan()
          TASK.cancel_current()
          vim.notify('Quick-c: make scan canceled', vim.log.levels.INFO)
        end
        map('i', '<C-c>', cancel_scan)
        map('n', '<C-c>', cancel_scan)
        -- Auto cancel when picker buffer closes
        if bufnr and bufnr > 0 then
          pcall(vim.api.nvim_create_autocmd, 'BufWipeout', {
            buffer = bufnr,
            callback = function()
              if not scan_state.completed then
                TASK.cancel_current()
                vim.schedule(function()
                  vim.notify('Quick-c: closed picker, stopped make scan', vim.log.levels.INFO)
                end)
              end
            end,
          })
        end
        return true
      end,
    })
    picker:find()
    return picker
  end

  local base_dir = base
  MSR.resolve_make_cwd_async(config, base_dir, function(cwd)
    local picker = open_picker(cwd)
    local title_base = picker.prompt_title
    local canceled_flag = false
    TASK.enqueue({
      name = 'make-scan',
      target = cwd,
      timeout_ms = (config.make and tonumber(config.make.parse_timeout_ms)) or 0,
      start = function(done)
        handle = MK.parse_make_targets_stream_async(config, cwd, function(ev)
          if ev.kind == 'batch' then
            for _, t in ipairs(ev.targets or {}) do
              if not seen[t] then
                seen[t] = true
                table.insert(all_targets, t)
              end
            end
            for k, v in pairs(ev.phony or {}) do if v then phony_set[k] = true end end
            local entries = build_entries()
            picker:refresh(
              finders.new_table {
                results = entries,
                entry_maker = function(e)
                  return { value = e.value, display = e.display, ordinal = e.display, kind = e.kind, phony = e.phony }
                end,
              },
              { reset_prompt = false }
            )
          elseif ev.kind == 'done' then
            seen = {}
            all_targets = {}
            for _, t in ipairs(ev.targets or {}) do seen[t] = true; table.insert(all_targets, t) end
            phony_set = ev.phony or {}
            local entries = build_entries()
            picker.prompt_title = title_base .. ' ✓('
              .. tostring(#entries - 1) .. ' targets)'
            picker:refresh(
              finders.new_table {
                results = entries,
                entry_maker = function(e)
                  return { value = e.value, display = e.display, ordinal = e.display, kind = e.kind, phony = e.phony }
                end,
              },
              { reset_prompt = false }
            )
            scan_state.completed = true
            done(0)
          elseif ev.kind == 'error' then
            picker.prompt_title = title_base .. ' ✗'
            picker:refresh(
              finders.new_table {
                results = { { display = '[Failed to parse make targets]', kind = 'empty' } },
                entry_maker = function(e)
                  return { value = e.value, display = e.display, ordinal = e.display, kind = e.kind }
                end,
              },
              { reset_prompt = false }
            )
            done(1)
          end
        end)
      end,
      cancel = function()
        canceled_flag = true
        if handle and handle.cancel then pcall(handle.cancel) end
      end,
      on_exit = function(code)
        -- Update title using standardized status label
        local S = require 'quick-c.status'
        local label = S.last_label()
        if canceled_flag and not label then label = 'Canceled' end
        if label and label ~= 'OK' then
          picker.prompt_title = title_base .. ' [' .. label .. ']'
        end
        -- Refresh to apply title change without resetting entries
        picker:refresh(
          finders.new_table {
            results = build_entries(),
            entry_maker = function(e)
              return { value = e.value, display = e.display, ordinal = e.display, kind = e.kind, phony = e.phony }
            end,
          },
          { reset_prompt = false }
        )
      end,
    })
  end)
end

return M