# Changelog

## 0.1.0

首个公开版本。

### 功能

- `EasySplitGoRoute`：`GoRoute` 的分栏版本，宽屏时页面进入右栏、窄屏时全屏，页面代码零改动
- 重复路由去重（默认开启）：栈内已有同一页面时再次 `context.push(...)`，自动收敛路由栈到已有页面并置顶，保留原页面状态；支持单条路由 `dedupe: false`、全局 `EasySplit.config.dedupeRepeatedRoutes = false`、自定义 `sameRoute` 匹配规则
- `fullscreen` 参数：指定某条路由永远全屏（如登录页、设置页）
- `redirect` / `onExit` / `caseSensitive` 透传：分栏页面同样支持路由级登录拦截与离开确认
- 公开去重判断：`easySplitDuplicateIndexOf(configuration, settings)` / `easySplitIsDuplicate(...)`，
  便于在 go_router 16.3+ 的 `onEnter` 里于入栈前拦截重复页面（示例见 `example/lib/main_on_enter.dart`）
- 示例接入 `GoRouter(redirect:)` + `refreshListenable` 的登录拦截（未登录改道 `/login?from=...`，登录后回到原目标）
- 复用 `easy_split` 的配置与分栏能力（`EasySplitScope`、`EasySplit.config.fullscreenRoutes`、`paneRatio` 等）
- `easySplitDedupeAction(router, settings)`：配合 go_router 16.3+ 的 `Allow(then: ...)` 实现
  「已有页面置顶」；配套 `easySplitDuplicateIndexOf` / `easySplitIsDuplicate`。
- 兼容 go_router 13 及以上（`>=13.0.0`，不设上限；测试已在 16.3.0 / 18.1.4 上跑通）

### 已知限制

- `ShellRoute` / `StatefulShellRoute` 子页面不参与去重
- 只处理「push 新页」场景，`go` / `replace` 保持 GoRouter 原生语义
