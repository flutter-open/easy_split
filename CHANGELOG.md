# Changelog

## 0.1.0

首个公开版本。

### 功能

- 平行视界分栏：一个路由栈，窄屏全屏、宽屏自动左右分栏，折叠/展开切换时路由栈不动
- 路由接入方式：
  - `EasySplit.routeAdapter({...})`：`MaterialApp` / `CupertinoApp` 的 `onGenerateRoute`
  - `easySplitNativeRouterConfig(home:, pageBuilders:)`：`MaterialApp.router`（内置 `Navigator.pushNamed/pop` 支持、深链同步、`observers` / `onUnknownRoute` 透传）
  - `EasySplitPage(child:, name:)`：`Navigator.pages` 等基于 `Page` 的路由体系
  - `EasySplitRoute(builder:)`：手动构造分栏路由
- 重复路由去重（默认开启）：栈内已有同一页面时再次 `pushNamed` 不再重复压栈，而是置顶已有实例；支持 `EasySplit.config.dedupeRepeatedRoutes` / `sameRoute` 自定义；`onGenerateRoute` 方案通过 `EasySplit.dedupeObserver` 一行接入
- 布局即时更新：改完 `paneRatio` / `breakpoint` / `layoutDelegate` / `layoutBuilder` 后调用一次 `EasySplit.updateLayout()`，已显示的分栏立即重排（路由栈不动）；demo 卡片新增「分栏设置」，可实时切换左右分栏 / 内容在左 / 上下分栏 / 悬浮内容栏四种布局并调整比例（演示 `layoutDelegate` 自定义布局）
- 手势穿透：`opaque=false` + 零尺寸 barrier + 转场子树缩进 `paneRect` + `hitTest` 裁剪，左栏点击/滚动不被右栏路由劫持，iOS 侧滑热区锚定右栏左缘
- 参数透传：`EasySplitRoute` / `EasySplitPage` 的 `maintainState`、`fullscreenDialog`、`allowSnapshotting`、`requestFocus`、`settings`；`EasySplitScope.placeholderBuilder`；`fullscreen` 强制全屏
- 配置：`EasySplit.config`（`paneRatio`、`breakpoint`、`fullscreenRoutes`、`placeholderBuilder`、`layoutDelegate`、`layoutBuilder`、`paneDecoration`、`isWideOverride`、`enabled` 动态开关）
- 铰链/安全区：`paneWidth` 扣除 `displayFeatures` 铰链区域，竖屏避上下、横屏避左右

### 已知限制

- 去重只拦截 `Navigator.pushNamed`；`pushReplacementNamed`、`pushNamedAndRemoveUntil`、`push` 保持原生语义
- 分栏路由为非 opaque 路由，被覆盖的页面仍在 widget 树中（与原生 `PageRoute` 语义一致，测试断言时需注意）
