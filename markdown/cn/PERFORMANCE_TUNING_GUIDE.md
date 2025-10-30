# Quick-c 性能调优指南（中文）

本指南提供在不同系统/硬件环境下优化 quick-c 交互与 IO 的建议，重点在“异步并发、预览限流、缓存与策略选择”。

## 目标
- 在大型项目与慢速磁盘上保持流畅
- 避免阻塞 Neovim 主线程
- 兼顾可观测性（日志/诊断）与性能

## 一、并发控制（核心旋钮）

- `make.concurrency`：Makefile 目录发现等操作的并发工作者数
- `cmake.concurrency`：CMake 根目录发现等操作的并发工作者数
- 回退策略：未设置时回退到 `debug.concurrency`，再回退默认 `8`

推荐值：
- 低配/机械硬盘：`2 ~ 4`
- 常规 SSD/开发机：`8`（默认）
- 高性能 NVMe/服务器：`12 ~ 16`（如遇高负载可下调）

示例：
```lua
make = { concurrency = 8 }
cmake = { concurrency = 8 }
-- 可统一用 debug.concurrency 作为回退：
debug = { concurrency = 8 }
```

## 二、Telescope 预览限流

- Make 预览：`make.telescope.{max_preview_bytes,max_preview_lines,set_filetype}`
- CMake 预览：`cmake.telescope.{max_preview_bytes,max_preview_lines}`
- 建议：
  - 大 Makefile/CMakeLists：将 `max_preview_bytes` 调小，如 `100*1024`
  - 超大文件时会自动截断并在首行提示
  - 极限场景可将 `preview = false`

示例：
```lua
make = { telescope = { preview = true, max_preview_bytes = 150*1024, max_preview_lines = 1500 } }
cmake = { telescope = { preview = true, max_preview_bytes = 150*1024, max_preview_lines = 1500 } }
```

## 三、缓存策略

- Make 目标解析缓存：`make.cache.ttl`（秒）
  - 值越大，解析越少，列表越快；但更改 Makefile 后可能有短暂滞后
  - CMake 目标解析自动监听 `CMakeLists.txt`/`CMakeCache.txt` 变更并失效缓存

示例：
```lua
make = { cache = { ttl = 10 } } -- 提高到 20~30 可减少重复解析
```

## 四、诊断输出与窗口

- 诊断列表开关/策略：`diagnostics.quickfix.{enabled,open,jump}`
- 输出面板高度：`cmake.output.height`；若受限可调小
- 仅终端视图：`cmake.view = 'terminal'`（减少 quickfix 解析与渲染）

```lua
      terminal = {
        -- 运行时是否自动打开内置终端窗口
        open = true,
        -- 终端窗口高度
        height = 12,
      }
```

## 五、终端选择与发送策略

- `make.telescope.choose_terminal` / `cmake.telescope.choose_terminal`
  - `auto`：存在已开终端时弹选择器
  - `never`：直接按默认策略（BetterTerm 优先）
- BetterTerm 的 `send_delay` 与 `focus_on_run` 也会影响交互体验

```lua
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
      }
```

## 六、Windows 与 Shell

- PowerShell 在长输出下可能略慢，可按需更换到 `cmd` 或使用内置终端默认行为
- MSVC `cl` 编译需在 VS 环境初始化终端内启动 Neovim，避免环境探测开销

## 七、调优模板（推荐起点）

```lua
require('quick-c').setup({
  make = {
    concurrency = 8,
    telescope = { preview = true, max_preview_bytes = 200*1024, max_preview_lines = 2000 },
    cache = { ttl = 15 },
  },
  cmake = {
    concurrency = 8,
    view = 'both',
    output = { open = true, height = 12 },
    telescope = { max_preview_bytes = 200*1024, max_preview_lines = 2000 },
  },
  debug = { concurrency = 8 },
})
```

## 八、故障排查

- 并发过大 → CPU/Disk 飙升、目录扫描卡顿：下调 `make/cmake.concurrency`
- Telescope 预览卡顿：降低 `max_preview_*`，或 `preview=false`
- 诊断列表频繁弹出影响流畅：将 `open/jump` 调为 `error` 或 `never`


