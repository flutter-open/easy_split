import 'package:easy_split/easy_split.dart';
import 'package:flutter/material.dart';

import 'pages.dart';

/// ============================================================================
/// 方案二：MaterialApp.router（RouterDelegate，不依赖 go_router）
///
/// 页面代码零改动：页面里依然是 `Navigator.pushNamed / pop /
/// pushReplacementNamed`，arguments 照旧从 `ModalRoute.of(context)` 取。
/// 接线只有两步：
/// 1. 首页不是启动首路由（广告页 → replace 首页），把 '/home' 加入全屏名单，
///    它内部自包 EasySplitScope 自行分栏；
/// 2. routerConfig 只创建一次（放顶层 final / State 字段）。
/// ============================================================================
void main() {
  EasySplit.config.fullscreenRoutes.add('/home');
  runApp(const DemoApp());
}

/// 本 demo 使用的接入方式（首页标题下方展示）
const kRouteScheme = '方案 · MaterialApp.router';

/// 注意：routerConfig 必须只创建一次。
/// 放进 build() 里每次重建都会生成新的 delegate → 新的 Navigator → 路由栈被重置。
final RouterConfig<String> _routerConfig = easySplitNativeRouterConfig(
  home: const AdPage(),
  pageBuilders: {
    // 首页 = 左栏：入口处显式包 EasySplitScope，一眼看到"谁是左栏"
    '/home': (_) => EasySplitScope(child: const HomePage(title: kRouteScheme)),
    '/detail': (_) => const DetailPage(),
    '/secondary': (_) => const SecondaryPage(),
    '/dialogs': (_) => const DialogsPage(),
  },
);

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EasySplit · 方案 MaterialApp.router',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      routerConfig: _routerConfig,
    );
  }
}
