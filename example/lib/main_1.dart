import 'package:easy_split/easy_split.dart';
import 'package:easy_split_demo/easy_split_demo.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// ============================================================================
/// 方案二：MaterialApp.router（RouterDelegate，不依赖 go_router）
///
/// 页面代码零改动：页面里依然是 `Navigator.pushNamed / pop /
/// pushReplacementNamed`，arguments 照旧从 `ModalRoute.of(context)` 取。
/// 接线只有两步：
/// 1. 首页不是启动首路由（广告页 → replace 首页），把首页路由加入全屏名单，
///    它内部自包 EasySplitScope 自行分栏；'/login' 也全屏（登录页不分栏）。
/// 2. routerConfig 只创建一次（放顶层 final / State 字段）。
///
/// 额外收益：重复路由去重（重复点同一页面时置顶）已内置，无需额外接入。
///
/// 演示页面与路由表都在 `package:easy_split_demo` 里，与方案一共用；
/// 本文件只保留"这一种接入方式"相关的配置。
/// ============================================================================
void main() {
  // ScreenUtil 适配（关键一行）：把面板实际生效的 MediaQuery 交给全局单例，
  // 页面里的 .w / .sp 才会按面板宽度换算，而不是按整窗。
  installPaneScreenUtil();
  // 自带 EasySplitScope 的首页一起进全屏名单
  EasySplit.config.fullscreenRoutes.addAll(kDemoHomeRoutes);
  runApp(
    ScreenUtilInit(
      designSize: kDesignSize,
      builder: (context, child) => child!,
      child: const DemoApp(),
    ),
  );
  // 截图 / 回归用：--dart-define=EASYSPLIT_FORCE_MODE / EASYSPLIT_START_ROUTE
  applyDemoAutostart();
}

/// 本 demo 使用的接入方式（首页标题下方展示）
const kRouteScheme = '方案 · MaterialApp.router';

/// 注意：routerConfig 必须只创建一次。
/// 放进 build() 里每次重建都会生成新的 delegate → 新的 Navigator → 路由栈被重置。
/// 接入仍然是一行 `easySplitNativeRouterConfig`；demo 的
/// `--dart-define=EASYSPLIT_START_ROUTE` 只把 home 包一层 [demoHome]。
final RouterConfig<String> _routerConfig = easySplitNativeRouterConfig(
  home: demoHome(const AdPage(), title: kRouteScheme),
  pageBuilders: demoRoutes(scheme: kRouteScheme),
);

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EasySplit · 方案 MaterialApp.router',
      theme: demoTheme(),
      routerConfig: _routerConfig,
    );
  }
}
