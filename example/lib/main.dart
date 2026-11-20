import 'package:easy_split/easy_split.dart';
import 'package:flutter/material.dart';

import 'pages.dart';

/// ============================================================================
/// 方案一：MaterialApp · onGenerateRoute（不依赖 go_router）
///
/// 极简接线就两行：
/// 1. 首页不是启动首路由（广告页 → replace 首页），把 '/home' 加入全屏名单，
///    它内部自包 EasySplitScope 自行分栏；
/// 2. onGenerateRoute 用 EasySplit.routeAdapter({...})，命中即分栏路由。
/// 3.（可选，推荐）navigatorObservers 加 EasySplit.dedupeObserver：
///    重复点同一个页面时把栈内已有的置顶，而不是反复压栈。
/// ============================================================================
void main() => runApp(const DemoApp());

/// 本 demo 使用的接入方式（首页标题下方展示）
const kRouteScheme = '方案 · onGenerateRoute（EasySplit.routeAdapter）';

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    EasySplit.config.fullscreenRoutes.add('/home');

    return MaterialApp(
      title: 'EasySplit · 方案 onGenerateRoute',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const AdPage(),
      // 重复路由去重（默认开启）：已在栈内的同一页面再次 pushNamed 时置顶
      navigatorObservers: [EasySplit.dedupeObserver],
      // 极简路由表：宽屏自动分栏 / 窄屏全屏；arguments 用 ModalRoute 取
      onGenerateRoute: EasySplit.routeAdapter({
        // 首页 = 左栏：入口处显式包 EasySplitScope，一眼看到"谁是左栏"
        '/home': (_) =>
            EasySplitScope(child: const HomePage(title: kRouteScheme)),
        '/detail': (_) => const DetailPage(),
        '/secondary': (_) => const SecondaryPage(),
        '/dialogs': (_) => const DialogsPage(),
      }),
    );
  }
}
