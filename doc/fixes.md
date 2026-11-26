# 问题说明与修复记录 / Issue notes and fixes

本文件记录 easy_split 已修复的两个问题的症状、根因、修复方式、API 变化与回归用例。
[`CHANGELOG.md`](../CHANGELOG.md) 只记录**已发布版本**的信息（0.2.0）；本文件是其详细说明。用法见 [`README.md`](../README.md) /
[`README_CN.md`](../README_CN.md)。

---

## 1. 折叠 / 展开后，tabbar 首页被重置

### 症状

底部 tabbar 形式的首页（栈底页，自带 `EasySplitScope`）在窗口变宽、展开成左右分栏后，页面的
State 回到初始值：当前 tab 回到第 0 个，滚动位置回到顶部，`TextEditingController` 的文本、
计数等全部丢失。窗格里的二级页（详情页等）重新折叠 / 展开时同样会重置。

### 根因

窄屏和宽屏两条分支返回的 **widget 树结构不同**：

| 位置 | 折叠（窄屏） | 展开（宽屏） |
| --- | --- | --- |
| `EasySplitScope.build` | 直接 `return child` | `Stack` + `Positioned` |
| `_PaneFrame.build` | 直接 `return child` | `Padding` > `SizedBox` |
| `_PaneTeleport.build` | 直接 `return child` | `DecoratedBox` > `MediaQuery` > `Padding` > `Material` |

Flutter 的 Element 复用按「位置 + 类型 + key」匹配，父级类型一变就整棵子树卸载重建，页面 State
自然被销毁。所以问题不在状态管理，而在**结构切换**。

### 修复

三处都改成"结构恒定、只改参数"：

- `EasySplitScope`：窄屏 / 宽屏都返回 `Stack`，第 0 个孩子恒为 `Positioned`（窄屏
  `Positioned.fill`，宽屏 `Positioned.fromRect(leftRect)`），首页恒包一层 `MediaQuery`；
- `_PaneFrame`：始终 `Padding` > `SizedBox`，窄屏传入整窗矩形；
- `_PaneTeleport`：始终 `DecoratedBox` > `MediaQuery` > `Padding` > `Material`，窄屏用零
  insets 与空 decoration。

自定义布局（`EasySplit.config.layoutBuilder`）无法保证结构一致，改用稳定的 `GlobalKey` 直接
包住用户的 `home`（`KeyedSubtree(key: _homeKey, child: child)`），key 必须在 `Material` 外层
之下直接贴着用户 widget，否则上层的类型变化仍会重建其下的 State。

### 回归用例

- `test/layout_state_test.dart`（5 例）：Scope 首页 Tab 状态、分栏路由首页、右栏详情页计数、
  首页滚动位置、自定义 layoutBuilder 的窄 ⇄ 宽切换；
- `packages/easy_split_demo` 的 `TabsHomePage`（`lib/src/demos.dart`）+ `example/test/demo_pages_test.dart`：真机 / 模拟器上
  手动验收同一场景。

---

## 2. 按"整体宽度"适配的布局在分栏后被放大

### 症状

页面按屏幕宽度写百分比、栅格列数、间距系数，或使用 ScreenUtil（`.w` / `.sp`）时，展开成分栏后
元素按**整窗**宽度计算，在窗格里被放大，甚至溢出窗格边界。

### 根因

窗格内页面拿到的 `MediaQuery` 仍是整窗数据（只调整了 `padding`），`MediaQuery.sizeOf(context)`
返回整窗尺寸；ScreenUtil 更是直接读原始 `FlutterView`（`ScreenUtil.init` /
`ScreenUtilInit` 走 `View.maybeOf(context)` + `MediaQueryData.fromView`），完全绕过了
`MediaQuery`。

### 修复

- 左右窗格分别注入**窗格自己的 `MediaQuery`**：`MediaQuery.sizeOf` 为窗格尺寸、orientation
  跟随窗格、`padding` / `viewPadding` 已扣除窗格避让掉的安全区；
- 分屏判定用的几何（`EasySplit.isWide` / `layoutOf` / `paneWidth` / `paneContentInsets`）通过
  内部 `EasySplitWindowMetrics` 继续读整窗，断点不会被窗格尺寸带偏；
- 新增 `EasySplit.config.onPaneMediaQuery` 回调，把窗格 `MediaQuery` 转发给读原始 `FlutterView`
  的方案（ScreenUtil 一行接入）；
- 新增 `EasySplit.paneMediaQuery(parent, paneRect, {insets})`，自定义布局可自行换算；
- 对话框 / 底部弹层在 overlay 里，保持整窗尺寸。

业务页面**不需要改任何代码**。

### ScreenUtil 接入

```dart
void main() {
  EasySplit.config.onPaneMediaQuery = (data) => ScreenUtil.configure(
        data: data,
        designSize: const Size(375, 812),
        splitScreenMode: false, // late 字段，第一次 configure 必须显式传
        minTextAdapt: false,
      );
  runApp(const App());
}
```

注意：回调在窗格 build 期间同步触发，不要在里面 `setState`；ScreenUtil 是全局单例，左右窗格
同时可见时后构建的一栏生效；调整缩放配置后调用 `EasySplit.updateLayout()` 重新上报。

### 回归用例

`test/pane_media_query_test.dart`（7 例）：左右窗格尺寸、断点判定不受窗格影响、右栏路由内容
尺寸、窄屏整窗、自定义 layoutBuilder、`onPaneMediaQuery` 上报、`paneMediaQuery` 的 insets 扣除。

---

## 3. 参数内容相同的重复路由没有去重

### 症状

同一个页面反复跳转（典型：左侧列表重复点击同一个 H5 条目、webview 路由），路由栈会越压越深，
返回要按很多次。`dedupeRepeatedRoutes` 默认开启，但看起来"没生效"。

### 根因

默认 `sameRoute` 用 `a.arguments == b.arguments` 判等（3 处：`EasySplitDedupeObserver`、
`EasySplitRouterDelegate`、`easy_split_go_router` 的 `_sameSettings`）。Dart 的 `Map` / `List`
没有重写 `==`，比较的是引用；而每次跳转都会新构造一个内容相同的 `Map`
（如 `{'url': ..., 'headerMap': {'token': ...}}`、go_router 的 `extra`），`==` 永远为 false，
去重永远不命中。`String` / `num` 参数因为 `==` 是值比较，所以原有测试没暴露问题。

### 修复

新增共享判等 `lib/src/route_equality.dart`：

- `easySplitSameRoute(RouteSettings a, RouteSettings b)`：`name` 相同 + `arguments` 结构相等，
  替换三处重复的私有默认实现（DRY，三个入口行为一致）；
- `easySplitArgumentsEqual(Object? a, Object? b)`：`Map` / `List` 递归按内容比较，其余类型用 `==`；
- 预算：最多 12 层、256 个节点，超出即返回 `false`（fail-closed：宁可多压一页，也不误去重）；
  自引用结构会在预算内提前截断，不会栈溢出；`identical` 快速路径不受预算影响。

### 行为变化

- 内容相同但实例不同的 `Map` / `List` 参数现在会被视为同一页面。以前能重复压栈的场景
  （例如故意用相同参数打开两个独立实例）会被收敛，可用 `EasySplit.config.sameRoute`
  自定义规则恢复，或 `dedupeRepeatedRoutes = false` 整体关闭。
- 参数极深（>12 层）、元素极多（>256 个节点）或自引用的路由不会去重，但也不会报错 / 崩溃。

### 回归用例

- `test/route_equality_test.dart`（19 例）：name 判等、Map/List 内容与键顺序、嵌套差异、
  自定义 `==` 类型、自引用、12 层 / 13 层边界、255 / 256 节点预算边界；
- `test/dedupe_observer_test.dart`：Map 参数相同去重、深层值不同照常压栈；
- `test/router_delegate_test.dart`：Map 参数键顺序不同仍去重、深层值不同照常压栈；
- `packages/easy_split_go_router/test/go_route_dedupe_test.dart`：`extra` 为内容相同的 Map 时只保留一页。

---

## API 变化清单

### 新增

- `EasySplit.paneMediaQuery(MediaQueryData parent, Rect paneRect, {EdgeInsets insets = EdgeInsets.zero})`
  —— 按窗格矩形生成窗格 `MediaQueryData`（`size` = 窗格尺寸减 insets，`padding` / `viewPadding`
  同步扣除 insets，其余字段沿用 parent）。自定义布局 / 自己换算尺寸时用。
- `EasySplitConfig.onPaneMediaQuery`（`void Function(MediaQueryData data)?`）——
  窗格 `MediaQuery` 每次生效时回调，用来把面板尺寸转发给读原始 `FlutterView` 的方案（ScreenUtil）。
  不要在回调里 `setState`；调整缩放配置后调 `EasySplit.updateLayout()` 让可见窗格重新上报。

### 行为变化

- 左右窗格内 `MediaQuery.sizeOf(context)` / `MediaQuery.of(context).size` = 窗格尺寸；
  `MediaQuery.orientationOf(context)` 跟随窗格；`padding` / `viewPadding` 已扣除窗格避让的安全区。
- `EasySplit.isWide` / `layoutOf` / `paneWidth` / `paneContentInsets` **仍按整窗**几何计算
  （通过内部 `EasySplitWindowMetrics` 读取整窗数据），断点不会被窗格尺寸带偏。
- 从窗格里打开的对话框 / 底部弹层仍在 overlay 里，尺寸按整窗。
- `EasySplitScope` / `_PaneFrame` / `_PaneTeleport` 的 widget 结构在窄屏 / 宽屏之间恒定，
  只改布局参数；自定义 `layoutBuilder` 用稳定 `GlobalKey` 保留首页 State。

### 新增文件与回归用例

- `lib/src/easy_split_window.dart`（内部实现：整窗几何 + 窗格 `MediaQuery` 注入）；
- `test/layout_state_test.dart`（5 例）：Scope 首页 Tab 状态、分栏路由首页、右栏详情页计数、
  首页滚动位置、自定义 `layoutBuilder` 的窄 ⇄ 宽切换；
- `test/pane_media_query_test.dart`（7 例）：左右窗格尺寸、断点判定不受窗格影响、右栏路由内容
  尺寸、窄屏整窗、自定义 `layoutBuilder`、`onPaneMediaQuery` 上报、`paneMediaQuery` 的 insets 扣除；
- README 新增「窗格内的"屏幕"就是窗格本身 / Inside a pane, "the screen" is the pane」一节。

---

## 升级说明 / Upgrade notes

> 本节对应 **0.2.0**（已发布版本）；`CHANGELOG.md` 的 `## 0.2.0` 条目是同一份升级信息的简版。

- 破坏性变更：**无**。页面代码不需要改动。
- 使用 ScreenUtil 的项目：在 `main()` 里加 `onPaneMediaQuery` 一行（见上），否则 `.w` / `.sp`
  仍按整窗换算。
- 依赖窗格内 `MediaQuery.sizeOf` 等于整窗尺寸的特殊场景（例如自己按整窗排版的面板），可用自己的
  `MediaQuery` 覆盖窗格注入的数据。

---

# Issues (English summary)

1. **Folding / unfolding reset tabbed home pages.** The narrow and wide branches returned different
   widget structures, so Flutter unmounted and rebuilt the whole subtree and page `State` was lost.
   Fixed by keeping the structure identical in both modes and only changing layout parameters
   (plus a stable `GlobalKey` for custom `layoutBuilder`s). Regression tests:
   `test/layout_state_test.dart`.
2. **Width-based layouts were blown up inside panes.** Pages kept receiving the window
   `MediaQuery`, and ScreenUtil bypasses `MediaQuery` entirely by reading the raw `FlutterView`.
   Fixed with a pane-scoped `MediaQuery`, window-based geometry kept for the split decision
   (`EasySplit.isWide` / `layoutOf` / `paneWidth` / `paneContentInsets`), the
   `EasySplit.config.onPaneMediaQuery` callback and `EasySplit.paneMediaQuery`. Regression tests:
   `test/pane_media_query_test.dart`.
3. **Duplicate routes with equal arguments were not deduplicated.** The default `sameRoute`
   compared `arguments` with `==`, i.e. by reference, while `Map` / `List` arguments are rebuilt on
   every navigation. The default now compares arguments structurally (budgeted to 12 levels /
   256 nodes, failing closed on oversized or self-referencing values) and is shared by the
   observer, the router delegate and `easy_split_go_router`. Regression tests:
   `test/route_equality_test.dart`, plus Map-argument cases in the dedupe observer / delegate /
   go_router test files.
