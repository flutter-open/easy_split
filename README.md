# EasySplit · 折叠屏/宽屏快速分栏适配引擎

仿鸿蒙"平行视界"的 Flutter 实现：**一个路由栈，折叠（窄屏）= 正常全屏路由模式，展开（宽屏）= 自动左右分栏**，切换纯表现层、栈完全不动。

纯适配器设计：**不继承任何 App、不替换任何方法**，与 MaterialApp（含 `.router`）/ CupertinoApp / GoRouter(routerConfig) / Navigator.pages 自由组合。

## 接入三件套

### 1. 列表页（栈底）包 `EasySplitScope` —— 你自己决定谁是左栏

```dart
MaterialApp(
  home: EasySplitScope(child: RootPage()),
)
```

### 2. 路由接入（按你的路由方案三选一，页面代码零改动）

```dart
// 方案一：MaterialApp / CupertinoApp · onGenerateRoute
MaterialApp(
  home: const AdPage(),                                   // 启动首屏（全屏）
  onGenerateRoute: EasySplit.routeAdapter({
    '/home': (_) => EasySplitScope(child: HomePage()),    // 首页自己决定谁是左栏
    '/detail': (_) => DetailPage(),
  }),
)

// 方案二：MaterialApp.router · RouterDelegate（不依赖 go_router）
// 页面里照旧 Navigator.pushNamed / pop / pushReplacementNamed，arguments 也从 ModalRoute 取
final routerConfig = easySplitNativeRouterConfig(
  home: const AdPage(),                                   // 全屏首屏，不自动包 Scope
  pageBuilders: {
    '/home': (_) => EasySplitScope(child: HomePage()),    // 首页自己决定谁是左栏
    '/detail': (_) => DetailPage(),
  },
);
MaterialApp.router(routerConfig: routerConfig)

// 方案三：GoRouter · 把普通 GoRoute 换成 EasySplitGoRoute 即可
// 见 packages/easy_split_go_router
```

> 方案二的 `routerConfig` 只创建一次（顶层 final / State 字段）：若放进 `build()`，每次重建都会换掉 delegate 与 Navigator，路由栈随之丢失。

### 3. 配置：`EasySplit.config`（一层包装）

```dart
EasySplit.config
  ..paneRatio = 0.45            // 左右占比
  ..fullscreenRoutes.addAll({'/login'})  // 永远全屏的沉浸页
  ..fullscreenRoutes.addAll({'/home'})   // 首页非启动首路由时（闪屏→replace→首页）：首页加入名单，内部自行分栏
  ..placeholderBuilder = (ctx) => EmptyView()  // 右侧空态
  ..breakpoint = 600            // 宽窄断点
  ..layoutDelegate = (ctx) => ...  // 自定义分栏布局（左右矩形）
  ..paneDecoration = ...        // 右栏面板装饰
  ..isWideOverride = (ctx) => ...  // 自定义"展开"判定（如真机铰链）
```

便捷存取：`EasySplit.enabled`（动态开关）、`EasySplit.paneRatio` 等。

## 目录结构

```
lib/easy_split.dart                  EasySplitConfig（配置一层包装）+ 核心 API
lib/src/easy_split_pane_route.dart  EasySplitRoute / EasySplitPage
lib/src/easy_split_scope.dart       EasySplitScope 分栏容器
lib/src/easy_split_router_delegate.dart  EasySplitRouterDelegate（MaterialApp.router 接入）
test/                                15 个行为测试（分栏手势、路由接入两条线）
example/                             三种路由方案 demo（独立入口，按需运行）
  └─ lib/main.dart                   方案一：MaterialApp · onGenerateRoute 拦截器
  └─ lib/main_1.dart                 方案二：MaterialApp.router · RouterDelegate
  └─ lib/pages.dart                  各入口共享的页面
packages/easy_split_go_router/       方案三：GoRouter · 把 GoRoute 换成 EasySplitGoRoute
  └─ example/lib/main.dart           方案三 demo
```

## 手势穿透原理（PageRoute 在分栏里怎么不添乱）

分栏的二级页是一条 `opaque=false` 的真实 `PageRoute`，它天然会想「占满全屏」并接管全身手势。
EasySplit 用三层把它关进右栏：

1. **视觉层**：`opaque=false` + `buildModalBarrier()` 返回零尺寸盒子 → 下层首页继续绘制、没有全屏遮罩。
2. **布局层（关键）**：在 `buildTransitions` 里先把主题/平台的原生转场产出来，再整体套一层
   `Padding + SizedBox`，把**整棵转场子树缩进 `paneRect`**。
   `buildTransitions` 的产物在 Overlay 里拿到的始终是「全屏」约束，而框架会在这一层插入自己的
   手势探测器——最典型的是 `CupertinoPageTransitionsBuilder` 的 iOS 侧滑返回热区
   （`Stack[child, PositionedDirectional(start: 0, width: 20, child: Listener(...))]`，贴着路由盒子的左边）。
   路由盒子若是全屏，热区就落在屏幕最左 = 左栏里，表现为：
   - 从**屏幕左缘**右滑 → 把右栏详情 pop 掉（左栏手势被路由劫持）
   - 从**右栏左缘**右滑 → 毫无反应（用户直觉的位置反而失效）

   把整条路由缩进 pane 后：热区跟着落到右栏左缘，转场动画也只在右栏内播放，
   Cupertino 的拖拽进度按 pane 宽度换算（手势与动画 1:1 跟手）。
   `buildContent` 里做 hitTest 裁剪是**管不到这一层**的，所以位置必须在这里定。
3. **命中兜底**：`_PaneHitTestScope`（`RenderProxyBox.hitTest`）把局部坐标 `localToGlobal` 换算后
   与 `paneRect` 比对，右栏之外直接返回 `false` → 指针继续向下层路由传递。
   即使业务页面内部有 `OverflowBox` 之类越界绘制的节点，也不会挡住左栏。

窄屏/竖屏（非分栏态）直接透传原生路由，行为与 `MaterialPageRoute` 完全一致。

回归测试：`test/pane_route_gesture_test.dart`（左栏点击/滚动穿透、右栏内容盒恰好落在 paneRect、
iOS 侧滑锚定右栏左缘且不误触左栏、窄屏全屏、转场中左栏可交互、pop/push 往返）；
`test/router_delegate_test.dart`（MaterialApp.router 宽/窄屏导航、pushNamed/pop/pushReplacementNamed/
pushNamedAndRemoveUntil、delegate.push/pop、深链同步）。

## 运行 Demo（-t 切换入口，方便对比复用）

```bash
cd example
flutter run -t lib/main.dart          # 方案一：onGenerateRoute 拦截器
flutter run -t lib/main_1.dart        # 方案二：MaterialApp.router · RouterDelegate

cd packages/easy_split_go_router/example
flutter run                           # 方案三：GoRouter · EasySplitGoRoute
```

右上角开关可随时关闭适配；下拉可切换布局模式（自动 / 自定义 / 关闭分栏）；旋转模拟器（Cmd+方向键）验证折叠/展开切换。

## 设计要点

- 路由栈只有一个 = 原生 Navigator；`EasySplitRoute` 仅 5 点不同（opaque=false、无 barrier、delegatedTransition 透传、整条路由缩进右栏、内容自适应），返回手势/系统返回/转场动画全部原生
- 手势与命中边界：见上方「手势穿透原理」——指针与路由自带手势层都由**布局**隔离在右栏内，`hitTest` 裁剪只作兜底
- 折叠/展开切换：路由栈不动，`EasySplitRoute` 内容在"右栏区域 ↔ 全屏"间自适应
- 安全区方向感知：竖屏避上下、横屏避左右，旋转随 MediaQuery 自动更新
- 铰链避让：`paneWidth` 计算扣除 `displayFeatures` 中的 hinge 区域

## 运行 Demo

```bash
cd example && flutter run -d macos   # 或 iOS 模拟器，拖窗口宽度验证
```

右上角开关可随时关闭适配；下拉可切换布局模式（自动 / 自定义 / 关闭分栏）。
