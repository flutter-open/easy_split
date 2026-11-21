import 'package:easy_split_go_router/easy_split_go_router.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages.dart';

/// ============================================================================
/// 方案二·进阶：GoRouter `onEnter`（需要 go_router >= 16.3.0）
///
/// 与 `main.dart` 的区别只在「去重时机」：
/// - `main.dart`：`EasySplitGoRoute` 内置去重（pageBuilder 里发现重复后，
///   在帧末把栈收敛回去，带"置顶"效果），对 go_router 13 及以上都可用；
/// - 本文件：关掉内置去重（`dedupe: false`），改用 go_router 16.3+ 的
///   `onEnter`，在页面**入栈前**判断重复：
///   * 已在栈顶 → `Block.stop()`，直接拦掉，不重复压栈；
///   * 在栈内但不在栈顶 → `Allow(then: easySplitDedupeAction(...))`，
///     先允许入栈，提交后把中间页收掉，已有页面置顶（原页面 state 保留）。
///
/// 判断与收敛都不用自己写，库公开了三个函数：
/// - `easySplitDuplicateIndexOf(configuration, settings)`：算栈内是否已有同一页；
/// - `easySplitIsDuplicate(configuration, settings)`：布尔快捷版，只判断不处理；
/// - `easySplitDedupeAction(router, settings)`：返回"置顶已有页面"的回调。
///
/// 登录拦截仍用 `redirect`：`onEnter` 在 redirect 之前执行，所以未登录 push
/// 受保护页面时不会命中重复，会正常进入 `/login?from=...` 流程。
/// ============================================================================

/// 需要登录才能访问的路由前缀（带子路径，如 /detail/2）。
const _protected = <String>{'/detail', '/secondary', '/dialogs'};

bool _needsAuth(String location) =>
    _protected.any((p) => location == p || location.startsWith('$p/'));

/// 登录拦截：go_router 的 redirect 在每次解析路由时都会执行。
String? _guard(BuildContext context, GoRouterState state) {
  final String location = state.matchedLocation;
  if (!DemoAuth.isLoggedIn && _needsAuth(location)) {
    final String from = Uri.encodeComponent(state.uri.toString());
    return '/login?from=$from';
  }
  return null;
}

/// 导航表：广告页（全屏）→ 首页（左栏）→ 一级页 → 二级页 → 弹窗大全（分栏）
///
/// 抽成函数方便测试直接构造（`test/on_enter_dedupe_test.dart`）。
GoRouter createDemoRouter() {
  return GoRouter(
    initialLocation: '/',
    redirect: _guard,
    // go_router 16.3+：先于匹配 / 建页执行
    onEnter: (context, current, next, router) {
      final settings = RouteSettings(
        name: next.matchedLocation,
        arguments: next.extra,
      );
      if (!easySplitIsDuplicate(
        router.routerDelegate.currentConfiguration,
        settings,
      )) {
        return const Allow();
      }
      // 已在栈顶：直接拦掉，不再压栈。
      final action = easySplitDedupeAction(router, settings);
      if (action == null) {
        return const Block.stop();
      }
      // 页面在栈内但不在栈顶：先允许入栈，提交后把中间页收掉（已有页置顶）。
      return Allow(then: action);
    },
    routes: [
      // 广告页：普通 GoRoute，永远全屏
      GoRoute(path: '/', builder: (_, _) => const AdPage()),
      // 首页 = 左栏：入口处显式包 EasySplitScope，一眼看到"谁是左栏"
      GoRoute(
        path: '/home',
        builder: (_, _) => EasySplitScope(child: const HomePage()),
      ),
      // 登录页：普通 GoRoute，任何宽度都全屏，不参与分栏
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      // 一级页：EasySplitGoRoute = 宽屏右栏 / 窄屏全屏；去重交给 onEnter
      EasySplitGoRoute(
        path: '/detail/:index',
        builder: (_, _) => const DetailPage(),
        dedupe: false,
      ),
      // 二级页
      EasySplitGoRoute(
        path: '/secondary',
        builder: (_, _) => const SecondaryPage(),
        dedupe: false,
      ),
      // 系统弹窗大全
      EasySplitGoRoute(
        path: '/dialogs',
        builder: (_, _) => const DialogsPage(),
        dedupe: false,
      ),
    ],
  );
}

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EasySplit · GoRouter onEnter',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      routerConfig: createDemoRouter(),
    );
  }
}
