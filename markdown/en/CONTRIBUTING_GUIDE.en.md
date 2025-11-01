# Contribution Guide

Thank you for your interest in and contribution to **Quick-c**!
This guide is intended to help you participate efficiently and consistently in the project’s development.

---

## Getting Started

* **Read the documentation**

  * Project overview: `README.md` / `README.en.md`
  * Configuration details: `markdown/cn/PROJECT_CONFIG_GUIDE.md`
  * Performance tuning: `markdown/cn/PERFORMANCE_TUNING_GUIDE.md`
  * Configuration examples: `markdown/cn/CONFIGURATION_GUIDE.md`

* **Environment setup**

  * Lua 5.1+ (or a host environment such as Neovim)
  * Code formatting: [Stylua](https://github.com/JohnnyMorganz/StyLua) (per `.stylua.toml`)
  * Static analysis: [Luacheck](https://github.com/lunarmodules/luacheck) (per `.luacheckrc`)

---

## Branching and Commit Workflow

* **Branch strategy**

  * Create feature branches from `dev`: `feat/<topic>`
  * Bug fixes: `fix/<issue-id-or-topic>`
  * Docs and maintenance: `docs/<topic>`, `chore/<topic>`
  * Experimental features may be branched from `pre` (pre-release branch)
  * Default PR target: `dev`
    → Do not open PRs directly to `main` unless for critical hotfixes.

* **Commit messages** *(follow [Conventional Commits](https://www.conventionalcommits.org/) when possible)*

  * `feat: add ...`
  * `fix: resolve ...`
  * `docs: update ...`
  * `refactor: restructure ...`
  * `perf: optimize ...`
  * `test: add tests ...`
  * `chore: build/deps/tools ...`

* **Pre-commit checklist**

  * Run formatter: `stylua .` (optional but preferred)
  * Run static analysis: `luacheck lua plugin` (optional locally, required in CI)
  * Avoid committing unrelated files or debug output

---

## Required Updates

* Any **new configuration option** must be added and documented in the `README.md` under “Default Config / Minimal Example.”
* For new or modified configuration items, also update:

  * `markdown/cn/PROJECT_CONFIG_GUIDE.md`
  * `markdown/cn/CONFIGURATION_GUIDE.md`
  * `markdown/cn/PERFORMANCE_TUNING_GUIDE.md` (for performance/concurrency-related changes)

---

## CI and Quality Gates

* **GitHub Actions** runs Stylua and Luacheck automatically.
  Logs and artifacts are uploaded even on failure. Any failed check blocks merging.
* It’s recommended to run `stylua .` and `luacheck lua plugin` locally to avoid repeated CI failures.
* The Make/CMake workflow uses “send to terminal” as the execution mode.
  Use `Ctrl+C` to cancel — keep it consistent with the documentation.

---

## Documentation Synchronization

* `README.md`: Keep command/keybinding matrices, configuration sections, and Quick Start/FAQ up to date.
* `README.en.md`: Please update English docs as well when possible (they may lag behind).
* For major changes, include draft `Release.md` entries in your PR description; maintainers will finalize them before release.

---

## Compatibility and Migration

* Avoid breaking changes whenever possible.
  If a breaking change is unavoidable:

  * Mark it explicitly in the PR title or description using `BREAKING CHANGE`.
  * Provide a “Migration Guide” section describing the change, affected areas, and replacement usage.
  * Prefer backward-compatible paths when possible (e.g., keep deprecated options temporarily).

---

## Code and Module Structure

Follow the module layout described in the **Architecture Overview** of the README:

* `lua/quick-c/init.lua` – initialization, commands, and keymaps
* `lua/quick-c/config.lua` – default configuration
* `lua/quick-c/util.lua` – utility functions
* `lua/quick-c/terminal.lua` – terminal abstraction layer
* `lua/quick-c/make_search.lua`, `make.lua`, `telescope.lua` – Make integration
* `lua/quick-c/cc.lua` – `compile_commands.json` handling
* `lua/quick-c/build.lua`, `keys.lua` – build & keybinding logic

Keep each function focused, reuse existing utilities and notification wrappers.

---

## Code Style

* **Lua**

  * Must be formatted with `.stylua.toml`
  * Must pass `.luacheckrc` rules
  * Functions should remain short, single-purpose, and clearly named

* **Directory layout**

  * Source: `lua/`, `plugin/`
  * Docs: `markdown/`
  * Changelog: `Release.md`

---

## Pull Requests (PRs)

* **PR content**

  * Explain motivation and impact
  * Reference related issues (e.g., `Fixes #123`)
  * PRs are merged only after passing CI and maintainer review

* **PR self-check**

  * [ ] Passed `stylua` and `luacheck` locally
  * [ ] Updated related docs/comments (if applicable)
  * [ ] Covered edge cases (if applicable)
  * [ ] Synced `README.md` / `README.en.md` / `markdown/cn/*` (if relevant)
  * [ ] Added draft `Release.md` entry (for user-visible changes)
  * [ ] Evaluated backward compatibility and migration steps (if breaking)

---

## Issue Reports

When reporting an issue, please include:

* Reproduction steps, expected vs actual behavior
* Minimal reproducible configuration (e.g., relevant `init.lua` snippet)
* Platform, Lua/Neovim version, and plugin version

---

## Releases and Versioning

* **Semantic Versioning (SemVer)** is used:
  `v1.2.3` → `1` = major, `2` = minor, `3` = patch

  * Patch (`x.x.1`): maintenance fixes
  * Minor (`x.1.x`): new features
  * Major (`1.x.x`): breaking or large-scale changes
* Major changes are recorded in `Release.md`
* Version numbers and releases are managed by maintainers —
  do **not** modify them in PRs.

---

## Code of Conduct

* Be respectful, constructive, and collaborative.
* Feedback should be specific and actionable — avoid personal criticism.

---

## License

By contributing, you agree that your work will be released under the project’s existing license.

---

## FAQ

* **Stylua/Luacheck not found**

  * Install via:

    * Stylua: [https://github.com/JohnnyMorganz/StyLua](https://github.com/JohnnyMorganz/StyLua)
    * Luacheck: [https://github.com/lunarmodules/luacheck](https://github.com/lunarmodules/luacheck)
* **Conflict between formatter and linter rules**

  * Follow the project’s configuration; if necessary, explain the rationale in your PR.

---

If you have any questions, feel free to open an **Issue** or start a **Discussion**.
Thank you for contributing to **Quick-c**!
