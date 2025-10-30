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
  <a href="README.md">中文</a> | <b>English</b>
</p>

# Quick-c

> [!IMPORTANT]
> This document is not synchronized with the Chinese document and may lag behind the Chinese document.
>
> I would be very grateful if you could translate or correct errors in this document.

Lightweight Neovim plugin for C/C++: build, run, and debug the current file in one key. Works on Windows/Linux/macOS. Integrates with BetterTerm and the built-in terminal. Fully async.

## ✨ Features

 - 🚀 Build/Run (async): `QuickCBuild`, `QuickCRun`, `QuickCBR` (build & run)
 - 🐞 Debug integration: `QuickCDebug` via `nvim-dap` and `codelldb`
 - 🌐 Cross-platform: auto select compiler (gcc/clang/cl) and runtime (PowerShell/terminal)
 - 📁 Flexible output dir: default to source folder; configurable
 - 🔧 Make integration: auto discover Makefiles, list targets, .PHONY prioritization, argument input with remember
  - 🧭 Robust parsing: fallback to `-pn` if `-qp` yields nothing; support Windows-style paths in targets
  - 🧪 If `prefer` is not executable, use an available make (make/mingw32-make/nmake) only for parsing; running still uses your `prefer`
- 🏗️ CMake integration: search CMakeLists, `cmake -S/-B` configure, `cmake --build` with target list (`--target help`)
  - View modes: `both` (stream output + quickfix), `quickfix`, `terminal`
  - Output panel: `cmake.output.{open,height}`
- 🔭 Telescope enhancements: built-in Makefile preview, source multi-select, quick toggle .PHONY
- 🧪 Enhanced Quickfix preview: when opening `cqf`, show detailed error and source context on the right
- 🧠 Smart cache invalidation: watch `Makefile`/`CMakeLists.txt` changes and invalidate related caches immediately (not only TTL-based), reducing unnecessary re-parsing.
- 🔎 Make/CMake preview upgrades: target picker preview jumps to the selected target's definition (deferred + fallback search) and enables soft wrapping (wrap/linebreak/breakindent) for readability.

## 🚀 Quick Start

- Build: `:QuickCBuild` or `<leader>cqb`
- Run: `:QuickCRun` or `<leader>cqr`
- Build & Run: `:QuickCBR` or `<leader>cqR`
- Debug: `:QuickCDebug` or `<leader>cqD`
- When the default executable is missing, `QuickCDebug` will search for alternatives in preferred directories (e.g., `./build/bin`, `./out`) and prompt a picker.

Multi-file:

- C: `:QuickCBuild main.c util.c`
- C++: `:QuickCBR src/main.cpp src/foo.cpp`
- Or press `<leader>cqS` to open Telescope source picker
  - Tab multi-select (Shift+Tab backward, Ctrl+Space toggle)
  - Enter to choose Build / Run / Build & Run

Note: the list shows paths relative to cwd; absolute paths are used internally.

Output name prompt & cache:

- Multi-file: always prompt; default is the last name used for the same source set
- Single-file: default to current filename (Windows adds .exe)

If the current buffer is unnamed and modified, auto-jump from diagnostics is skipped to avoid save prompts.

### Supported compiler outputs

- gcc/g++
- clang/clang++
- MSVC cl

## 📦 Dependencies

- Neovim 0.8+
- Telescope (optional, recommended)
- nvim-dap + codelldb (for debugging)

## ⌨️ Commands

### Commands & Keymaps Matrix (Quick Reference)

| Category | Command | Description | Default Keymap |
| --- | --- | --- | --- |
| Build/Run/Debug | `QuickCBuild` | Build current/selected sources | `<leader>cqb` |
|  | `QuickCRun` | Run the last built executable | `<leader>cqr` |
|  | `QuickCBR` | Build & Run | `<leader>cqR` |
|  | `QuickCDebug` | Debug with codelldb (last built program) | `<leader>cqD` |
| Make | `QuickCMake` | Choose directory and targets to run | `<leader>cqM` |
|  | `QuickCMakeRun [target]` | Run a specific target directly | — |
|  | `QuickCMakeCmd` | Prompt a full make command and send to terminal | — |
| CMake | `QuickCCMake` | Open CMake target picker | `<leader>cqC` |
|  | `QuickCCMakeRun [target]` | Build default or specified target | `<leader>cqB` |
|  | `QuickCCMakeConfigure` | Run cmake configure (-S/-B) | `<leader>cqc` |
| Sources | — | Telescope source picker | `<leader>cqS` |
| Diagnostics | `QuickCQuickfix` | Open quickfix (prefer Telescope) | `<leader>cqf` |
| Config | `QuickCCompileDB` | Apply compile_commands.json (generate into source dir) | — |
|  | `QuickCCompileDBGen` | Generate compile_commands.json | — |
|  | `QuickCCompileDBUse` | Use external compile_commands.json | — |
|  | `QuickCCheck` | Validate configuration | — |
|  | `QuickCHealth` | Health report | — |
|  | `QuickCReload` | Reload configuration | — |
|  | `QuickCConfig` | Print effective configuration & project path | — |

## ⌨️ Keymaps (normal mode)

- `<leader>cqb` build
- `<leader>cqr` run
- `<leader>cqR` build & run
- `<leader>cqD` debug
- `<leader>cqM` Telescope Make targets
- `<leader>cqC` CMake targets (Telescope)
- `<leader>cqB` CMake build
- `<leader>cqc` CMake configure
- `<leader>cqS` Telescope source picker
- `<leader>cqf` Open quickfix (Telescope)
- `<leader>cqL` Build logs (Telescope)

## 🧪 Diagnostics -> Quickfix / Telescope

- Parses gcc/clang/MSVC output to quickfix (errors & warnings)
- Auto open/jump policy: `always | error | warning | never`
- Prefer an enhanced Quickfix Telescope picker when available: right-side preview shows the item's message and ±3 lines of source context. Fallbacks to `telescope.builtin.quickfix`, then to `:copen`.
- If the current buffer is unnamed and modified, auto-jump is skipped to avoid save prompts.

## ⚙️ Configuration

Quick-c supports multi-level configuration with priority from high to low:
1. Project-level configuration (`.quick-c.json`) - overrides global config
2. User configuration (`setup()` parameters) - user customizations
3. Default configuration - plugin built-in defaults

### Project-level Configuration File

Create a `.quick-c.json` file in your project root directory to customize configuration for specific projects, overriding global settings. The plugin automatically detects and applies project configuration when available.

**Configuration file lookup rules:**
- Only search in the current working directory (`:pwd`, project root)
- File name is fixed to `.quick-c.json`
- On directory change (`DirChanged`), configuration is auto reloaded (with 400ms debounce)

**Configuration format:**
- JSON format
- Same structure as Lua configuration
- Support all configuration options

more details in [GUIDE](markdown/en/PROJECT_CONFIG_GUIDE.en.md).

Notes:
- With `make.prefer_force = true`:
  - If `prefer` is not executable, parsing will only warn and try an available make to discover targets;
  - Running still uses your `prefer` to build the command (combine with `QuickCMakeCmd` for full control).
- Parsing fallback: try `-pn` when `-qp` returns nothing.

Example `.quick-c.json` (annotated):
```jsonc
{
  // Output directory: "source" means write to the same folder as the source file; custom path is supported
  "outdir": "build",

  // Toolchain priority (per platform, per language); picks the first executable
  "toolchain": {
    "windows": { "c": ["gcc", "cl"], "cpp": ["g++", "cl"] },
    "unix":    { "c": ["gcc", "clang"], "cpp": ["g++", "clang++"] }
  },
  

  // compile_commands.json for LSP (e.g., clangd)
  "compile_commands": {
    "mode": "generate",     // generate | use
    "outdir": "build"        // where to write; "source" writes to the source file's directory
    // "use_path": "./compile_commands.json" // when mode = use, copy from this path
  },

  // Diagnostics collection into quickfix
  "diagnostics": {
    "quickfix": {
      "open": "warning",      // always | error | warning | never
      "jump": "warning",      // always | error | warning | never
      "use_telescope": true    // prefer Telescope quickfix if available
    }
  },

  // Make settings
  "make": {
    // Preferred make program: string or list; on Windows often ["make", "mingw32-make"]
    "prefer": ["make", "mingw32-make"],
    // Force using the preferred value even if not found in PATH or file missing
    // e.g., { "prefer": "make", "prefer_force": true }
    "prefer_force": false,
    // Optional wrapper (planned): run via WSL on Windows, e.g., "wsl"
    // "wrapper": "wsl",

    // Fixed working directory used for -C
    // Note: the directory must exist; otherwise it falls back to the start dir with a warning
    // If it has no Makefile, the plugin will search downward within this directory (depth = search.down)
    "cwd": ".",

    // Search strategy (used when cwd is not set, or cwd requires searching within it)
    "search": {
      "up": 2,                       // go up at most this many levels (bounded by :pwd)
      "down": 3,                     // per-level downward recursion depth
      "ignore_dirs": [".git", "node_modules", ".cache"] // directories to skip
      // Enhancement: even for ignored dirs, perform a one-level probe; if a Makefile exists at the root, include it
    },

    // Telescope display
    "telescope": { "prompt_title": "Project Build Targets" },

    // Target cache: reuse results within TTL when Makefile unchanged under the same cwd
    "cache": { "ttl": 10 },

    // Extra make args (e.g., -j4 VAR=1), remember last input per cwd
    "args": { "prompt": true, "default": "-j4", "remember": true }
  },

  // Debug executable discovery when the default path is missing
  "debug": {
    "search": {
      "dirs": ["./build/bin", "./out"],  // preferred directories; fall back to up/down if absent
      "up": 2,                              // limit upward search within :pwd
      "down": 2,                            // downward breadth-first depth
      "ignore_dirs": [".git", "node_modules", ".cache"],
    },
    "concurrency": 8,                       // parallel fs_scandir concurrency
  },

  // Compiler preference and force mode (similar to make.prefer_force)
  "compile": {
    "prefer": { "c": "arm-none-eabi-gcc", "cpp": "arm-none-eabi-g++" },
    "prefer_force": false
  },

  // Default keymaps (customizable/disable-able); injected only when keymaps.enabled != false
  "keymaps": {
    "build": "<leader>cb",
    "run": "<leader>cr",
    "build_and_run": "<leader>cR",
    "debug": "<leader>cD",
    "make": "<leader>cM",
    "sources": "<leader>cS",
    "quickfix": "<leader>cf"
    // When you change/disable a key, old default mappings are automatically unmapped by default
    // Set `unmap_defaults = false` to keep them
  }
}
```

### User Configuration

Minimal example:

```lua
require('quick-c').setup({
  outdir = 'source',
  toolchain = {
    windows = { c = { 'gcc', 'cl' }, cpp = { 'g++', 'cl' } },
    unix    = { c = { 'gcc', 'clang' }, cpp = { 'g++', 'clang++' } },
  },
  compile = {  -- It only works when you want to use custom tools. And make.prefer_force = true
    prefer = { c = nil, cpp = nil }, -- such c = i686-gcc-elf
    prefer_force = false,
  },
  make = {
    prefer = { 'make', 'mingw32-make' },
    cache = { ttl = 10 },
    -- When true, omit `-C <cwd>` and run in the terminal's current directory
    no_dash_C = false,
    telescope = { choose_terminal = 'auto' },
  },
  diagnostics = {
    quickfix = { open = 'warning', jump = 'warning', use_telescope = true },
  },
  -- Force a specific compiler name (useful for cross toolchains). When prefer_force = true,
  -- the name is used even if not found in PATH (may fail to run; expected consequence).
  compile = {
    prefer = { c = 'arm-none-eabi-gcc', cpp = 'arm-none-eabi-g++' },
    prefer_force = false,
  },
  debug = {
    search = {
      dirs = { './build/bin', './out' },
      up = 2,
      down = 2,
      ignore_dirs = { '.git', 'node_modules', '.cache' },
    },
    concurrency = 8,
  },
  keymaps = {
    enabled = true,
    build = '<leader>cqb',
    run = '<leader>cqr',
    build_and_run = '<leader>cqR',
    debug = '<leader>cqD',
  },
})
```

Example (trimmed):

```lua
require('quick-c').setup({
  outdir = 'source',
  toolchain = {
    windows = { c = { 'gcc', 'cl' }, cpp = { 'g++', 'cl' } },
    unix    = { c = { 'gcc', 'clang' }, cpp = { 'g++', 'clang++' } },
  },
  make = {
    prefer = { 'make', 'mingw32-make' },
    cache = { ttl = 10 },
    targets = { prioritize_phony = true },
    args = { prompt = true, default = '', remember = true },
    -- When true, omit `-C <cwd>` and run in the terminal's current directory
    no_dash_C = false,
    telescope = { choose_terminal = 'auto' },
  },
  diagnostics = {
    quickfix = {
      enabled = true,
      open = 'warning',   -- always | error | warning | never
      jump = 'warning',   -- always | error | warning | never
      use_telescope = true,
    },
  },
  debug = {
    search = {
      dirs = { './build/bin', './out' },
      up = 2,
      down = 2,
      ignore_dirs = { '.git', 'node_modules', '.cache' },
    },
    concurrency = 8,
  },
  keymaps = {
    enabled = true,
    build = '<leader>cqb',
    run = '<leader>cqr',
    build_and_run = '<leader>cqR',
    debug = '<leader>cqD',
    make = '<leader>cqM',
    sources = '<leader>cqS',
    quickfix = '<leader>cqf',
  },
})
```

## 🧩 Install (lazy.nvim)

```lua
{
  "AuroBreeze/quick-c",
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
    "QuickCMake", "QuickCMakeRun", "QuickCMakeCmd",
    "QuickCCompileDB", "QuickCCompileDBGen", "QuickCCompileDBUse",
    "QuickCQuickfix", "QuickCCheck",
  },
  config = function()
    require("quick-c").setup()
  end,
}
```

## 🧩 Install (packer.nvim)

```lua
use({
  'AuroBreeze/quick-c',
  config = function()
    require('quick-c').setup()
  end,
})
```

### CMake configuration (excerpt)

```lua
require('quick-c').setup({
  cmake = {
    enabled = true,
    prefer = nil,            -- cmake executable
    generator = nil,         -- e.g. "Ninja" | "Unix Makefiles" | ...
    build_dir = 'build',     -- relative to project root
    view = 'both',           -- 'both' | 'quickfix' | 'terminal'
    output = { open = true, height = 12 },
    search = { up = 2, down = 3, ignore_dirs = { '.git', 'node_modules', '.cache' } },
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
  },
})
```

### CMake terminal selection

- Terminal selection for CMake targets/build is controlled by `cmake.telescope.choose_terminal` (same semantics as `make.telescope.choose_terminal`):
  - `auto`: if a terminal is open, show a selector; otherwise use the default strategy (BetterTerm first, fallback to native)
  - `always`: always show the selector
  - `never`: always use the default strategy

## 📚 Telescope preview notes

- Both directory and target pickers include Make/CMake previews with improved Windows path compatibility.
- In the target picker, the preview is fixed to the `Makefile` (selected directory) or `CMakeLists.txt` (project root) for performance.
- Preview enhancements:
  - Jump-to-definition: after selecting a target, the preview auto-scrolls to its definition in `Makefile`/`CMakeLists.txt`.
  - Soft wrapping: wrap/linebreak/breakindent are enabled in preview for long lines.
- Large files are truncated by bytes/lines; controlled by:
  - `make.telescope.preview`
  - `make.telescope.max_preview_bytes`
  - `make.telescope.max_preview_lines`
  - `make.telescope.set_filetype`
  - CMake preview also enables jump and wrapping by default; advanced knobs can be added similarly under `cmake.telescope` if needed.

## 🔌 Terminal selection behavior

- After selecting a Make target, commands can be sent to an opened built-in terminal, or follow the default strategy (BetterTerm first, fallback to native terminal).
- Configure via `make.telescope.choose_terminal`:
  - `auto`: if a terminal is open, show selector; otherwise use default strategy
  - `always`: always show selector
  - `never`: always use default strategy

## 🔎 Makefile search notes

- If `make.cwd` is not set, the plugin searches from the current file's directory:
  - Up to `search.up` levels upward (default 2)
  - For each level, recursively downward up to `search.down` (default 3)
  - The first directory containing `Makefile`/`makefile`/`GNUmakefile` is used as cwd
  - Directories in `ignore_dirs` are skipped (default: `.git`, `node_modules`, `.cache`)
  - Enhancement: for ignored directories, perform a one-level probe (no recursion). If a Makefile exists at the root of that ignored directory, include it as a candidate

When multiple results are found, Telescope shows paths relative to `:pwd` for clarity (e.g., `./build`, `./sub/dir`).

## 🛠️ Architecture

- Modules
  - `lua/quick-c/init.lua`: wiring, commands, keymaps
  - `lua/quick-c/config.lua`: defaults
  - `lua/quick-c/util.lua`: utils (platform/path/messages)
  - `lua/quick-c/terminal.lua`: BetterTerm/native terminal
  - `lua/quick-c/make_search.lua`: async Makefile search & directory select
  - `lua/quick-c/make.lua`: choose make/parse targets/run in cwd
  - `lua/quick-c/telescope.lua`: Telescope interactions (make targets, custom args, source picker)
  - `lua/quick-c/build.lua`: build/run/debug
  - `lua/quick-c/cc.lua`: compile_commands.json
  - `lua/quick-c/keys.lua`: key injection

## 💻 Windows notes

- On PowerShell, runs as `& 'path\\to\\exe'`; on other shells, runs as `"path\\to\\exe"`.
- For MSVC `cl`, run Neovim from a Developer Command Prompt or with VS env vars initialized.

## 🐞 Debugging

- Requires `nvim-dap` and `codelldb`.
- `:QuickCDebug` launches with codelldb; `program` points to the last build output.

## 🔎 Troubleshooting

- Compiler not found: ensure `gcc/g++`, `clang/clang++`, or `cl` are in PATH.
- Build failed without output: check `:messages` or the terminal panel for warnings/errors.
- Cannot send to terminal: if BetterTerm fails, the plugin falls back to the native terminal automatically.
- Cannot run executable: build first with `:QuickCBuild`; also check output directory and `.exe` on Windows.
- No make targets found: ensure a Makefile exists and `make -qp` works in that directory; on Windows try `mingw32-make`.

### FAQ

- Where is the executable written?
  - Controlled by `outdir`:
    - `"source"`: write to the source file's directory (default)
    - otherwise: your custom directory (relative to `:pwd` or absolute path)
  - Example: with `outdir = "build/bin"`, `a.c` produces `./build/bin/a.exe` (Windows) or `./build/bin/a.out` (Unix).
  - If `QuickCRun/QuickCDebug` cannot find the program: verify `outdir` or add your artifact directory to `debug.search.dirs` (e.g., `./build/bin`).


## 📋 Release notes

See [Release.md](Release.md)

