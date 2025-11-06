# Quick-c Configuration Guide (EN)

This guide summarizes key Quick-c options, defaults, and examples.

- Scope
  - User-level: `require('quick-c').setup({ ... })`
  - Project-level: place `.quick-c.json` at project root (see PROJECT_CONFIG_GUIDE.en.md)

## Overview

- `outdir` executable output location
- `toolchain` / `compile` compiler preference & forcing
- `diagnostics.quickfix` build diagnostics list behavior
- `terminal` / `betterterm` run window behavior
- `make` Make integration (search, targets, Telescope)
- `cmake` CMake integration (root, configure, build, Telescope)
- `debug` discover executables for debugging
- `keymaps` default key bindings

## Toolchain & Compile

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

### Custom Compile Command: compile.user_cmd
- Purpose: keep default behavior while allowing optional "append args" or "full replacement via presets".
- Default: disabled. When disabled (or no popup), the built-in command is used (backward compatible).

```lua
compile = {
  user_cmd = {
    enabled = true,                 -- enable custom compile command
    telescope = { popup = true },   -- show picker (Use built-in / Custom args… / presets)
    -- Default value for the "Custom args…" input when no history exists.
    -- Accepts string or array (array will be joined with spaces as default text)
    default = { "-O2", "-DNDEBUG" },  -- or "-O2 -DNDEBUG"
    remember_last = true,           -- remember per-project last input
    -- Presets: full replacement (argv array; safer than a single string)
    -- Placeholders supported: {sources} {out} {cc} {ft}
    presets = {
      { "{cc}", "-g", "-O0", "-Wall", "-Wextra", "{sources}", "-o", "{out}" },
      { "{cc}", "-O2", "{sources}", "-o", "{out}" },
    },
  },
}
```

- Placeholders:
  - `{sources}` list of source files (expands into multiple argv elements)
  - `{out}` output executable path
  - `{cc}` chosen compiler (gcc/g++/clang/clang++/cl)
  - `{ft}` filetype (c/cpp)
- Literal escaping: `%{sources%}` / `%{out%}` / `%{cc%}` / `%{ft%}` are kept as text (no substitution).
- Behavior details:
  - `[Use built-in]`: use built-in command (default behavior).
  - `[Custom args…]`: append args to the built-in argv; default input prefers last value, otherwise uses `default`.
  - A `presets` entry: generate a full argv from the template; typically include at least `{sources}` and `{out}`.

## Diagnostics: diagnostics.quickfix

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
