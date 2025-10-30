# Quick-c Release Notes

## v1.5.8 (2025-10-30)

### 新增
- 任务队列（仅用于内部“单文件构建”路径）：
  - 全局互斥与排队，避免重复并发触发。
  - 支持取消与快速重试：新增命令 `QuickCStop`、`QuickCRetry`。
  - 支持构建超时（毫秒）：`build.timeout_ms`，默认 0 表示不超时。
- 状态接口：`require('quick-c').status()` 暴露 `phase/task/target/last` 等信息，便于 statusline/winbar 展示“编译中/成功/失败 + 目标/耗时”。

### 变更
- 移除“构建完成悬浮摘要”浮窗，改为使用 `notify` 提示，包含：结果、耗时、错误/警告计数、完整命令行。避免遮挡终端与已有面板。
- 保持 quickfix 集成与自动打开/跳转策略不变（由 `diagnostics.quickfix` 控制）。

### 修复
- `QuickCCMakeRun` 在非 CMake 目录或快速事件上下文下报错 `E5560`：
  - 目录创建与 `jobstart` 调用改为 `vim.schedule(...)` 执行，避免 fast event 上下文限制。
  - 当未检测到 `CMakeLists.txt` 时给出友好提示并返回，不再进入 configure/build。

### 文档
- README（中/英）新增示例：`build = { timeout_ms = 120000 }`。

### 兼容性
- 非破坏性变更：新增命令与配置项，默认行为不改变。
- Make/CMake 仍以“发送到终端”为主，取消方式保持 Ctrl+C，不纳入任务队列。

## v1.5.7 (2025-10-30)

### 新增
- 自动保存 Autosave（默认启用，可配置）：
  - 监听 `TextChanged`/`TextChangedI`/`InsertLeave` 等事件，按防抖时间自动保存当前缓冲。
  - 支持按文件类型白名单（默认 `{'c','cpp'}`）与忽略名单（默认忽略 `gitcommit/gitrebase`）。
  - 仅在满足条件时保存：缓冲已修改、非只读、有文件名、非特殊 `buftype`。
- 移除了 `compile_cmds` 和 `runtime` 配置项，这些配置在当前版本中已不再使用
- 修复CI日志记录中的stderr丢失问题

### 工程化（CI）
- 不中断测试：各子步骤使用 `set +e`，失败不会短路；新增“汇总步骤”统一根据子步骤退出码判定失败。
- 日志完整上传：上传步骤 `if: always()`，确保任何情况下都会上传工件。
- 详细日志：所有 `nvim` 命令追加 `2>&1 | tee -a artifacts/ci.log` 合并 stderr；关键步骤启用 `-V3 -v`、`+messages`，并用 `xpcall(..., debug.traceback)` 打印 Lua 堆栈；分阶段标记 `STEP{n} begin/end` 便于定位卡点。
- 稳定性：适度提升 `vim.wait` 超时阈值（如 3000→8000ms，5000→12000ms）以降低 CI 抖动带来的偶发超时。

### 配置
- `autosave` 配置块（在 `setup()` 或 `.quick-c.json` 中设置）：
  ```lua
  autosave = {
    enabled = true,
    debounce_ms = 1000,
    events = { 'TextChanged', 'TextChangedI', 'InsertLeave' },
    filetypes = { 'c', 'cpp' },       -- 为空或省略则表示允许所有文件类型
    ignore_filetypes = { 'gitcommit', 'gitrebase' },
  }
  ```

### 兼容性
- 无破坏性变更；如不需要可将 `autosave.enabled = false` 关闭。

### 迁移指南
- 无需迁移；如需修改触发事件或白/黑名单，可按上方配置覆盖。

## v1.5.6 (2025-10-30)

### 新增
- 智能缓存失效：监听构建脚本变化，自动清空相关缓存，避免不必要的重新解析。
  - Make：监听 `Makefile`/`makefile`/`GNUmakefile`，变化后清空当前目录的目标解析缓存。
  - CMake：监听项目根下的 `CMakeLists.txt`，变化后清空对应构建目录的目标列表缓存。
- Make 目标预览定位：使用 `<leader>cqM` 选择目标时，右侧预览会自动跳转到该目标在 Makefile 中的规则定义行（匹配 `^<target>:`）。
 - CMake 目标预览定位：使用 `<leader>cqC` 选择目标时，右侧预览会尝试跳转到 `CMakeLists.txt` 中该目标相关定义（`add_executable/add_library/add_custom_target/target_*`）。

### 改进
- 解析效率：在文件未变更时继续复用 TTL 缓存；当脚本变更时即时失效，无需等待 TTL，响应更及时。
- 体验一致性：Make/CMake 两条路径均采用 libuv 事件监听，行为统一、非阻塞。
 - 预览可读性：Make/CMake 预览窗口启用软换行 `wrap/linebreak/breakindent`，长行展示更友好；定位跳转采用“延迟 + 二次正则搜索”更稳健。

### 修复
- 修复 CMake 目标预览加载错误：正则转义在 Lua 字符串中导致 `invalid escape sequence`，改用 Lua 长字符串构造 Vim 正则。
- 修复在无 Makefile 的目录下使用 `cqM` 报错：`E5560: Vimscript function must not be called in a fast event context`，统一通过 `vim.schedule` 延迟回到主线程执行涉及 `vim.fn` 的逻辑。

### 兼容性
- 无破坏性变更。默认启用监听；在不支持文件事件的环境下会自动静默回退，不影响现有功能。

### 迁移指南
- 无需迁移与配置调整。继续按以往方式使用 Make/CMake 功能即可享受即时刷新。

## v1.5.5 (2025-10-29)

### 新增
- 构建日志自动清理：日志目录将仅保留最近 50 个 `build-*.log`，其余旧日志自动删除，`latest-build.log` 始终保留。
- Make 命令可选省略 `-C`：新增配置 `make.no_dash_C`（默认 `false`）。开启后发送命令时不附带 `-C <cwd>`，直接在当前终端目录执行。

### 改进
- Telescope/命令行/已知 cwd 三条执行路径均统一适配 `make.no_dash_C` 逻辑，行为一致。

### 兼容性
- 无破坏性变更。默认行为保持与旧版一致（仍使用 `-C <cwd>`，日志清理阈值为 50）。

### 迁移指南
- 如希望在已有终端的当前目录执行 make，请在 `setup()` 或 `.quick-c.json` 中加入：
  ```lua
  make = { no_dash_C = true }
  ```

## v1.5.4 (2025-10-27)

### 新增
- Quickfix 增强视图（Telescope）：`cqf` 打开时在右侧预览当前条目的详细信息与源码上下文（±3 行）。
- 构建日志持久化与浏览：将构建的 stdout/stderr 合并保存到
  - `stdpath('data')/quick-c/logs/latest-build.log`
  - `stdpath('data')/quick-c/logs/build-YYYYMMDD-HHMMSS.log`
  并提供 Telescope 日志浏览器，可多次打开查看完整日志。
- 新增按键：`<leader>cqL` 打开构建日志浏览器（可在配置中自定义或禁用）。

### 修复
- 修复 Lua 模式串错误：`make.lua` 内 `%` 匹配导致的 “malformed pattern (ends with '%')”。
- 修复 Telescope 回调在无选中项时访问 `entry` 导致的错误（`attempt to index local 'entry' (a nil value)`）。
- 修复 keys.lua 中辅助函数定义顺序导致的运行时报错（先使用 `disabled` 再定义）。

### 改进
- Quickfix 打开逻辑更稳健：优先使用内置增强视图，不可用时回退到 `telescope.builtin.quickfix`，再次回退 `:copen`。
- 构建失败时也可从“构建日志浏览器”反复查看完整输出，便于排错复盘。
- 日志预览跨平台实现（buffer 读取），不依赖 shell 工具。
- 日志浏览器显示相对路径（过长时回退文件名），附带修改时间，并按时间倒序排列。

### 兼容性
- 无破坏性变更；默认键位新增 `<leader>cqL`。

### 迁移指南
- 如你使用了自定义键位，请在 `setup({ keymaps = { logs = '<leader>cqL' } })` 中加入或调整。
- 若你在 README/文档中引用了旧的 quickfix 行为，请更新为“右侧带预览的增强视图（可回退）”。

## v1.5.3 (2025-10-26)

### 新增
- 编译器强制选择：新增 `compile.prefer` 与 `compile.prefer_force`
  - 可为 C/C++ 分别指定首选编译器名（例如交叉编译器）。
  - 当 `prefer_force = true` 时，即使该编译器不在 PATH 中也会直接调用（可能运行时报错，属预期行为）。

### 改进
- `choose_compiler` 逻辑支持 `compile.prefer` 优先，并在 `prefer_force` 关闭时按可执行性回退到 `toolchain` 列表（如 `gcc/clang/cl`）。
- README 与英文文档同步新增了该配置示例与说明。

### 兼容性
- 无破坏性变更；未配置时行为与旧版一致。

### 迁移指南
- 如需强制使用特定（交叉）编译器，在 `setup()` 或 `.quick-c.json` 中加入：
```lua
compile = {
  prefer = { c = 'arm-none-eabi-gcc', cpp = 'arm-none-eabi-g++' },
  prefer_force = true,
}
```

## v1.5.2 (2025-10-26)

### 新增
- 调试可执行文件选择（当默认路径不可用）：
  - `QuickCDebug` 在找不到默认可执行文件时，进行“并行异步”候选搜索，并通过 Telescope（优先）或 `vim.ui.select` 提示选择要调试的可执行文件。
  - 搜索范围包含：当前文件目录（向上 up 层、向下 down 层）、项目下常见目录（`build/`、`bin/`、`out/`）、以及配置的 `outdir`（当不为 `source`）。

### 改进
- 最近构建产物优先：
  - 构建成功后缓存“项目根”的最近一次构建产物路径；`QuickCDebug` 调试时优先使用该路径，减少选择动作。
- 搜索策略与性能：
  - 基于 libuv 的 `fs_scandir` 并发限流，BFS 按层推进，避免阻塞主线程；忽略目录做“一层探测”以提升命中率。

### 配置
- 新增配置块：
  - `debug.search.up`（默认 2）：最大向上搜索层数。
  - `debug.search.down`（默认 2）：最大向下搜索层数。
  - `debug.search.ignore_dirs`（默认 `['.git','node_modules','.cache']`）。
  - `debug.concurrency`（默认 8）：并行扫描并发数。

Lua 示例：
```lua
require('quick-c').setup({
  debug = {
    search = { up = 3, down = 2, ignore_dirs = { '.git', 'node_modules', '.cache' } },
    concurrency = 6,
  },
})
```

### 兼容性
- 无破坏性变更；默认行为为“命中最近构建产物 → 找不到时进入候选选择”。

### 迁移指南
- 无需迁移。可按需在 `setup()` 或 `.quick-c.json` 中调整 `debug.search` 与 `debug.concurrency`。

## v1.5.1 (2025-10-26)

### 修复
- 移除 `cmake.lua` 末尾冗余导出（`M.list_targets_async = M.list_targets_async`），避免阅读混淆。
- `QuickCCMakeConfigure`（`<leader>cqc`）在部分环境下因 `notify.info` 为空导致报错的问题：
  - 为 `configure_from_current` 增加 `notify` 兜底（缺失时回退到 `U.notify_*`）。

### 一致性
- 统一诊断默认值：`diagnostics.quickfix.open/jump` 默认改为 `warning`，与 README 描述一致。

### 性能/缓存
- CMake：为根目录搜索与目标列表新增 TTL 缓存（默认 10s），减少重复 IO 与命令调用。
- CMake：目标列表缓存增加失效判断，基于 `CMakeCache.txt` 或 `CMakeFiles/` 的 mtime 变化自动失效。

### 新增
- 健康检查命令：`QuickCHealth` 输出基础依赖探测结果与诊断策略摘要。

### 工程化
- CI：新增 GitHub Actions（Stylua 检查 + Luacheck）。

### 文档
- 英文 README 同步 CMake 功能、命令与键位、配置节与视图模式，新增 `QuickCHealth` 说明。
- 中/英文 README 补充 `cmake.telescope.choose_terminal` 的说明。

### 兼容性
- 无破坏性变更。默认行为趋于与文档一致。

### 迁移指南
- 无需迁移。如有自定义诊断策略，请根据需要覆盖 `diagnostics.quickfix.{open,jump}`。

### 其它改进
- CMake both 模式输出面板复用固定 buffer，并设置 `buftype=nofile`/`bufhidden=wipe`/`swapfile=false`。
- 诊断解析抽取到 `util.parse_diagnostics`，`build.lua`/`cmake.lua` 统一复用。
- Telescope 空状态提示：
  - Make 目标为空时，展示友好提示与排查建议。
  - CMake 目标为空时，提供“[配置]”入口与生成器/配置提示。

## v1.5.0 (2025-10-26)

### 新增
- CMake 支持（自动配置/列出目标/构建）
  - 新模块：`cmake.lua`（搜索 CMakeLists、`cmake -S/-B` 配置、`cmake --build` 构建、解析 `--target help` 列表）
  - 新 Telescope 入口：CMake 目标选择器（含“一键配置”）
  - 新命令：
    - `QuickCCMake`（打开 CMake 目标选择器）
    - `QuickCCMakeRun [target]`（构建默认或指定目标）
    - `QuickCCMakeConfigure`（执行 `cmake -S/-B` 配置）
  - 新默认键位：
    - `<leader>cqC`：CMake 目标选择器
    - `<leader>cqB`：CMake 构建
    - `<leader>cqc`：CMake 配置
- 新配置节：`cmake`
  - `prefer`、`generator`、`build_dir`、`search.{up,down,ignore_dirs}`
  - `configure.{extra,toolchain}`（传递额外参数与工具链文件）
  - `args.{prompt,default,remember}`（构建附加参数交互与记忆）
  - `view`（默认 `both`）：`both` 流式输出+quickfix；`quickfix` 仅 quickfix；`terminal` 仅终端
  - `output.{open,height}`：both 模式输出面板是否自动打开与高度

### 改进
- 键位系统扩展：支持 CMake 专用键位，遵循 `keymaps.unmap_defaults` 的卸载逻辑。
- 终端集成：CMake 构建命令沿用现有终端选择与发送策略。

### 修复
- 无。

### 文档
- 默认配置中补充了 CMake 配置与键位注释。

### 兼容性
- 无破坏性变更；CMake 功能默认启用，仅在检测到 `CMakeLists.txt` 时触发。
- 新增默认键位不改变既有键位；可通过 `setup({ keymaps = { ... } })` 覆盖或禁用。

### 迁移指南
- 无需迁移。建议：
  - 使用 `QuickCCMake` 与 `QuickCCMakeRun` 在 CMake 项目中进行构建；
  - 通过 `cmake.configure.extra` 设置如 `-DCMAKE_BUILD_TYPE=Debug`；
  - 如需自定义键位，使用 `setup({ keymaps = { cmake = ..., cmake_run = ..., cmake_configure = ... } })`。

## v1.4.1 (2025-10-26)

### 修复
- 避免在 `prefer` 不可执行时直接 `jobstart` 触发 E475，增加可执行性与路径存在性保护。
- 将 `QuickCCheck` 命令注册移动到 `setup()` 内，避免模块初始化次序导致的潜在作用域问题。

### 兼容性
- 无破坏性变更；本次为稳健性与体验优化。

### 迁移指南
- 无需迁移。建议：
  - 使用 `QuickCCheck` 自检配置；
  - 需要自定义整行命令时使用 `QuickCMakeCmd`；
  - 如你修改键位，保留默认的 `keymaps.unmap_defaults = true` 可自动移除旧键位。

## v1.4.0 (2025-10-26)

### 新增
- 项目级配置文件支持 (`.quick-c.json`)
  - 在项目根目录（`:pwd`）查找并加载，覆盖全局配置
  - 配置优先级：项目配置 > 用户配置 > 默认配置
  - 新命令：`QuickCReload`（重载默认+用户+项目配置）、`QuickCConfig`（打印生效配置与检测到的项目配置路径）
- 配置校验：新增 `QuickCCheck` 命令与校验模块
  - 检查项目/全局配置类型与关键路径，解析 `make.cwd` 并提示是否会在该目录内向下搜索
  - 显示最终选择的 make 程序与建议
- 文档：新增/更新项目配置指南（`PROJECT_CONFIG_GUIDE*.md`，含注释 JSONC 示例）与 README（中/英）

### 改进
- 配置加载更健壮：
  - JSON 解析支持 `vim.json.decode` 与 `vim.fn.json_decode` 回退
  - 处理 UTF-8 BOM
  - `DirChanged` 自动重载并加入 400ms 防抖
  - 重复提示去重：仅在项目配置路径变化时提示“已加载项目配置文件”，并加入 1s 提示抑制窗口
  - 使用自动命令组避免重复注册导致的多次提示
- Make 使用体验：
  - `QuickCMakeRun` 现在遵循 `make.args.prompt/default/remember`，可在运行目标时弹输入框
  - 相对 `make.cwd` 基于“当前文件所在目录”解析为绝对路径；若目录不存在自动回退到起点目录
  - 指定 `make.cwd` 但该目录没有 Makefile 时，会在该目录内“向下搜索”，深度沿用 `make.search.down`
  - Telescope 入口修正基准目录为“当前文件目录”，避免相对路径二次拼接
  - 搜索增强：对被忽略目录进行“一层探测”（不递归），若根下存在 Makefile 也纳入候选
  - `choose_make` 增强：
    - 支持 `make.prefer` 传绝对路径（含空格路径）
    - 新增 `make.prefer_force`，即使不可执行也可强制使用首选项（高阶用法）
- 键位管理：
  - 新增 `keymaps.unmap_defaults`（默认开启）：当你修改或禁用某个键位时，自动解除默认键位的旧映射，避免 which-key 中残留旧键位

### 修复
- 之前在未找到项目配置时仍提示“已加载项目配置文件”的问题
- 进入项目/保存 `.quick-c.json` 时重复提示的情况（augroup + 抑制窗口）
- 目标选择时右侧预览偶发不显示 Makefile 的问题
- `make.cwd` 无效导致 `jobstart` 报错（Invalid argument）的情况，现已在解析阶段回退并给出提示

### 兼容性
- 无破坏性变更；默认行为更稳健
- 如依赖“向上查找项目配置”的旧行为，请将 `.quick-c.json` 放到项目根（`:pwd`），或与我们讨论加入策略开关

### 迁移指南
- 无需迁移。建议：
  - 在项目根放置 `.quick-c.json`
  - 使用 `QuickCReload` 使配置立即生效；`QuickCConfig` 查看生效配置；`QuickCCheck` 自检配置

## v1.3.1 (2025-10-25)

### 新增
- Makefile 搜索结果缓存（TTL）
  - 为 `find_make_root_async` 与 `find_make_roots_async` 增加内存级缓存，默认 10 秒（可通过 `make.cache.ttl` 配置）。
  - 在 TTL 内复用相同查询结果，显著减少重复扫描、提升响应速度。

### 改进
- 文档美化：中英文 README 增添简洁图标并结构优化。
  - 增加最小配置示例（Minimal example）。
  - 新增“支持的编译器输出 / Supported compiler outputs”。
  - 小幅措辞与交互提示优化（如 Telescope 多选按键标注）。
 - 并行目录扫描：搜索阶段并发处理多个目录（最多 8 个）；在不支持异步 `fs_scandir` 的环境下自动回退为同步扫描并通过调度避免阻塞，整体搜索更快。

### 修复
- 若干 README 细节修正（排版与标注）。

### 兼容性
- 无破坏性变更；默认行为保持一致。

### 迁移指南
- 无需迁移。

## v1.3.0 (2025-10-25)

### 新增
- LSP：`compile_commands.json` 支持
  - 生成模式：为当前文件目录生成最简编译数据库
  - 指定模式：从配置的路径复制到目标目录
  - 新命令：`QuickCCompileDB` / `QuickCCompileDBGen` / `QuickCCompileDBUse`
- 多文件构建/运行
  - `:QuickCBuild/QuickCBR/QuickCRun [file1 ... fileN]` 支持传入多个源文件
  - 输出名缓存：按“源文件集合”记忆上次输入的输出名（如 `[1.c,2.c]` 与 `[1.c,2.c,3.c]` 各自独立）
- Telescope 源选择器
  - `<leader>cqS` 打开，支持多选后选择 Build / Run / Build & Run
  - 多选提示：Tab 选择，Shift+Tab 反向选择，Ctrl+Space 切换选择但不移动
 - 快速查看诊断的便捷入口
   - 新命令：`QuickCQuickfix`（优先打开 Telescope quickfix，无则 `:copen`）
   - 新键位：`<leader>cqf`

### 改进
- 默认键位前缀统一为 `<leader>cq*`
  - 构建/运行/构建并运行/调试/Make/源选择：`<leader>cqb/cqr/cqR/cqD/cqM/cqS`
- README：补充多文件与 Telescope 多选使用说明

### 修复
- `build_and_run` 运行阶段直接使用构建返回的可执行文件路径，避免多文件或自定义输出名时“构建成功但运行找不到可执行文件”

### 迁移指南
- 如你依赖旧键位，请在 `setup({ keymaps = { ... } })` 中显式配置回旧值
- `compile_commands` 默认不自动触发；需要时使用命令或在配置中切换 `mode`

## v1.2.0 (2025-10-24)

### 新增
- Make 目标参数支持：执行目标前可输入附加参数（如 `-j4 VAR=1`），并按目录记忆最近一次输入。
- `.PHONY` 优先：`.PHONY` 目标优先显示并标注 `[PHONY]`；在 Telescope 中可用 `<C-p>` 切换“仅显示 .PHONY”。

### 改进
- README 重构：移除 Autorun 功能与文档残留；完善 Make 参数与 `.PHONY` 说明，三重懒加载示例保持一致。
- 目标解析结构化：`make -qp` 解析同时产出 `{ targets, phony }` 并加入缓存（TTL + mtime）。

### 兼容性
- `make.args` 新配置：`prompt`/`default`/`remember`。
- `make.targets.prioritize_phony` 新配置，默认开启。

---
## v1.1.1 (2025-10-24)

### 改进
- 终端选择器 UX：选择已打开的内置终端发送时，默认打开/聚焦该终端窗口；默认策略条目显示命令前缀（如 `make`）。
- `make.prefer` 支持字符串或列表，按顺序探测（例如 `{ 'make', 'mingw32-make' }`）。
- 解析 make 目标增加缓存（TTL + Makefile mtime），减少重复解析（默认 10s，可通过 `make.cache.ttl` 配置）。
- Makefile 搜索支持配置化忽略目录，在多结果/单根查找中一致生效：`make.search.ignore_dirs`。
- README 更新：加入三重懒加载（ft/keys/cmd）安装与配置示例，完善预览与终端选择文档。

### 修复
- 去除了 `init.lua` 中重复的函数定义，减少冗余。
- 小幅文档修正与注释完善。

---

## v1.1.0 (2025-10-24)

### 新增
- Telescope 选择器内置 Makefile 预览：
  - 目录选择与目标选择均可预览 Makefile。
  - 目标选择阶段固定预览所选目录中的 Makefile，避免频繁刷新导致卡顿。
- 大文件与编码兼容：预览支持按字节/行数截断，避免卡顿或解码异常。
- 终端选择可配置：`make.telescope.choose_terminal = 'auto'|'always'|'never'`。
  - 选择已打开的内置终端发送时，会自动打开/聚焦该终端窗口。
- make 程序优先级支持列表：`make.prefer = { 'make', 'mingw32-make' }`，按顺序探测。

### 改进
- 预览使用更稳健的实现与跨平台路径拼接（Windows 兼容）。
- 键位注入采用 `unique=true`，不再覆盖用户已有映射。
- 解析 make 目标增加缓存（TTL + Makefile mtime），减少重复解析。

### 配置变化
- `make.telescope` 新增：
  - `preview`、`max_preview_bytes`、`max_preview_lines`、`set_filetype`、`choose_terminal`。
- 默认配置注释更详尽，README 新增使用说明与故障排查。
- 默认快捷键：`make` 改为 `<leader>cM`（避免与部分配置冲突）。

### 迁移指南
- 如你依赖旧的 `<leader>cm`，请在 `setup({ keymaps = { make = '<leader>cm' } })` 中显式设置。
- 如不希望弹出终端选择器，将 `make.telescope.choose_terminal = 'never'`。

---

## v1.0.1 (2025-10-24)

### 内部重构

- 拆分大文件 `init.lua` 为多个模块，维护性更好，API 不变：
  - `config.lua` 默认配置
  - `util.lua` 工具函数（平台/路径/消息）
  - `terminal.lua` 终端封装（betterTerm/内置）
  - `make_search.lua` 异步 Makefile 搜索与目录选择
  - `make.lua` 选择 make/解析目标/在 cwd 执行
  - `telescope.lua` Telescope 交互（目录与目标、自定义参数）
  - `build.lua` 构建/运行/调试
  - `autorun.lua` 保存即运行
  - `keys.lua` 键位注入

