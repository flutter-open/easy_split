import 'package:easy_split/easy_split.dart';
import 'package:easy_split_go_router/easy_split_go_route.dart';
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

  // 你的 GoRouter 保持原样（唯一区别：首页 builder 里包了 EasySplitScope）
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
    ), // 沉浸页：普通 GoRoute + fullscreenRoutes 名单
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
