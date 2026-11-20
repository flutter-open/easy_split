# EasySplit · 折叠屏/宽屏快速分栏适配引擎

仿鸿蒙"平行视界"的 Flutter 实现：**一个路由栈，折叠（窄屏）= 正常全屏路由模式，展开（宽屏）= 自动左右分栏**，切换纯表现层、栈完全不动。

纯适配器设计：**不继承任何 App、不替换任何方法**，与 MaterialApp / CupertinoApp / GoRouter(routerConfig) / Navigator.pages 自由组合。

## 接入三件套

### 1. 列表页（栈底）包 `EasySplitScope` —— 你自己决定谁是左栏

```dart
MaterialApp(
  home: EasySplitScope(child: RootPage()),
)
```

### 2. 路由接入（按你的路由方案二选一，都是一行）

```dart
// 方案一：MaterialApp / CupertinoApp · onGenerateRoute 拦截器
MaterialApp(
  home: EasySplitScope(child: RootPage()),
  onGenerateRoute: EasySplit.routeAdapter({
    '/detail': (_) => DetailPage(),
  }),
)

// 方案二：GoRouter · routerConfig 一行接入
MaterialApp.router(
  routerConfig: createEasySplitGoRouter(
    home: RootPage(),                    // 自动包 EasySplitScope 作为左栏
    routes: {'/detail': (_) => DetailPage()},
  ),
)
```

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
lib/easy_split.dart            EasySplitConfig（配置一层包装）+ 核心 API
lib/src/easy_split_pane_route.dart  EasySplitRoute / EasySplitPage
lib/src/easy_split_scope.dart       EasySplitScope 分栏容器
example/                       三种路由方案 demo（独立入口，按需运行）
  └─ lib/main.dart             方案一：MaterialApp · onGenerateRoute 拦截器
  └─ lib/main_go_route.dart    方案三：GoRouter · routerConfig + EasySplitPage
  └─ lib/demo_pages.dart       各入口共享的配置与页面
  └─ test/                     14 个行为测试
```

## 运行 Demo（-t 切换入口，方便对比复用）

```bash
cd example
flutter run -t lib/main.dart          # 方案一：onGenerateRoute 拦截器
flutter run -t lib/main_go_route.dart # 方案二：GoRouter routerConfig
```

右上角开关可随时关闭适配；旋转模拟器（Cmd+方向键）验证折叠/展开切换。

## 设计要点

- 路由栈只有一个 = 原生 Navigator；`EasySplitRoute` 仅 4 点不同（opaque=false、无 barrier、delegatedTransition 透传、内容自适应），返回手势/系统返回/转场动画全部原生
- 折叠/展开切换：路由栈不动，`EasySplitRoute` 内容在"右栏区域 ↔ 全屏"间自适应
- 安全区方向感知：竖屏避上下、横屏避左右，旋转随 MediaQuery 自动更新
- 铰链避让：`paneWidth` 计算扣除 `displayFeatures` 中的 hinge 区域

## 运行 Demo

```bash
cd example && flutter run -d macos   # 或 iOS 模拟器，拖窗口宽度验证
```

顶部下拉可切换三种路由方案对比；右上角开关可随时关闭适配。
