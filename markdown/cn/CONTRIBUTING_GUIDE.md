# 贡献指南

感谢你对 quick-c 的关注与贡献！本指南旨在帮助你高效、规范地参与到项目开发中。

## 快速开始

- **阅读文档**
  - 项目说明：`README.md` / `README.en.md`
  - 配置相关：`markdown/cn/PROJECT_CONFIG_GUIDE.md`
  - 性能优化：`markdown/cn/PERFORMANCE_TUNING_GUIDE.md`
  - 配置示例：`markdown/cn/CONFIGURATION_GUIDE.md`

- **环境准备**
  - Lua 5.1+（或宿主环境，如 Neovim）
  - 格式化：Stylua（依据 `.stylua.toml`）
  - 静态检查：Luacheck（依据 `.luacheckrc`）

## 分支与提交流程

- **分支策略**
  - 在 `dev` 基础上创建特性分支：`feat/<topic>`
  - 修复分支：`fix/<issue-id-or-topic>`
  - 文档与杂项：`docs/<topic>`、`chore/<topic>`
  - 或者基于 `pre` 分支进行创建(实验性开发分支)，同上
  - 默认目标分支：`dev`。除紧急修复外，请勿直接向 `main` 提交 PR。

- **提交信息（建议遵循 Conventional Commits）**
  - `feat: 新增...`
  - `fix: 修复...`
  - `docs: 更新文档...`
  - `refactor: 重构...`
  - `perf: 性能优化...`
  - `test: 补充测试...`
  - `chore: 构建/依赖/工具...`

- **提交前检查**
  - 运行格式化：`stylua .`(非必须，但是要尽量保证格式一致)
  - 运行静态检查：`luacheck lua plugin`(非必须，但是CI测试会进行测试，不通过则无法进行PR)
  - 确保不引入无关文件与调试输出

## 必要说明

- 新增的配置项请在 `README.md` 的“默认配置/最小示例”中补充并附带说明。
- 新增或变更的配置项请同步更新：
  - `markdown/cn/PROJECT_CONFIG_GUIDE.md`
  - `markdown/cn/CONFIGURATION_GUIDE.md`
  - 涉及性能/并发策略时更新：`markdown/cn/PERFORMANCE_TUNING_GUIDE.md`

## CI 与质量门禁

- GitHub Actions 将执行 Stylua 与 Luacheck 检查；日志/工件会在失败时也上传，任何失败都会阻止合并。
- 本地建议先运行：`stylua .` 与 `luacheck lua plugin`，以减少 CI 反复。
- Make/CMake 流程以“发送到终端”为主，取消方式保持 Ctrl+C；与文档描述保持一致。

## 文档同步要求

- `README.md`：命令与键位矩阵、配置章节、快速开始/FAQ 等需同步。
- `README.en.md`：如可，请同步英文文档（英文文档可能滞后，欢迎协助）。
- 变更较大时：在 PR 描述中附上 `Release.md` 的草案条目，维护者会在发布时统一整理。

## 兼容性与迁移

- 默认不引入破坏性变更（Non-breaking）。如确需破坏性变更：
  - 在 PR 标题或描述中显式标注 `BREAKING CHANGE`。
  - 提供“迁移指南”小节：变更点、影响范围、替代配置/使用方式示例。
  - 优先提供兼容过渡期或向后兼容代码路径（如保留旧配置名并标记弃用）。

## 模块与代码结构约定

- 参照 README 的“架构说明”，按模块放置改动：
  - `lua/quick-c/init.lua`（装配/命令/键位）
  - `lua/quick-c/config.lua`（默认配置）
  - `lua/quick-c/util.lua`（工具函数）
  - `lua/quick-c/terminal.lua`（终端封装）
  - `lua/quick-c/make_search.lua`、`make.lua`、`telescope.lua`（Make 路径）
  - `lua/quick-c/cc.lua`（compile_commands.json）
  - `lua/quick-c/build.lua`、`keys.lua`
- 保持函数单一职责，复用现有工具与通知封装。

## 代码风格

- **Lua 代码**
  - 按 `.stylua.toml` 自动格式化
  - 通过 `.luacheckrc` 的规则检查
  - 保持函数短小、单一职责，命名清晰

- **目录约定**
  - 源码：`lua/`、`plugin/`
  - 文档：`markdown/`
  - 变更记录：`Release.md`

## PR（合并请求）

- **PR 内容**
  - 说明改动动机与影响范围
  - 如有关联 Issue，请在描述中引用（例如 `Fixes #123`）
  - 只有 CI 通过后，并且维护者确认无误后，PR 才会被合并

- **PR 自检清单**
  - [ ] 本地通过 `stylua` 与 `luacheck`
  - [ ] 更新了相关文档/注释（如适用）
  - [ ] 覆盖必要的边界情况（如适用）
  - [ ] 同步更新 `README.md`/`README.en.md` 与 `markdown/cn/*`（如涉及）
  - [ ] 在 PR 描述中附上 `Release.md` 草案条目（如有用户可见改动）
  - [ ] 兼容性评估：如有破坏性变更，已提供迁移说明

## Issue 报告

- 提供复现步骤、期望与实际行为
- 附带最小可复现配置（如 `init.lua` 片段）
- 标注平台、Lua/Neovim 版本、插件版本

## 发布与版本

- 版本遵循语义化（SemVer），v1.2.3中，1代表主版本，2代表次版本，3代表修订版本，维护修改3，新增大功能修改2，功能增加的一定数量由维护者决定修改1
- 重要变更会在 `Release.md` 中记录
- 版本号与发布由维护者管理；请勿在 PR 中自行修改版本号或发布标签。

## 行为准则

- 尊重彼此、积极协作
- 反馈具体、可行动；避免人身指摘

## 许可证

- 贡献意味着你同意以项目现有许可证发布你的改动

## 常见问题

- Stylua/Luacheck 未找到
  - 请先安装：
    - Stylua: https://github.com/JohnnyMorganz/StyLua
    - Luacheck: https://github.com/lunarmodules/luacheck
- 风格与检查意见冲突
  - 以项目配置为准，必要时在 PR 中说明理由

如果有任何疑问，欢迎直接提 Issue 或发起讨论。感谢你的贡献！
