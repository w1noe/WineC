# Quick-c 配置指南（中文）

本指南概述 quick-c 的主要配置项、默认值与示例，帮助你按项目或个人偏好进行定制。

- 适用范围
  - 用户级：`require('quick-c').setup({ ... })`
  - 项目级：在项目根创建 `.quick-c.json`

## 全局结构概览

- `outdir` 可执行输出位置
- `toolchain`/`compile` 编译器优先级与强制
- `runtime` 运行器与参数
- `diagnostics.quickfix` 构建诊断列表策略
- `terminal`/`betterterm` 运行窗口行为
- `make` Make 集成（目录搜索、目标解析、Telescope）
- `cmake` CMake 集成（根搜索、配置、构建、Telescope）
- `debug` 调试可执行文件搜索与并发
- `keymaps` 默认按键

## 核心配置项

### 输出目录 outdir
- `"source"`（默认）：输出到源文件所在目录
- 自定义目录：相对于 `:pwd`，或绝对路径

```lua
outdir = 'source' -- 或 'build/bin', 'C:/tmp/bin'
```

### 工具链与编译
- `toolchain`: 各平台/语言的编译器优先列表
- `compile.prefer`: 指定固定编译器名
- `compile.prefer_force`: 为 true 时即使不可执行也尝试调用

```lua
toolchain = {
  windows = { c = { 'gcc', 'cl' }, cpp = { 'g++', 'cl' } },
  unix    = { c = { 'gcc', 'clang' }, cpp = { 'g++', 'clang++' } },
}
compile = {
  prefer = { c = nil, cpp = nil },
  prefer_force = false,
}
```

### 诊断列表 diagnostics.quickfix
```lua
diagnostics = {
  quickfix = {
    enabled = true,
    open = 'warning',  -- always | error | warning | never
    jump = 'warning',  -- always | error | warning | never
    use_telescope = true,
  },
}
```

### 终端与 BetterTerm
```lua
terminal = { open = true, height = 12 }
betterterm = {
  enabled = true, index = 0, send_delay = 200,
  focus_on_run = true, open_if_closed = true,
}
```

### Make 集成 make
```lua
make = {
  enabled = true,
  prefer = nil,          -- 'make' | 'mingw32-make' | { 'make','mingw32-make' }
  cwd = nil,             -- 固定工作目录；未设置时按当前文件邻域搜索
  search = { up = 2, down = 3, ignore_dirs = { '.git','node_modules','.cache' } },
  concurrency = 8,       -- Makefile 目录发现等异步并发
  telescope = {
    prompt_title = 'Quick-c Make Targets',
    preview = true,
    max_preview_bytes = 200*1024,
    max_preview_lines = 2000,
    set_filetype = true,
    choose_terminal = 'auto', -- auto | always | never
  },
  cache = { ttl = 10 },  -- 目标解析缓存（秒）
  targets = { prioritize_phony = true },
  args = { prompt = true, default = '', remember = true },
}
```

### CMake 集成 cmake
```lua
cmake = {
  enabled = true,
  prefer = nil,
  generator = nil,
  build_dir = 'build',
  view = 'both',                 -- 'quickfix' | 'terminal' | 'both'
  concurrency = 8,               -- CMake 根搜索等异步并发
  output = { open = true, height = 12 },
  search = { up = 2, down = 3, ignore_dirs = { '.git','node_modules','.cache' } },
  telescope = {
    prompt_title = 'Quick-c CMake Targets',
    preview = true,
    max_preview_bytes = 200*1024,
    max_preview_lines = 2000,
    set_filetype = false,
    choose_terminal = 'auto',
  },
  args = { prompt = true, default = '', remember = true },
  configure = { extra = {}, toolchain = nil },
}
```

### 调试 debug
```lua
debug = {
  search = {
    up = 2, down = 2,
    ignore_dirs = { '.git','node_modules','.cache' },
    dirs = nil, -- 优先目录，如 { './build/bin','./out' }
  },
  concurrency = 8,
}
```

### 按键 keymaps
- 支持禁用、改键；不会覆盖你已有映射（unique=true）

## 项目级配置 `.quick-c.json` 示例
```jsonc
{
  "outdir": "build/bin",
  "make": { "prefer": ["make","mingw32-make"], "concurrency": 8 },
  "cmake": { "generator": "Ninja", "concurrency": 8 },
  "diagnostics": { "quickfix": { "open": "warning", "jump": "warning" } }
}
```

## 参考
- 中文 README 与命令速查
- 进阶：见《性能调优指南》
