import 'package:easy_split_go_router/easy_split_go_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages.dart';

/// ============================================================================
/// 方案二：GoRouter · routerConfig（easy_split_go_router 一行接入）
///
/// 极简零配置：把普通 GoRoute 换成 EasySplitGoRoute 即可，
/// 宽屏自动分栏 / 窄屏全屏；'/home' 作为栈底包 EasySplitScope 当左栏。
/// 重复点同一个列表项会自动置顶（内置去重，无需额外配置）。
/// ============================================================================

/// 导航表：广告页（全屏）→ 首页（左栏）→ 一级页 → 二级页 → 弹窗大全（分栏）
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    // 广告页：普通 GoRoute，永远全屏
    GoRoute(path: '/', builder: (_, __) => const AdPage()),
    // 首页 = 左栏：入口处显式包 EasySplitScope，一眼看到"谁是左栏"
    GoRoute(
      path: '/home',
      builder: (_, __) => EasySplitScope(child: const HomePage()),
    ),
    // 一级页：EasySplitGoRoute = 宽屏右栏 / 窄屏全屏
    EasySplitGoRoute(path: '/detail', builder: (_, __) => const DetailPage()),
    // 二级页
    EasySplitGoRoute(
      path: '/secondary',
      builder: (_, __) => const SecondaryPage(),
    ),
    // 系统弹窗大全
    EasySplitGoRoute(path: '/dialogs', builder: (_, __) => const DialogsPage()),
  ],
);

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EasySplit · 方案 GoRouter',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      routerConfig: _router,
    );
  }
}
