# Quick-c

<div align="center"><p>
    <a href="https://github.com/AuroBreeze/quick-c/releases/latest">
      <img alt="Latest release" src="https://img.shields.io/github/v/release/AuroBreeze/quick-c?style=for-the-badge&logo=starship&color=C9CBFF&logoColor=D9E0EE&labelColor=302D41&include_prerelease&sort=semver" />
    </a>
    <a href="https://github.com/AuroBreeze/quick-c/pulse">
      <img alt="Last commit" src="https://img.shields.io/github/last-commit/AuroBreeze/quick-c?style=for-the-badge&logo=starship&color=8bd5ca&logoColor=D9E0EE&labelColor=302D41"/>
    </a>
    <a href="https://github.com/AuroBreeze/quick-c/blob/main/LICENSE">
      <img alt="License" src="https://img.shields.io/github/license/AuroBreeze/quick-c?style=for-the-badge&logo=starship&color=ee999f&logoColor=D9E0EE&labelColor=302D41" />
    </a>
    <a href="https://github.com/AuroBreeze/quick-c/stargazers">
      <img alt="Stars" src="https://img.shields.io/github/stars/AuroBreeze/quick-c?style=for-the-badge&logo=starship&color=c69ff5&logoColor=D9E0EE&labelColor=302D41" />
    </a>
    <a href="https://github.com/AuroBreeze/quick-c/issues">
      <img alt="Issues" src="https://img.shields.io/github/issues/AuroBreeze/quick-c?style=for-the-badge&logo=bilibili&color=F5E0DC&logoColor=D9E0EE&labelColor=302D41" />
    </a>
    <a href="https://github.com/AuroBreeze/quick-c">
      <img alt="Repo Size" src="https://img.shields.io/github/repo-size/AuroBreeze/quick-c?color=%23DDB6F2&label=SIZE&logo=codesandbox&style=for-the-badge&logoColor=D9E0EE&labelColor=302D41" />
    </a>
</p></div>

<p align="center">
  <b>中文</b> | <a href="README.en.md">English</a>
</p>

一个面向 C/C++ 的功能齐全且轻量的 Neovim 插件：支持一键编译、运行与调试当前文件，兼容 Windows、Linux、macOS，适配 betterTerm 与内置终端；构建与运行全程异步，不阻塞 Neovim 主线程。

<a href="https://dotfyle.com/plugins/AuroBreeze/quick-c">
  <img src="https://dotfyle.com/plugins/AuroBreeze/quick-c/shield" />
</a>

<a href="https://deepwiki.com/AuroBreeze/quick-c"><img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki"></a>

## ✨ 特性

 - 🚀 **一键构建/运行（异步）**：`QuickCBuild`、`QuickCRun`、`QuickCBR`（构建并运行）
 - 🐞 **调试集成**：`QuickCDebug` 使用 `nvim-dap` 与 `codelldb`
 - 🌐 **跨平台**：自动选择可用编译器（gcc/clang/cl）与合适运行方式（PowerShell/终端）
 - 📁 **灵活输出位置**：默认将可执行文件输出到源码所在目录；可通过配置修改
 - 🔌 **终端兼容**：优先将命令发送到 `betterTerm`（如已安装），否则使用 Neovim 内置终端
 - 🔧 **Make 集成**：自动发现 Makefile、列出目标、`.PHONY` 优先、参数输入与记忆
- 🏗️ **CMake 集成**：自动搜索 CMakeLists、`cmake -S/-B` 配置、`cmake --build` 构建、目标列表（基于 `--target help`）
  - 视图模式：`both`（默认，流式输出+quickfix）/`quickfix`/`terminal`
  - 输出面板：`cmake.output.{open,height}` 控制
- 🔭 **Telescope 增强**：内置 Makefile 预览、源文件多选、快捷切换 .PHONY
- 🧪 **Quickfix 增强预览**：`cqf` 打开时右侧显示错误详情与源码上下文
- 📦 **多文件构建**：支持一次构建/运行多个源文件
- 🧠 **LSP 集成**：一键为当前文件目录生成或使用指定 `compile_commands.json` 供 clangd 等 LSP 使用


## 📦 依赖

- Neovim 0.8+
- 至少一种 C/C++ 编译器（按平台自动探测）：
  - Windows: `gcc/g++`（MinGW）或 `cl`（MSVC）或 `clang/clang++`
  - Unix: `gcc/g++` 或 `clang/clang++`
- 可选：
  - [`betterTerm`](https://github.com/CRAG666/betterTerm.nvim)（若安装则优先使用）
  - 调试：[`nvim-dap`](https://github.com/mfussenegger/nvim-dap) 与 `codelldb`
  - Make 选择器：[`nvim-telescope/telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) 与 [`nvim-lua/plenary.nvim`](https://github.com/nvim-lua/plenary.nvim)

## 🧩 安装

使用 lazy.nvim（三重懒加载：按文件类型/按快捷键/按命令 任一触发即加载）：

```lua
{
  "AuroBreeze/quick-c",

  lazy = true,
  event = "VeryLazy",

  -- 1) 文件类型触发（打开 C/C++ 文件时加载）
  ft = { "c", "cpp" },
  -- 2) 快捷键触发（首次按键时加载，映射由插件在 setup 时注入）
  keys = {
    { "<leader>cqb", desc = "Quick-c: Build" },
    { "<leader>cqr", desc = "Quick-c: Run" },
    { "<leader>cqR", desc = "Quick-c: Build & Run" },
    { "<leader>cqD", desc = "Quick-c: Debug" },
    { "<leader>cqM", desc = "Quick-c: Make targets (Telescope)" },
    { "<leader>cqS", desc = "Quick-c: Select sources (Telescope)" }, -- 使用tab进行多选
    { "<leader>cqf", desc = "Quick-c: Open quickfix (Telescope)" },
    { "<leader>cqL", desc = "Quick-c: Build logs (Telescope)" },
    { "<leader>cqC", desc = "Quick-c: CMake targets (Telescope)" },
    { "<leader>cqB", desc = "Quick-c: CMake build" },
    { "<leader>cqc", desc = "Quick-c: CMake configure" },
    { "<leader>cqx", desc = "Quick-c: Stop current task" },
    { "<leader>cqt", desc = "Quick-c: Retry last task" },
  },
  -- 3) 命令触发（调用命令时加载，等同“命令提前加载”）
  cmd = {
    "QuickCBuild", "QuickCRun", "QuickCBR", "QuickCDebug",
    "QuickCMake", "QuickCMakeRun", "QuickCMakeCmd",
    "QuickCCMake", "QuickCCMakeRun", "QuickCCMakeConfigure",
    "QuickCCompileDB", "QuickCCompileDBGen", "QuickCCompileDBUse",
    "QuickCQuickfix", "QuickCCheck",
  },
  config = function()
    require("quick-c").setup()
  end,
}
```


使用 packer.nvim：

```lua
use({
  "AuroBreeze/quick-c",
  config = function()
    require("quick-c").setup()
  end,
})
```

插件会通过 `plugin/quick-c.lua` 在加载时自动调用 `require('quick-c').setup()`，你也可以在自己的配置中传入自定义项覆盖默认行为。

## 🚀 快速开始

打开任意 `*.c` 或 `*.cpp` 文件：

- 构建当前文件：`:QuickCBuild` 或 `<leader>cqb`
- 运行可执行文件：`:QuickCRun` 或 `<leader>cqr`
- 构建并运行：`:QuickCBR` 或 `<leader>cqR`
- 调试运行：`:QuickCDebug` 或 `<leader>cqD`

多文件项目（传入多个源文件路径）：

- C: `:QuickCBuild main.c util.c`
- C++: `:QuickCBR src/main.cpp src/foo.cpp`
- 运行基于多文件编译生成的可执行文件：`:QuickCRun src/main.cpp src/foo.cpp`

使用 Telescope 选择多文件（推荐）：

- 按 `<leader>cqS` 打开源文件选择器。
- 在列表中按 `Tab` 多选（Shift+Tab 往回，多选不移动可用 Ctrl+Space）。
- 回车后选择操作：Build / Run / Build & Run。

说明：源文件列表显示为相对当前工作目录的路径，内部会使用绝对路径进行构建与运行。
 

默认输出名为当前文件名（Windows 会追加 `.exe`）；如需自定义输出名，构建时可在提示中输入。

输出名与缓存：

- 多文件构建：总是弹出“Output name”输入框；若你对“同一源集合”输入过名称，将自动带出为默认值。
- 单文件构建：直接使用默认名（同文件名）。

## ⌨️ 命令与快捷键

### 命令与键位矩阵（速查）

| 分类 | 命令 | 说明 | 默认键位 |
| --- | --- | --- | --- |
| Build/Run/Debug | `QuickCBuild` | 构建当前/所选源文件 | `<leader>cqb` |
|  | `QuickCRun` | 运行最近构建的可执行文件 | `<leader>cqr` |
|  | `QuickCBR` | 构建并运行 | `<leader>cqR` |
|  | `QuickCDebug` | 使用 codelldb 调试最近构建的程序 | `<leader>cqD` |
| Make | `QuickCMake` | 选择目录与目标并执行 | `<leader>cqM` |
|  | `QuickCMakeRun [target]` | 直接执行指定目标 | — |
|  | `QuickCMakeCmd` | 自定义完整 make 命令并发送到终端 | — |
| CMake | `QuickCCMake` | 打开 CMake 目标选择器 | `<leader>cqC` |
|  | `QuickCCMakeRun [target]` | 构建默认或指定目标 | `<leader>cqB` |
|  | `QuickCCMakeConfigure` | 执行 cmake 配置（-S/-B） | `<leader>cqc` |
| Sources | — | Telescope 源文件选择器 | `<leader>cqS` |
| Diagnostics | `QuickCQuickfix` | 打开 quickfix（优先 Telescope） | `<leader>cqf` |
| Tasks | `QuickCStop` | 取消当前内部构建任务 | `<leader>cqx` |
|  | `QuickCRetry` | 重试最近一个内部构建任务 | `<leader>cqt` |
| Config | `QuickCCompileDB` | 应用编译数据库（生成到当前文件目录） | — |
|  | `QuickCCompileDBGen` | 生成 compile_commands.json | — |
|  | `QuickCCompileDBUse` | 使用外部 compile_commands.json | — |
|  | `QuickCCheck` | 检查配置并输出报告 | — |
|  | `QuickCHealth` | 环境健康检查 | — |
|  | `QuickCReload` | 重新加载配置 | — |
|  | `QuickCConfig` | 打印生效配置与项目路径 | — |

## ⚙️ 配置

Quick-c 支持多级配置，优先级从高到低为：
1. 项目级配置（`.quick-c.json`） - 覆盖全局配置
2. 用户配置（`setup()` 参数） - 用户自定义配置
3. 默认配置 - 插件内置默认值

### 项目级配置文件

在项目根目录创建 `.quick-c.json` 文件，可以为特定项目定制配置，覆盖全局配置。当插件检测到项目配置文件时，会自动加载并应用配置。

**配置文件查找规则：**
- 仅在当前工作目录（`:pwd`，项目根）查找
- 文件名固定为 `.quick-c.json`
- 如切换目录（`DirChanged`），会自动重新载入（含 400ms 防抖）

**配置格式：**
- 使用 JSON 格式
- 配置结构与 Lua 配置相同
- 支持所有配置选项

**配置生效时机：**
- 插件初始化时自动检测并加载
- 切换不同项目（`:cd` 改变 `:pwd`）时自动应用（400ms 防抖）
- 使用命令 `:QuickCReload` 手动重载
- 使用命令 `:QuickCConfig` 查看“生效配置”和检测到的项目配置路径


具体指导：[GUIDE](markdown/cn/PROJECT_CONFIG_GUIDE.md)

补充说明：
- `make.prefer_force = true` 时：
  - 解析阶段若 `prefer` 不可执行，仅提示 Warning，并尝试用可用的 make 探测目标；
  - 运行阶段仍按你的 `prefer` 构造命令并发送到终端（可配合 `QuickCMakeCmd` 全自定义）。
- 解析阶段回退策略：`-qp` 无结果时使用 `-pn` 再试。
### 用户配置

最小示例（仅常用项）：

```lua
require("quick-c").setup({
  outdir = "source", -- 或自定义路径，如 vim.fn.stdpath("data") .. "/quick-c-bin"
  toolchain = {
    windows = { c = { "gcc", "cl" }, cpp = { "g++", "cl" } },
    unix    = { c = { "gcc", "clang" }, cpp = { "g++", "clang++" } },
  },
  -- 构建超时（毫秒）：例如 2 分钟
  build = { timeout_ms = 120000 },
  compile = { -- 只有当你想使用自定义的工具时才会有效，且仅当 prefer_force = true 时有效
    prefer = { c = nil, cpp = nil }, -- 就像 c = i686-gcc-elf
    prefer_force = false,
  },
  make = {
    prefer = { "make", "mingw32-make" },
    cache = { ttl = 10 },
    -- 当为 true 时，发送 make 命令时不附带 `-C <cwd>`，在当前终端目录执行
    no_dash_C = false,
    telescope = { choose_terminal = "auto" },
  },
  diagnostics = {
    quickfix = { open = "warning", jump = "warning", use_telescope = true },
  },
  -- 输出目录 outdir："source" 表示写到源文件目录；否则为自定义目录（相对 :pwd 或绝对路径）
  -- 例：outdir = "source" | "build" | "build/bin" | "C:/tmp/bin"
  -- 强制选择编译器：可用于交叉编译器或固定工具链名
  compile = {
    prefer = { c = "arm-none-eabi-gcc", cpp = "arm-none-eabi-g++" },
    prefer_force = false,  -- 设为 true 将不检查可执行性，直接调用
  },
  -- 调试可执行文件搜索（当默认路径不存在时）
  debug = {
    search = {
      dirs = { "./build/bin", "./out" }, -- 优先搜索目录，不存在则回退到 up/down 策略
      up = 2,                               -- 限制在 :pwd 内向上搜索层数
      down = 2,                             -- 向下搜索层数
      ignore_dirs = { ".git", "node_modules", ".cache" },
    },
    concurrency = 8,                        -- 并行扫描并发数
  },
  keymaps = {
    enabled = true,
    build = "<leader>cqb",
    run = "<leader>cqr",
    build_and_run = "<leader>cqR",
    debug = "<leader>cqD",
  },
})
```

> 更多配置请参考 [Default_configuration](markdown/cn/Default_configuration.md)。

### CMake 终端选择说明

- CMake 目标/构建发送到终端的行为由 `cmake.telescope.choose_terminal` 控制，语义与 `make.telescope.choose_terminal` 一致：
  - `auto`：已打开终端时弹选择器，否则使用默认策略（betterTerm 优先，失败回退内置）
  - `always`：总是弹出选择器
  - `never`：总是使用默认策略

自定义示例：指定固定输出目录，并优先使用 `clang/clang++`：

```lua
require("quick-c").setup({
  outdir = vim.fn.stdpath("data") .. "/quick-c-bin",
  toolchain = {
    windows = { c = { "clang", "gcc", "cl" }, cpp = { "clang++", "g++", "cl" } },
    unix = { c = { "clang", "gcc" }, cpp = { "clang++", "g++" } },
  },
  make = {
    -- 在 Windows 优先尝试 make，不存在时退回到 mingw32-make
    prefer = { 'make', 'mingw32-make' },
    cache = { ttl = 15 },
  },
})
```

### 🧪 诊断与快速跳转（quickfix / Telescope）

- 构建时会解析 gcc/clang/MSVC 输出为 quickfix 项，支持错误与警告。
- 满足触发条件时自动打开列表并跳转到第一条；默认仅有错误时打开/跳转。
- 如已安装 Telescope，默认使用“增强版 Quickfix 选择器”，右侧显示该条目的错误详情与源码上下文；不可用时回退 `:Telescope quickfix`，再回退 `:copen`。

提示：若当前缓冲是“未命名且已修改”，为避免保存提示，自动跳转（`cc`）将被跳过，此时请在 quickfix 中手动选择条目即可。

配置示例：

```lua
require('quick-c').setup({
  diagnostics = {
    quickfix = {
      enabled = true,
      open = 'warning',   -- always | error | warning | never
      jump = 'warning',   -- always | error | warning | never
      use_telescope = true,
    },
  },
})
```

#### 支持的编译器输出

- gcc/g++
- clang/clang++
- MSVC cl

默认快捷键（普通模式）：

- `<leader>cqb` → 构建
- `<leader>cqr` → 运行
- `<leader>cqR` → 构建并运行
- `<leader>cqD` → 调试
- `<leader>cqM` → 打开 Make 目标选择器（Telescope）
- `<leader>cqS` → 打开源文件选择器（Telescope）
- `<leader>cqf` → 打开 quickfix 列表（Telescope）
 - `<leader>cqx` → 取消当前内部任务（仅单/多文件构建）
 - `<leader>cqt` → 重试最近内部任务（仅单/多文件构建）

提示：
- 以上键位均可通过 `setup({ keymaps = { ... } })` 自定义或禁用。
- 插件设置键位时使用 `unique=true`，不会覆盖你已有的映射；如键位已被占用会跳过注入。
 - QuickCStop/QuickCRetry 仅作用于插件内部“单/多文件构建”任务队列；对 Make/CMake 流程不生效。

### 📚 Telescope 预览说明

- 目录选择器与目标选择器均内置 Make/CMake 预览，Windows 路径兼容更好。
- 目标选择器阶段，预览固定显示当前目录的 `Makefile` 或项目根的 `CMakeLists.txt`，不随光标移动刷新（避免卡顿）。
- 预览增强：
  - **跳转到定义**：选中目标后，预览自动跳转至该目标在 `Makefile`/`CMakeLists.txt` 中的定义附近。
  - **软换行**：预览窗口启用 wrap/linebreak/breakindent，长行可读性更好。
- 对大文件自动截断，受以下配置项控制：
  - `make.telescope.preview`：是否启用预览。
  - `make.telescope.max_preview_bytes`：超过该字节数则改为按行读取并截断。
  - `make.telescope.max_preview_lines`：截断时最多显示的行数。
  - `make.telescope.set_filetype`：是否设置预览 buffer 的 `filetype=make`。
  - CMake 预览默认也开启跳转与换行；如需更细配置，可按同样思路扩展 `cmake.telescope`。

### 🔌 终端选择行为

- 选择 make 目标后，可将命令发送到已打开的内置终端，或使用默认策略（betterTerm 优先，失败回退内置）。
- 通过 `make.telescope.choose_terminal` 控制行为：
  - `'auto'`：存在已打开终端时弹选择器，否则直接默认策略。
  - `'always'`：总是弹出选择器。
  - `'never'`：总是使用默认策略。

### 🔎 Makefile 搜索说明

- 若未设置 `make.cwd`，插件会在“当前文件所在目录”为起点：
  - 向上查找至多 `search.up` 层（默认 2 层）
  - 在每一层向下递归至多 `search.down` 层（默认 3 层）
  - 找到包含 `Makefile`/`makefile`/`GNUmakefile` 的首个目录作为工作目录
  - 会跳过 `ignore_dirs` 名单中的目录（默认：`.git`、`node_modules`、`.cache`）
  - 增强：对被忽略目录进行“第一层探测”（不递归），若该目录根下存在 Makefile，则也纳入候选

多结果时，Telescope 列表显示相对于 `:pwd` 的相对路径，便于识别（如 `./build`、`./sub/dir`）。

## 🛠️ 架构说明

内部已模块化重构，但对外 API 不变：

- 模块划分
  - `lua/quick-c/init.lua` 装配、命令与键位注入
  - `lua/quick-c/config.lua` 默认配置
  - `lua/quick-c/util.lua` 工具函数（平台/路径/消息）
  - `lua/quick-c/terminal.lua` 终端封装（betterTerm/内置）
  - `lua/quick-c/make_search.lua` 异步 Makefile 搜索与目录选择
  - `lua/quick-c/make.lua` 选择 make/解析目标/在 cwd 执行
  - `lua/quick-c/telescope.lua` Telescope 交互（目录与目标、自定义参数）
  - `lua/quick-c/build.lua` 构建/运行/调试
  - `lua/quick-c/cc.lua` 生成或使用指定的 `compile_commands.json`
  
  - `lua/quick-c/keys.lua` 键位注入

- 行为保持不变：
  - 键位可配置/禁用；多 Makefile 时目录先选后执行；选择后自动关闭选择器并在终端执行；全程异步不阻塞。

## 💻 Windows 注意事项

- 如在 PowerShell 下运行，会自动使用 `& 'path\to\exe'` 语法；`cmd`/其它 shell 下会使用 `"path\to\exe"`
- 使用 MSVC `cl` 编译时，请确保已在“开发者命令提示符”或已正确设置 VS 环境变量的终端中启动 Neovim

## 🐞 调试

- 需要安装并配置 `nvim-dap` 与 `codelldb`
- `:QuickCDebug` 会以 `codelldb` 方案启动，`program` 指向最近一次构建输出


## ❓ 常见问题 / 故障排查

- **可执行文件写到哪里了？**
  - 由 `outdir` 决定：`"source"` 表示写到源文件所在目录；否则写到你配置的目录（相对 `:pwd` 或绝对路径）。
  - 示例：`outdir = "build/bin"` 时，`a.c` 将生成 `./build/bin/a.exe`（Windows）或 `./build/bin/a.out`（Unix）。
  - 若 `QuickCRun/QuickCDebug` 找不到 exe：请确认 `outdir` 设置与期望一致，或在 `debug.search.dirs` 中加入你的产物目录（如 `./build/bin`）。
- 找不到编译器：请确认 `gcc/g++`、`clang/clang++` 或 `cl` 在 `PATH` 中
- 构建失败但无输出：查看 Neovim `:messages` 或终端面板中的编译器警告/错误
- 终端无法发送命令：如安装了 `betterTerm` 但发送失败，插件会自动回退到内置终端
- 无法运行可执行文件：请先 `:QuickCBuild`；或检查输出目录与文件后缀（Windows 需要 `.exe`）
 - 未解析到 make 目标：确认项目存在 `Makefile`，以及 `make -qp` 在该目录下可运行；Windows 可改用 `mingw32-make`

## 🤝 贡献

欢迎贡献代码与文档！请先阅读：

- 《贡献指南》：[markdown/cn/CONTRIBUTING_GUIDE.md](markdown/cn/CONTRIBUTING_GUIDE.md)

## 📋 发布说明

参见 [Release.md](Release.md)




