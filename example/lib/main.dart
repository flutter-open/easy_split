import 'package:easy_split/easy_split.dart';
import 'package:easy_split_demo/easy_split_demo.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// ============================================================================
/// 方案一：MaterialApp · onGenerateRoute（不依赖 go_router）
///
/// 极简接线就两行：
/// 1. 首页不是启动首路由（广告页 → replace 首页），把首页路由加入全屏名单，
///    它内部自包 EasySplitScope 自行分栏；'/login' 也全屏（登录页不分栏）。
/// 2. onGenerateRoute 用 EasySplit.routeAdapter({...})，命中即分栏路由。
/// 3.（可选，推荐）navigatorObservers 加 EasySplit.dedupeObserver：
///    重复点同一个页面时把栈内已有的置顶，而不是反复压栈。
///
/// 演示页面与路由表都在 `package:easy_split_demo` 里，与方案二共用；
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
const kRouteScheme = '方案 · onGenerateRoute（EasySplit.routeAdapter）';

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EasySplit · 方案 onGenerateRoute',
      theme: demoTheme(),
      home: demoHome(const AdPage(), title: kRouteScheme),
      // 重复路由去重（默认开启）：已在栈内的同一页面再次 pushNamed 时置顶
      navigatorObservers: [EasySplit.dedupeObserver],
      // 极简路由表：宽屏自动分栏 / 窄屏全屏；arguments 用 ModalRoute 取
      onGenerateRoute: EasySplit.routeAdapter(
        demoRoutes(scheme: kRouteScheme),
      ),
    );
  }
}
