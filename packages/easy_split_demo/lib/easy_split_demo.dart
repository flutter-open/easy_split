/// 两个 example 入口共用的演示页面与接入配置。
///
/// - [TabsHomePage] / [DemoViewport] / [ForceModeButton]：折叠 ⇄ 展开的状态保留与
///   窗格宽度演示（`src/demos.dart`）；
/// - 广告页、首页、详情页、弹窗大全等演示页面（`src/pages.dart`）；
/// - [installPaneScreenUtil] / [demoRoutes] / [kDemoHomeRoutes]：ScreenUtil 接入、
///   共用路由表与全屏名单（`src/setup.dart`）。
///
/// 两个入口（`example/lib/main.dart`、`example/lib/main_1.dart`）只保留各自的
/// 接入方式（`onGenerateRoute` / `MaterialApp.router`），页面与配置都从这里取，
/// 后续修问题改一处，两个 demo 同步生效。
library;

export 'src/demos.dart';
export 'src/pages.dart';
export 'src/setup.dart';
