/// 方案二：GoRouter · routerConfig 零路由改动接入
///
/// 运行：flutter run -t lib/main.dart
///
/// 你的 GoRouter 保持原样（唯一区别：首页 builder 里包了 EasySplitScope），
/// 仅在 routerConfig 处替换为 `goRouter.easySplit`，
/// 所有路由自动完成宽屏分栏 / 折叠全屏的转换。
import 'package:easy_split/easy_split.dart';
import 'package:easy_split_go_router/easy_split_go_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'demo_pages.dart';
import 'pages/detail_page.dart';
import 'pages/filter_page.dart';
import 'pages/login_page.dart';

void main() {
  configureEasySplit();
  runApp(GoRouteApp());
}

class GoRouteApp extends StatelessWidget {
  GoRouteApp({super.key});

  final _router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const EasySplitScope(
        child: DemoRootPage(title: '方案二 · GoRouter'),
      ),
    ),
    EasySplitGoRoute(
      path: '/detail',
      builder: (_, __) => const OrderDetailPage(),
    ),
    EasySplitGoRoute(
      path: '/filter',
      builder: (_, __) => const FilterPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginPage(),
    ), // 沉浸页：fullscreenRoutes 名单
  ]);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '方案二 · GoRouter',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      routerConfig: _router,
    );
  }
}
