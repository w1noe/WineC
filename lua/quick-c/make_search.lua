---
 --- quick-c: Makefile 目录异步搜索工具
 --- @module quick-c.make_search
 --- @desc 异步、非阻塞地在项目中搜索包含 Makefile 的目录，提供：
 ---   1) 单个候选目录搜索（最近的根）
 ---   2) 多个候选目录收集（用于选择器）
 ---   3) 基于配置解析 make.cwd（含向下搜索与 Telescope 选择）
 --- 使用分批处理 + libuv 异步接口，结合 TTL 缓存，避免阻塞 Neovim 主线程。
 local U = require 'quick-c.util'
 local M = {}

 -- 简单 TTL 缓存：
 -- single: 单根目录搜索结果；multi: 多根目录搜索列表
 local _cache = { single = {}, multi = {} }

 --- 获取缓存过期时间（秒）
 ---@param config table quick-c 配置
 ---@return number
 local function _ttl(config)
  local c = (config.make and config.make.cache and config.make.cache.ttl) or 10
  return tonumber(c) or 10
 end

 --- 获取当前时间戳
 ---@return number
 local function _now()
  return os.time()
 end

 --- 以异步优先的方式读取目录项，失败时回退同步并 schedule 回主线程
 ---@param uv uv
 ---@param dir string
 ---@param ondone fun(entries: {name:string,type:string}[])
 local function scandir_async(uv, dir, ondone)
  -- 兼容两种环境：
  -- 1) 某些运行时可能提供回调式 fs_scandir（少见）
  -- 2) Neovim/luv 中 fs_scandir 为同步 API（常见，CI 环境）
  -- 策略：尝试回调式；若短时间未触发，则回退同步扫描，并确保只回调一次。
  local done = false
  local function safe_done(list)
    if done then
      return
    end
    done = true
    vim.schedule(function()
      ondone(list or {})
    end)
  end

  -- 尝试回调式（若不支持，该调用不会触发回调）
  pcall(function()
    uv.fs_scandir(dir, function(err, req)
      if done then
        return
      end
      if err or not req then
        safe_done {}
        return
      end
      local out = {}
      while true do
        local name, t = uv.fs_scandir_next(req)
        if not name then
          break
        end
        out[#out + 1] = { name = name, type = t }
      end
      safe_done(out)
    end)
  end)

  -- 定时兜底：若回调未在极短时间内触发，执行同步扫描并异步回调
  vim.defer_fn(function()
    if done then
      return
    end
    local req = uv.fs_scandir(dir)
    local out = {}
    if req then
      while true do
        local name, t = uv.fs_scandir_next(req)
        if not name then
          break
        end
        out[#out + 1] = { name = name, type = t }
      end
    end
    safe_done(out)
  end, 5)
 end

 --- 异步查找最近的包含 Makefile 的目录（受 :pwd 边界与忽略目录控制）
 ---@param config table quick-c 配置（使用 make.search.{up,down,ignore_dirs} 与 cache.ttl）
 ---@param start_dir string 起点目录（通常为当前文件目录）
 ---@param cb fun(dir:string) 回调，参数为找到的目录；找不到时回退为 start_dir
 function M.find_make_root_async(config, start_dir, cb)
  local cfg = config.make or {}
  local up = (cfg.search and cfg.search.up) or 2
  local down = (cfg.search and cfg.search.down) or 3
  local ignore = (cfg.search and cfg.search.ignore_dirs) or { '.git', 'node_modules', '.cache' }
  local names = { 'Makefile', 'makefile', 'GNUmakefile' }
  local uv = vim.loop

  local key = table.concat({ U.norm(start_dir or ''), up, down }, '|')
  do
    local ent = _cache.single[key]
    if ent and (_now() - ent.ts) < _ttl(config) then
      -- 命中缓存：异步回调，保持接口一致
      vim.schedule(function()
        cb(ent.val)
      end)
      return
    end
  end

  local function _done(dir)
    _cache.single[key] = { val = dir, ts = _now() }
    vim.schedule(function()
      cb(dir)
    end)
  end

  local function is_ignored(name)
    for _, n in ipairs(ignore) do
      if name == n then
        return true
      end
    end
    return false
  end
  local function has_makefile(dir)
    for _, n in ipairs(names) do
      local st = uv.fs_stat(U.join(dir, n))
      if st and st.type == 'file' then
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

  local cwd_root = U.norm(vim.fn.getcwd()) -- 限制向上查找不越界于当前工作根

  -- 预生成“向上各层”的 BFS 起点（包含起点自身），受工作目录边界限制
  local bases = {}
  do
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
  end

  -- BFS 队列：每个元素为 { dir, depth }
  local queue = {}
  for _, b in ipairs(bases) do
    table.insert(queue, { dir = b, depth = 0 })
  end

  local scanning = false
  local found = false
  local batch_size = 40 -- 每个调度 tick 处理的目录数（控制占用）
  -- 并发工作者数：优先 make.concurrency，其次 debug.concurrency，最后默认 8
  local parallel = tonumber((config.make and config.make.concurrency)
    or (config.debug and config.debug.concurrency)
    or 8) or 8

  local function step()
    if scanning then
      return
    end
    if found then
      return
    end
    scanning = true
    local taken = {}
    local n = math.min(batch_size, #queue, parallel)
    for i = 1, n do
      taken[i] = table.remove(queue, 1)
    end
    if #taken == 0 then
      scanning = false
      if not found then
        if #queue == 0 then
          _done(start_dir)
        else
          vim.defer_fn(step, 1)
        end
      end
      return
    end
    local pending = #taken
    local function on_one_done()
      pending = pending - 1
      if pending == 0 then
        scanning = false
        if not found then
          if #queue == 0 then
            _done(start_dir)
          else
            vim.defer_fn(step, 1)
          end
        end
      end
    end
    for _, item in ipairs(taken) do
      local dir, depth = item.dir, item.depth
      if has_makefile(dir) then
        if not found then
          found = true
          _done(dir)
        end
        pending = 0
        scanning = false
        return
      end
      if depth < down then
        scandir_async(uv, dir, function(entries)
          if found then
            on_one_done()
            return
          end
          for _, e in ipairs(entries) do
            if e.type == 'directory' then
              local subdir = U.join(dir, e.name)
              if is_ignored(e.name) then
                -- 忽略目录的一层探测：若根有 Makefile 也视为候选
                if has_makefile(subdir) then
                  if not found then
                    found = true
                    _done(subdir)
                  end
                  pending = 0
                  scanning = false
                  return
                end
              else
                table.insert(queue, { dir = subdir, depth = depth + 1 })
              end
            end
          end
          on_one_done()
        end)
      else
        on_one_done()
      end
    end
  end

  step()
end

 --- 收集多个包含 Makefile 的目录（异步，非阻塞），供 Telescope 等选择
 ---@param config table quick-c 配置（使用 make.search 与 cache.ttl）
 ---@param start_dir string 起点目录
 ---@param cb fun(list:string[]) 回调，返回去重后的目录有序列表
 function M.find_make_roots_async(config, start_dir, cb)
  local results, seen = {}, {}
  local cfg = config.make or {}
  local up = (cfg.search and cfg.search.up) or 2
  local down = (cfg.search and cfg.search.down) or 3
  local key = table.concat({ U.norm(start_dir or ''), up, down }, '|')
  do
    local ent = _cache.multi[key]
    if ent and (_now() - ent.ts) < _ttl(config) then
      vim.schedule(function()
        cb(vim.deepcopy(ent.val))
      end)
      return
    end
  end

  local function _done(list)
    _cache.multi[key] = { val = vim.deepcopy(list), ts = _now() }
    vim.schedule(function()
      cb(list)
    end)
  end

  -- 先触发一次“最近根”的扫描，利用其 warming 与边界校验，然后再进行全面收集
  M.find_make_root_async(config, start_dir, function()
    vim.schedule(function()
      local cfg = config.make or {}
      local names = { 'Makefile', 'makefile', 'GNUmakefile' }
      local uv = vim.loop
      local ignore = (cfg.search and cfg.search.ignore_dirs) or { '.git', 'node_modules', '.cache' }

      local function is_ignored(name)
        for _, n in ipairs(ignore) do
          if name == n then
            return true
          end
        end
        return false
      end

    local cwd_root = U.norm(vim.fn.getcwd()) -- 同样受 :pwd 边界限制
    local bases = {}
    do
      local cur = start_dir
      for _ = 0, up do
        local cur_norm = U.norm(cur)
        if not cur_norm:find(cwd_root, 1, true) then
          break
        end
        table.insert(bases, cur)
        local nextp = vim.fn.fnamemodify(cur, ':h')
        if nextp == cur then
          break
        end
        local next_norm = U.norm(nextp)
        if #next_norm < #cwd_root or not next_norm:find(cwd_root, 1, true) then
          break
        end
        cur = nextp
      end
    end

    local function has_makefile(dir)
      for _, n in ipairs(names) do
        local st = uv.fs_stat(U.join(dir, n))
        if st and st.type == 'file' then
          return true
        end
      end
      return false
    end

    local queue = {} -- BFS 队列
    for _, b in ipairs(bases) do
      table.insert(queue, { dir = b, depth = 0 })
    end
    local batch_size = 50 -- 更大的批量以提升收集效率
    -- 并发工作者数：优先 make.concurrency，其次 debug.concurrency，最后默认 8
    local parallel = tonumber((config.make and config.make.concurrency)
      or (config.debug and config.debug.concurrency)
      or 8) or 8
    local function step()
      local taken = {}
      local n = math.min(batch_size, #queue, parallel)
      for i = 1, n do
        taken[i] = table.remove(queue, 1)
      end

      if #taken == 0 then
        table.sort(results)
        _done(results)
        return
      end
      local pending = #taken
      local function on_one_done()
        pending = pending - 1
        if pending == 0 then
          if #queue > 0 then
            vim.defer_fn(step, 1)
          else
            table.sort(results)
            _done(results)
          end
        end
      end
      for _, item in ipairs(taken) do
        local dir, depth = item.dir, item.depth
        if has_makefile(dir) and not seen[dir] then
          seen[dir] = true
          table.insert(results, dir)
        end
        if depth < down then
          scandir_async(uv, dir, function(entries)
            for _, e in ipairs(entries) do
              if e.type == 'directory' then
                local subdir = U.join(dir, e.name)
                if is_ignored(e.name) then
                  -- 忽略目录同样进行“一层探测”
                  if has_makefile(subdir) and not seen[subdir] then
                    seen[subdir] = true
                    table.insert(results, subdir)
                  end
                else
                  table.insert(queue, { dir = subdir, depth = depth + 1 })
                end
              end
            end
            on_one_done()
          end)
        else
          on_one_done()
        end
      end
    end
    step()
    end)
  end)
end

 --- 根据配置解析最终 make 的 cwd：
 ---  - 若设置了 make.cwd：
 ---    - 绝对路径：直接使用；若无 Makefile，则限制在该目录内向下搜索可用子目录
 ---    - 相对路径：相对 start_dir 解析
 ---  - 未设置 make.cwd：收集候选后返回最近或让用户通过 Telescope 选择
 ---@param config table quick-c 配置
 ---@param start_dir string 起点目录（通常为当前文件目录）
 ---@param cb fun(dir:string) 回调返回最终 cwd
 function M.resolve_make_cwd_async(config, start_dir, cb)
  if config.make and config.make.cwd then
    local cwd = tostring(config.make.cwd)
    local is_abs
    if U.is_windows() then
      -- e.g. C:\ or \\server\share or starts with /
      is_abs = cwd:match '^%a:[\\/]' or cwd:match '^[\\/]' or cwd:match '^\\\\'
    else
      is_abs = cwd:sub(1, 1) == '/'
    end
    if not is_abs then
      -- 相对路径：以起点为基准解析绝对路径；回退为当前文件目录
      local base = start_dir and vim.fn.fnamemodify(start_dir, ':p') or vim.fn.fnamemodify(vim.fn.expand '%:p', ':h')
      cwd = vim.fn.fnamemodify(U.join(base, cwd), ':p')
    end
    if vim.fn.isdirectory(cwd) == 1 then
      -- 若 cwd 本身无 Makefile：仅在 cwd 内向下搜索，避免跨出用户指定范围
      local uv = vim.loop
      local names = { 'Makefile', 'makefile', 'GNUmakefile' }
      local function has_makefile(dir)
        for _, n in ipairs(names) do
          local st = uv.fs_stat(U.join(dir, n))
          if st and st.type == 'file' then
            return true
          end
        end
        return false
      end
      if has_makefile(cwd) then
        cb(cwd)
        return
      end
      -- 仅向下搜索（up=0），限定在 cwd 内部
      local cfg2 = vim.deepcopy(config)
      cfg2.make = cfg2.make or {}
      cfg2.make.search = cfg2.make.search or {}
      cfg2.make.search.up = 0
      local ok_t = pcall(require, 'telescope')
      M.find_make_roots_async(cfg2, cwd, function(roots)
        if #roots == 0 then
          cb(cwd)
          return
        end
        if #roots == 1 or not ok_t then
          cb(roots[1])
          return
        end
        local pickers = require 'telescope.pickers'
        local finders = require 'telescope.finders'
        local conf = require('telescope.config').values
        local pwd = vim.fn.getcwd()
        local entries = {}
        for _, d in ipairs(roots) do
          local rel = vim.fn.fnamemodify(d, ':p')
          if rel:sub(1, #pwd) == pwd then
            rel = '.' .. rel:sub(#pwd + 1)
          end
          table.insert(entries, { display = rel, path = d })
        end
        local telcfg = (cfg2.make and cfg2.make.telescope) or {}
        pickers
          .new({}, {
            prompt_title = 'Select Makefile Directory',
            finder = finders.new_table {
              results = entries,
              entry_maker = function(e)
                return { value = e.path, display = e.display, ordinal = e.display }
              end,
            },
            sorter = conf.generic_sorter {},
            previewer = (function()
              if telcfg.preview == false then
                return nil
              end
              local previewers = require 'telescope.previewers'
              local conf_t = require('telescope.config').values
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
              local max_bytes = telcfg.max_preview_bytes or (200 * 1024)
              local max_lines = telcfg.max_preview_lines or 2000
              local set_ft = (telcfg.set_filetype ~= false)
              return previewers.new_buffer_previewer {
                get_buffer_by_name = function(_, entry)
                  return find_makefile(entry.value) or ('[makefile-preview] ' .. entry.value)
                end,
                define_preview = function(self, entry)
                  local path = find_makefile(entry.value)
                  if not path then
                    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { '[No Makefile found]' })
                    return
                  end
                  local st = uv.fs_stat(path) or {}
                  if st.size and st.size > max_bytes then
                    -- 超大文件：按行读取并截断，首行提示被截断信息
                    local ok, lines = pcall(vim.fn.readfile, path, '', max_lines)
                    if not ok then
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
                  else
                    conf_t.buffer_previewer_maker(path, self.state.bufnr, { bufname = self.state.bufname })
                  end
                  if set_ft then
                    pcall(vim.api.nvim_buf_set_option, self.state.bufnr, 'filetype', 'make')
                  end
                end,
              }
            end)(),
            attach_mappings = function(_, map)
              local actions = require 'telescope.actions'
              local action_state = require 'telescope.actions.state'
              local function choose(bufnr)
                local entry = action_state.get_selected_entry()
                actions.close(bufnr)
                cb(entry.value)
              end
              map('i', '<CR>', choose)
              map('n', '<CR>', choose)
              return true
            end,
          })
          :find()
      end)
      return
    else
      U.notify_warn('make.cwd directory not found: ' .. tostring(cwd) .. '，已回退到起点目录')
      cb(start_dir)
    end
    return
  end
  local ok_t = pcall(require, 'telescope')
  M.find_make_roots_async(config, start_dir, function(roots)
    if #roots == 0 then
      cb(start_dir)
      return
    end
    if #roots == 1 or not ok_t then
      cb(roots[1])
      return
    end
    local pickers = require 'telescope.pickers'
    local finders = require 'telescope.finders'
    local conf = require('telescope.config').values
    local cwd = vim.fn.getcwd()
    local entries = {}
    for _, d in ipairs(roots) do
      local rel = vim.fn.fnamemodify(d, ':p')
      if rel:sub(1, #cwd) == cwd then
        rel = '.' .. rel:sub(#cwd + 1)
      end
      table.insert(entries, { display = rel, path = d })
    end
    local telcfg = (config.make and config.make.telescope) or {}
    pickers
      .new({}, {
        prompt_title = 'Select Makefile Directory',
        finder = finders.new_table {
          results = entries,
          entry_maker = function(e)
            return { value = e.path, display = e.display, ordinal = e.display }
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
          local max_bytes = telcfg.max_preview_bytes or (200 * 1024)
          local max_lines = telcfg.max_preview_lines or 2000
          local set_ft = (telcfg.set_filetype ~= false)
          return previewers.new_buffer_previewer {
            get_buffer_by_name = function(_, entry)
              return find_makefile(entry.value) or ('[makefile-preview] ' .. entry.value)
            end,
            define_preview = function(self, entry)
              local path = find_makefile(entry.value)
              if not path then
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { '[No Makefile found]' })
                return
              end
              local st = uv.fs_stat(path) or {}
              if st.size and st.size > max_bytes then
                -- 大文件预览截断策略，同上
                local ok, lines = pcall(vim.fn.readfile, path, '', max_lines)
                if not ok then
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
              else
                conf_t.buffer_previewer_maker(path, self.state.bufnr, { bufname = self.state.bufname })
              end
              if set_ft then
                pcall(vim.api.nvim_buf_set_option, self.state.bufnr, 'filetype', 'make')
              end
            end,
          }
        end)(),
        attach_mappings = function(_, map)
          local actions = require 'telescope.actions'
          local action_state = require 'telescope.actions.state'
          local function choose(bufnr)
            local entry = action_state.get_selected_entry()
            actions.close(bufnr)
            cb(entry.value)
          end
          map('i', '<CR>', choose)
          map('n', '<CR>', choose)
          return true
        end,
      })
      :find()
  end)
end

return M
