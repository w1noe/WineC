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
      compile = {
        prefer = { c = nil, cpp = nil },
        prefer_force = false,
        -- 用户自定义编译命令：可通过模板或预设完全覆盖内置命令
        -- 当 enabled = true 时，构建流程会优先询问/选择自定义命令；未选择时回退到内置命令
        user_cmd = {
          enabled = true,
          -- 是否使用 Telescope 弹窗选择：包含 [Use built-in]、[Custom input...] 以及 presets
          telescope = {
            popup = false, -- 参考 make 的交互，默认不弹；开启后若未安装 telescope 将自动回退到 vim.ui
            prompt_title = 'Quick-c Compile',
          },
          -- 预设命令（推荐使用列表形式以避免 shell 解析问题）：
          -- 必须使用完整的编译命令，这不是追加参数
          -- 允许占位符：{sources} {out} {cc} {ft}
          presets = {
            { name = "Debug", cmd = { "gcc", "-g", "-O0", "{sources}", "-o", "{out}" } },
            { name = "ASan",  cmd = { "gcc", "-g", "-O0", "-fsanitize=address", "{sources}", "-o", "{out}" } },
          },
          -- 自定义输入的默认模板（字符串或数组）。
          -- 这是弹窗后的追加命令
          default = nil,
          -- 记住每个项目最近一次输入（用于下次默认值）
          remember_last = true,
        },
        -- compile_commands.json 相关配置
        compile_commands = {
          -- mode:
          --   'generate' : 按当前工具链/参数为单/多文件生成最小 compile_commands（适合非 CMake 项目）
          --   'use'      : 从 use_path 指定的文件复制到 outdir
          --   'cmake'    : 使用 CMake 导出（自动追加 -DCMAKE_EXPORT_COMPILE_COMMANDS=ON），
          --                从 cmake.build_dir/compile_commands.json 复制到 outdir
          -- 说明：
          --   - 非 CMake 项目的一次性批量生成，建议使用命令：
          --       :QuickCCompileDBGenProject   （扫描 :pwd 全项目）
          --       :QuickCCompileDBGenDir [dir] （指定目录）
          --       :QuickCCompileDBGenSources   （Telescope 多选源文件）
          --   - 仅借用 CMake 导出（即使平时用 make）：
          --       :QuickCCompileDBGenCMake 或将 mode 设为 'cmake' 后 :QuickCCompileDB
          mode = 'generate',
          -- outdir：生成/复制的目标位置
          --   'source'  : 写到“当前源文件目录”。当为多文件/项目生成时，内部会优先写到项目根（便于 clangd 发现）
          --   'cwd'     : 直接写到当前工作目录（项目根）
          --   相对路径 : 相对 :pwd
          --   绝对路径 : 例如 'C:/proj/compile_commands'
          outdir = 'source',
          -- 当 mode = 'use' 时，从此路径复制 compile_commands.json
          use_path = nil,
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