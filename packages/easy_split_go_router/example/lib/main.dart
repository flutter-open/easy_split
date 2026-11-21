import 'package:easy_split_go_router/easy_split_go_router.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages.dart';

/// ============================================================================
/// 方案二：GoRouter · routerConfig（easy_split_go_router 一行接入）
///
/// 极简零配置：把普通 GoRoute 换成 EasySplitGoRoute 即可，
/// 宽屏自动分栏 / 窄屏全屏；'/home' 作为栈底包 EasySplitScope 当左栏。
/// 重复点同一个列表项会自动置顶（内置去重，无需额外配置）。
///
/// Demo 的登录拦截完全交给 go_router 自己的能力：
/// - `redirect`：未登录访问 /detail、/secondary、/dialogs 时自动改道
///   `/login?from=<原地址>`，登录页完成后带着 from 回到原目标；
/// - `refreshListenable`：监听 DemoAuth.currentUser，登录/退出立即重新解析路由。
/// 页面里不再手写"先登录再跳转"，直接 context.push('/detail/2') 即可。
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
final _router = GoRouter(
  initialLocation: '/',
  refreshListenable: DemoAuth.currentUser,
  redirect: _guard,
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
    // 一级页：EasySplitGoRoute = 宽屏右栏 / 窄屏全屏。
    // 用 :index 路径参数而不是 extra，这样被 redirect 改道后目标不会丢。
    EasySplitGoRoute(
      path: '/detail/:index',
      builder: (_, _) => const DetailPage(),
    ),
    // 二级页
    EasySplitGoRoute(
      path: '/secondary',
      builder: (_, _) => const SecondaryPage(),
    ),
    // 系统弹窗大全
    EasySplitGoRoute(path: '/dialogs', builder: (_, _) => const DialogsPage()),
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
