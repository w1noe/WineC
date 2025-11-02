local C = {}

C.defaults = {
  -- outdir 用于决定可执行文件与临时产物的输出位置：
  -- - "source": 写入到“当前源文件所在目录”（默认）
  -- - 其他字符串：自定义目录
  --    · 相对路径：相对于当前工作目录(:pwd)；例如 "build"、"build/bin"
  --    · 绝对路径：如 "C:/proj/bin" 或 "/home/me/bin"
  --    · 目录不存在会自动创建（mkdir -p）
  -- 示例：
  --   outdir = "source"         -- a.c => ./a.exe 或 ./a.out
  --   outdir = "build"          -- a.c => ./build/a.exe
  --   outdir = "build/bin"      -- a.c => ./build/bin/a.exe
  --   outdir = "C:/tmp/bin"     -- Windows 绝对路径
  outdir = 'source',
  -- 用户可覆盖：为不同系统/工具链提供命令模板
  toolchain = {
    windows = { c = { 'gcc', 'cl' }, cpp = { 'g++', 'cl' } },
    unix = { c = { 'gcc', 'clang' }, cpp = { 'g++', 'clang++' } },
  },
  compile = { -- 自定义编译器
    prefer = { c = nil, cpp = nil }, -- 例如：i386-elf-gcc
    prefer_force = false, -- 是否强制使用优先级
  },
  -- compile_commands.json 相关配置
  compile_commands = {
    -- mode = 'generate' | 'use'
    mode = 'generate',
    -- 生成或复制的目标输出目录：'source' 表示放在当前源文件目录
    outdir = 'source',
    -- 当 mode = 'use' 时，从此路径复制 compile_commands.json
    use_path = nil,
  },
  -- Build behavior
  build = {
    -- Timeout for single-file builds started via jobstart (ms). 0 = no timeout
    timeout_ms = 0,
    summary = {
      -- Show floating summary after build finishes. Default off to avoid covering terminal.
      enabled = false,
    },
  },
  diagnostics = {
    quickfix = {
      enabled = true, -- 是否收集编译输出到 quickfix
      open = 'warning', -- 'always' | 'error' | 'warning' | 'never'
      jump = 'warning', -- 'always' | 'error' | 'warning' | 'never'
      use_telescope = true, -- 打开列表时优先使用 Telescope quickfix（如已安装）
    },
  },
  autosave = {
    enabled = true, -- 自动保存
    debounce_ms = 1000, -- 节流时间（ms）
    events = { 'TextChanged', 'TextChangedI', 'InsertLeave' }, -- 事件
    filetypes = { 'c', 'cpp' }, -- 文件类型
    ignore_filetypes = { 'gitcommit', 'gitrebase' }, -- 忽略的文件类型
  },
  terminal = {
    open = true,
    height = 12,
  },
  betterterm = {
    enabled = true,
    index = 0, -- 默认打开的终端索引
    send_delay = 200, -- 发送命令的延迟（ms）
    focus_on_run = true, -- 运行时自动聚焦
    open_if_closed = true, -- 如果终端关闭则自动打开
  },
  debug = { -- 搜索可执行文件
    search = {
      up = 2,
      down = 2,
      ignore_dirs = { '.git', 'node_modules', '.cache' },
      dirs = nil, -- 指定搜索目录，为空时使用当前文件所在目录
    },
    concurrency = 8, -- 并发工作者数
  },
  make = {
    enabled = true,
    prefer = nil, -- 可为字符串或列表，例如 "make" | "mingw32-make" | { "make", "mingw32-make" }
    cwd = nil, -- 默认使用当前文件所在目录
    search = { up = 2, down = 3, ignore_dirs = { '.git', 'node_modules', '.cache' } },
    -- 并发工作者数：用于 Makefile 搜索等异步操作；可根据系统性能微调
    concurrency = 8,
    streaming = {
      enabled = true, -- 是否启用流式解析
      batch_size = 100, -- 每批解析的行数
      throttle_ms = 60, -- 批次节流时间（ms）
    },
    parse_timeout_ms = 0, -- make 解析超时时间
    telescope = {
      prompt_title = 'Quick-c Make Targets',
      preview = true, -- 是否启用预览
      max_preview_bytes = 200 * 1024, -- 预览最多读取的字节数
      max_preview_lines = 2000, -- 预览最多显示的行数
      set_filetype = true, -- 预览 buffer 是否设置 filetype = 'make'
      choose_terminal = 'auto', -- 发送命令到终端时的选择行为: 'auto' | 'always' | 'never'
    },
    cache = {
      ttl = 10, -- 目标解析缓存（秒）。同一 cwd 且 Makefile 未变化时，在 TTL 内复用上次解析结果
    },
    targets = {
      prioritize_phony = true, -- 将 .PHONY 目标在列表中优先显示
    },
    args = {
      prompt = true, -- 选择目标后是否弹出输入框追加参数（例如 -j4 VAR=1）
      default = '', -- 默认参数
      remember = true, -- 记住每个 cwd 最近一次输入，作为下次默认值
    },
  },
  cmake = {
    enabled = true,
    prefer = nil, -- 指定 cmake 可执行程序路径或名称
    generator = nil, -- 例如 "Ninja" | "Unix Makefiles" | "MinGW Makefiles" | "NMake Makefiles"
    build_dir = 'build', -- 构建目录，默认在项目根目录下
    view = 'both', -- 构建输出视图：'quickfix' | 'terminal' | 'both'
    -- 并发工作者数：用于 CMake 根目录搜索等异步操作；可根据系统性能微调
    concurrency = 8,
    output = {
      open = true, -- both 模式下是否自动打开输出面板
      height = 12, -- 输出面板高度
    },
    search = { up = 2, down = 3, ignore_dirs = { '.git', 'node_modules', '.cache' } },
    telescope = {
      prompt_title = 'Quick-c CMake Targets',
      preview = true, -- 是否显示预览
      max_preview_bytes = 200 * 1024, -- 预览最多读取的字节数
      max_preview_lines = 2000, -- 预览最多显示的行数
      set_filetype = false, -- 预览 buffer 是否设置 filetype = 'cmake'
      choose_terminal = 'auto', -- 发送命令到终端时的选择行为: 'auto' | 'always' | 'never'
    },
    args = {
      prompt = true, -- 选择目标后是否弹出输入框追加构建参数（传递给构建工具，如 -j4）
      default = '', -- 默认追加参数
      remember = true, -- 记住每个 cwd 最近一次输入，作为下次默认值
    },
    configure = {
      extra = {}, -- 额外传递给 cmake -S/-B 的参数，如 { "-DCMAKE_BUILD_TYPE=Debug" }
      toolchain = nil, -- 指定工具链文件路径
    },
  },
  keymaps = {
    enabled = true,
    unmap_defaults = true,
    build = '<leader>cqb',
    run = '<leader>cqr',
    build_and_run = '<leader>cqR',
    debug = '<leader>cqD',
    make = '<leader>cqM',
    cmake = '<leader>cqC',
    cmake_run = '<leader>cqB',
    cmake_configure = '<leader>cqc',
    sources = '<leader>cqS',
    quickfix = '<leader>cqf',
    logs = '<leader>cqL',
    stop = '<leader>cqx',
    retry = '<leader>cqt',
  },
}

return C
