# easy_split_getx

[English](https://github.com/flutter-open/easy_split/blob/main/packages/easy_split_getx/README.md) | [简体中文](https://github.com/flutter-open/easy_split/blob/main/packages/easy_split_getx/README_CN.md)

[EasySplit](https://pub.dev/packages/easy_split) 的 GetX 适配包：在保留 GetX
**bindings / middleware / 转场 / 路由上报**的前提下，实现「宽屏左右分栏、窄屏全屏单页」。

- 需要进右栏的页面，把 `GetPage` 换成 `EasySplitGetPage` 即可。
- 支持两种接入：经典命名路由（`GetMaterialApp` + `onGenerateRoute`）和 Navigator 2.0
  （`GetMaterialApp.router` + `getPages`）。
- 页面代码不变，继续使用 `Get.toNamed`、`Get.offNamed`、`Get.parameters`、`Get.back`、
  `Get.dialog` 等。
- 要求 Flutter 3.27+、GetX 4.6.5+。

## 为什么需要适配包

GetX 没有提供替换所创建 `Route` 的入口：

- 经典模式的 `Get.toNamed` / `Get.offNamed` 最终走 `Navigator.pushNamed`，会到达
  `GetMaterialApp.onGenerateRoute`。EasySplit 自带的 `EasySplit.routeAdapter` 虽然能返回分栏
  路由，但它返回的是普通 `EasySplitRoute`，会丢掉 GetX 的 `PageRouteReportMixin`、
  middleware、bindings 和转场，`Get.currentRoute` 也会失效。
- `Get.to(() => page)` 直接创建 `GetPageRoute` 并入栈，完全绕过 `onGenerateRoute`。
- Navigator 2.0 通过 `GetPage.createRoute` 创建路由，同样硬编码了 `GetPageRoute`。

因此本包提供 `GetPageRoute` 的子类 `EasySplitGetPageRoute`：复用 GetX 的内容构建和转场管线，
只覆盖分栏所需的五个点（`opaque`、遮罩、委托转场、内容包装、转场包装）。

## 安装

```yaml
dependencies:
  easy_split: ^0.2.1
  easy_split_getx: ^0.1.0
  get: ">=4.6.5 <5.0.0"
```

## 经典命名路由

```dart
import 'package:easy_split/easy_split.dart';
import 'package:easy_split_getx/easy_split_getx.dart';
import 'package:get/get.dart';

final List<GetPage> pages = [
  GetPage(name: '/', page: () => const AdPage()),
  GetPage(
    name: '/home',
    page: () => const EasySplitScope(child: HomePage()), // 左栏
  ),
  EasySplitGetPage(
    name: '/detail/:index',
    page: () => const DetailPage(),
    binding: DetailBinding(),
  ),
  EasySplitGetPage(name: '/secondary', page: () => const SecondaryPage()),
];

void main() {
  runApp(
    GetMaterialApp(
      initialRoute: '/',
      onGenerateRoute: easySplitGetRouteAdapter(pages: pages),
      // 可选：整栈重复路由收敛（与 EasySplit.routeAdapter 一致）。
      navigatorObservers: [EasySplit.dedupeObserver],
    ),
  );
}
```

> 该模式**不要传 `getPages`**。一旦 `getPages != null`，GetX 会用内部 generator 覆盖
> `onGenerateRoute`，适配器不会被调用。未知路由用 `unknownRoute:` 或适配器的
> `unknownRoute` 参数指定。

导航代码保持不变：

```dart
Get.toNamed('/detail/1');
Get.parameters['index'];
Get.back();
```

## Navigator 2.0（`GetMaterialApp.router`）

```dart
GetMaterialApp.router(
  getPages: [
    GetPage(name: '/', page: () => const AdPage()),
    GetPage(name: '/home', page: () => const EasySplitScope(child: HomePage())),
    EasySplitGetPage(name: '/detail/:index', page: () => const DetailPage()),
  ],
  unknownRoute: GetPage(name: '/not-found', page: () => const NotFoundPage()),
);
```

该模式下 Navigator 由 `pages` 驱动，导航必须走 delegate：

```dart
Get.rootDelegate.toNamed('/detail/1');
Get.rootDelegate.offNamed('/home');
Get.rootDelegate.popRoute();
```

`Get.toNamed` 走的是 `Navigator.pushNamed`，与 `pages` 驱动的 Navigator 不兼容，不要混用。

`EasySplitGetPage` 必须 override `copy`：GetX 路由树在匹配 location 时会调用 `copy`，
而基类 `GetPage.copy` 返回普通 `GetPage`，会丢子类。

## 左栏、全屏页与配置

普通 `GetPage` 始终保留原生全屏路由，这正是分栏宿主页（通常是 `/home`）需要的，
因为左右窗格由 `EasySplitScope` 自己创建：

```dart
GetPage(name: '/home', page: () => const EasySplitScope(child: HomePage()));
```

只有 `EasySplitGetPage` 会被转换成分栏路由，所以初始广告/splash 页和 `/home` 都不需要额外
的全屏配置。需要任何宽度都全屏的分栏页，两种方式任选：

```dart
// 单页声明。
EasySplitGetPage(name: '/login', page: () => const LoginPage(), fullscreen: true);

// 或全局配置（对 EasySplitGetPage 生效）。
EasySplit.config.fullscreenRoutes.add('/login');
```

其余配置（`breakpoint`、`paneRatio`、`paneDecoration`、`layoutDelegate`、
`placeholderBuilder` 等）仍是 EasySplit 核心配置：

```dart
EasySplit.config
  ..breakpoint = 600
  ..paneRatio = 0.5
  ..enabled.value = true;
EasySplit.updateLayout(); // 几何配置变更后调用
```

## 保留的 GetX 能力

- `Bindings` / `Get.put` / `Get.lazyPut`：`EasySplitGetPageRoute` 继承 `GetPageRoute`，
  `buildContent` 仍走 GetX 的 `_getChild()` 管线（bindings、`onPageBuildStart` 等）。
- `GetMiddleware`：经典模式走 `PageRedirect.page()`（与 GetX 一致），Navigator 2.0 走
  `GetDelegate`；`redirect` / `onPageCalled` / `onBindingsStart` 正常执行。
- 转场：`GetPageRouteTransitionMixin` 照常构建转场，分栏包装套在转场外层，因此 iOS
  侧滑热区被收进右栏，而不是落在屏幕左边缘。
- `Get.currentRoute` 与 `RouterReportManager`：继承 `PageRouteReportMixin`，路由上报、
  依赖路由的逻辑都保留。
- `Get.dialog`、`Get.bottomSheet`、`Get.snackbar`：不受影响，浮层仍覆盖整窗。

## 重复路由

- 经典模式：加 `navigatorObservers: [EasySplit.dedupeObserver]`（与
  `EasySplit.routeAdapter` 使用的是同一个观察者）。它尊重
  `EasySplit.config.dedupeRepeatedRoutes` / `sameRoute`，会收敛中间重复页。
- Navigator 2.0：GetX 自带的 `preventDuplicates` 只检查栈顶当前页，暂未提供整栈收敛。

## 已知限制

- `Get.to(() => widget)` 直接创建普通 `GetPageRoute`，无法拦截，始终全屏。需要分栏的页面请用
  命名路由（`EasySplitGetPage`）。
- `Get.offAllNamed`、`Get.until`、`Get.offUntil` 保持 GetX 原生语义。
- Shell / 嵌套 Navigator 未做特殊处理，只适配根 Navigator 上的路由。
- 右栏内容依赖 easy_split 0.2.1 新增的公开 `EasySplitPaneFrame` / `EasySplitPaneTeleport` /
  `EasySplitPaneHitTest`。

## 示例与测试

```bash
cd example
flutter run                          # 经典命名路由
flutter run -t lib/main_router.dart  # Navigator 2.0
flutter test
```

- `example/lib/main.dart`：`GetMaterialApp` + `onGenerateRoute` 适配器。
- `example/lib/main_router.dart`：`GetMaterialApp.router` + `getPages`。
- `example/lib/pages.dart`：共用示例页（左栏首页、带 `Binding` 的详情页、弹窗页、全屏页）。
- `test/easy_split_getx_test.dart`：路由构造、全屏、`copy`、适配器行为。
- `example/test/navigation_test.dart`：两种模式、左栏状态保留、全屏行为。
