# 默认配置：

```lua
{
  "AuroBreeze/quick-c",
  -- 三重懒加载：任一触发即可加载
  ft = { "c", "cpp" },
  keys = {
    { "<leader>cqb", desc = "Quick-c: Build" },
    { "<leader>cqr", desc = "Quick-c: Run" },
    { "<leader>cqR", desc = "Quick-c: Build & Run" },
    { "<leader>cqD", desc = "Quick-c: Debug" },
    { "<leader>cqM", desc = "Quick-c: Make targets (Telescope)" },
    { "<leader>cqS", desc = "Quick-c: Select sources (Telescope)" },
    { "<leader>cqf", desc = "Quick-c: Open quickfix (Telescope)" },
  },
  cmd = {
    "QuickCBuild", "QuickCRun", "QuickCBR", "QuickCDebug",
    "QuickCMake", "QuickCMakeRun", "QuickCQuickfix",
  },
  config = function()
    require("quick-c").setup({
      -- 可执行文件输出目录：
      --  - "source": 输出在源码同目录
      --  - 自定义路径：如 vim.fn.stdpath("data") .. "/quick-c-bin"
      outdir = "source",
      toolchain = {
        -- 编译器探测优先级（按平台与语言）
        windows = { c = { "gcc", "cl" }, cpp = { "g++", "cl" } },
        unix    = { c = { "gcc", "clang" }, cpp = { "g++", "clang++" } },
      },
      -- CMake 配置（默认启用）
      cmake = {
        enabled = true,
        prefer = nil,
        generator = nil,       -- 例如 "Ninja" | "Unix Makefiles" | ...
        build_dir = "build",   -- 构建目录（相对项目根）
        view = 'both',          -- 'both' | 'quickfix' | 'terminal'
        output = { open = true, height = 12 },
        search = { up = 2, down = 3, ignore_dirs = { '.git', 'node_modules', '.cache' } },
        telescope = {
          prompt_title = "Quick-c CMake Targets",
          preview = true,
          max_preview_bytes = 200 * 1024,
          max_preview_lines = 2000,
          set_filetype = false,
          -- 发送命令到终端时的选择行为
        -- 'generate' 生成基于当前文件的简单编译数据库；'use' 从指定路径复制
        mode = 'generate',
        -- 输出位置：'source' 表示写入到当前源文件所在目录
        outdir = 'source',
        -- 当 mode = 'use' 时，从该路径复制 compile_commands.json 到 outdir
        -- 例如：vim.fn.getcwd().."/compile_commands.json"
        use_path = nil,
      }},
      
      terminal = {
        -- 运行时是否自动打开内置终端窗口
        open = true,
        -- 终端窗口高度
        height = 12,
      },
      betterterm = {
        -- 安装了 betterTerm 时优先使用
        enabled = true,
        -- 发送到的终端索引（0 为第一个）
        index = 0,
        -- 发送命令的延时（毫秒）
        send_delay = 200,
        -- 发送命令后是否聚焦终端
        focus_on_run = true,
        -- 终端未打开时是否先打开
        open_if_closed = true,
      },
      make = {
        -- 启用/禁用 make 集成
        enabled = true,
        -- 指定优先使用的 make 程序：
        --   - 可为字符串或列表；按顺序探测可执行：
        --     prefer = 'make' 或 prefer = { 'make', 'mingw32-make' }
        --   - Windows 常见：{ 'make', 'mingw32-make' }

        -- 强制使用不存在的 make 命令
        prefer_force = false, -- 强制使用不可执行的 prefer（解析阶段仅告警，运行阶段仍使用 prefer）

        prefer = nil,
        -- 发送 make 命令时是否省略 `-C <cwd>`（为 true 时在当前终端目录执行）
        no_dash_C = false,
        -- 固定工作目录（不设置则由插件根据当前文件自动搜索）
        cwd = nil,
        -- Makefile 搜索策略（未显式设置 cwd 时生效）：
        --   以当前文件所在目录为起点，向上 up 层、向下每层 down 层，跳过 ignore_dirs
        search = { up = 2, down = 3, ignore_dirs = { '.git', 'node_modules', '.cache' } },
        telescope = {
          -- Telescope 选择器标题
          prompt_title = "Quick-c Make Targets",
          -- 是否启用预览（目录选择与目标选择均支持）
          preview = true,
          -- 大文件截断策略（按字节与行数）
          max_preview_bytes = 200 * 1024,
          max_preview_lines = 2000,
          -- 是否为预览 buffer 设置 filetype=make（语法高亮）
          set_filetype = true,
          -- 发送命令到终端时的选择行为：
          --   'auto'  有已打开终端则弹选择器，否则走默认策略
          --   'always'总是弹选择器
          --   'never' 始终走默认策略（betterTerm 优先，失败回退内置）
          choose_terminal = 'auto',
        },
        -- 目标解析缓存：同一 cwd 且 Makefile 未变化时，TTL 内复用结果
        cache = {
          ttl = 10,
        },
        -- 目标列表行为
        targets = {
          -- 将 .PHONY 目标在列表中优先显示（Telescope 内可用 <C-p> 切换“仅显示 .PHONY”）
          prioritize_phony = true,
        },
        -- 追加 make 参数（如 -j4、VAR=1），并记住每个 cwd 最近一次输入
        args = {
          prompt = true,   -- 选择目标后是否弹出输入框
          default = "",    -- 默认参数
          remember = true, -- 记忆最近一次输入，作为默认值
        },
      },
      diagnostics = {
        quickfix = {
          enabled = true,
          open = 'warning',   -- always | error | warning | never
          jump = 'warning',   -- always | error | warning | never
          use_telescope = true,
        },
      },
      keymaps = {
        -- 设为 false 可不注入任何默认键位（你可自行映射命令）
        enabled = true,
        unmap_defaults = true,
        -- 置为 nil 或 '' 可单独禁用某个映射
        build = '<leader>cqb',
        run = '<leader>cqr',
        build_and_run = '<leader>cqR',
        debug = '<leader>cqD',
        -- 注意：键位注入使用 unique=true，不会覆盖你已有的映射；冲突时跳过
        make = '<leader>cqM',
        cmake = '<leader>cqC',
        cmake_run = '<leader>cqB',
        cmake_configure = '<leader>cqc',
        sources = '<leader>cqS',
        quickfix = '<leader>cqf',
        logs = '<leader>cqL',
      },
    })
  end,
}
```