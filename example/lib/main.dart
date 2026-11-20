/// 方案一：MaterialApp · onGenerateRoute 拦截器
///
/// 运行：flutter run -t lib/main.dart
///
/// 适合：使用 MaterialApp + 命名路由（pushNamed / routes 表）的项目，
/// 业务跳转代码零改动，拦截器自动完成宽屏分栏 / 窄屏全屏的转换。
///
/// 使用 GoRouter 的项目请运行 lib/main_go_route.dart（一行接入）。
import 'package:easy_split/easy_split.dart';
import 'package:flutter/material.dart';

import 'demo_pages.dart';

void main() {
  configureEasySplit();
  runApp(const OnGenerateRouteApp());
}

class OnGenerateRouteApp extends StatelessWidget {
  const OnGenerateRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '方案一 · onGenerateRoute 拦截器',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      // 接入点 1：列表页（栈底）包 EasySplitScope —— 决定谁是左栏
      home: const EasySplitScope(
          child: DemoRootPage(title: '方案一 · onGenerateRoute')),
      // 接入点 2：路由表挂适配器（宽屏分栏 / 全屏名单原生）
      onGenerateRoute: EasySplit.routeAdapter(demoRoutes()),
    );
  }
}
