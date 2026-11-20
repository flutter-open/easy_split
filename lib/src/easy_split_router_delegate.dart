import 'package:flutter/material.dart';

import '../easy_split.dart';

/// 原生 router 模式（MaterialApp.router，无 go_router）的 RouterDelegate
///
/// 行为与 `onGenerateRoute` 方案**完全一致**，页面代码零改动：
/// - `Navigator.pushNamed(context, '/detail')` → 宽屏右栏 / 窄屏全屏
/// - `Navigator.pop(context)` / 系统返回 → 正常返回
/// - `pushReplacementNamed` / `pushNamedAndRemoveUntil` 等与原生一致
/// - 页面参数仍用 `ModalRoute.of(context)!.settings.arguments` 获取
///
/// ```dart
/// MaterialApp.router(
///   routerConfig: easySplitNativeRouterConfig(
///     home: RootPage(),                                   // 启动首路由 '/'
///     pageBuilders: {                                     // 与 routeAdapter 同一张表
///       '/detail': (_) => DetailPage(),
///       '/home': (_) => EasySplitScope(child: HomePage()), // 左栏自己包 Scope
///     },
///   ),
/// )
/// ```
///
/// 注意：
/// 1. `home` 就是 '/' 路由本身，**不会**被自动包 [EasySplitScope] ——
///    谁是左栏由你在对应路由的 builder 里决定（与 `onGenerateRoute` 方案一致）。
/// 2. `routerConfig` 请在 `build` 之外只创建一次（字段 / `late final`），
///    否则每次重建都会生成新的 Navigator，路由栈会被重置。
class EasySplitRouterDelegate extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  EasySplitRouterDelegate({
    required this.home,
    required this.pageBuilders,
  });

  /// 启动首路由 '/' 的内容（原 MaterialApp.home）
  final Widget home;

  /// 页面构建表：name → 页面构建器（与原 onGenerateRoute 的 routes 表相同）
  final Map<String, WidgetBuilder> pageBuilders;

  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  /// 等价于 `Navigator.pushNamed`：方便持有 delegate 的代码直接跳转
  void push(String name, {Object? arguments}) {
    _navigatorKey.currentState?.pushNamed(name, arguments: arguments);
  }

  /// 等价于 `Navigator.pop`
  Future<bool> pop<T extends Object?>([T? result]) async {
    return await _navigatorKey.currentState?.maybePop<T>(result) ?? false;
  }

  /// 首帧之前收到的深链（Router 在构建 Navigator 前会调用一次 setNewRoutePath）
  String? _pendingLocation;

  @override
  Widget build(BuildContext context) {
    final pending = _pendingLocation;
    if (pending != null) {
      _pendingLocation = null;
      // Navigator 就在这一帧里创建：等本帧构建完成后把深链同步进去
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncRoute(pending));
    }
    return Navigator(
      key: navigatorKey,
      // 关键：使用普通命名路由 Navigator，页面里的 Navigator.pushNamed/pop
      // 无需任何改动；'/' 原样走 MaterialPageRoute（全屏），与 MaterialApp.home
      // 的行为一致；其余路由交给 EasySplit.adaptRoute 决定分栏 / 全屏。
      onGenerateRoute: (settings) {
        if (settings.name == Navigator.defaultRouteName) {
          return MaterialPageRoute<dynamic>(
            builder: (_) => home,
            settings: settings,
          );
        }
        final builder = pageBuilders[settings.name];
        if (builder == null) return null;
        return EasySplit.adaptRoute(settings, builder);
      },
    );
  }

  @override
  Future<void> setNewRoutePath(String configuration) async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      // 首帧（Router 在构建 Navigator 之前就会调用一次，configuration 通常是 '/'）
      _pendingLocation = configuration;
      return;
    }
    _syncRoute(configuration);
  }

  /// 把 Router 的位置同步到 Navigator：
  /// - '' / '/' → 回到栈底（首帧和浏览器后退）
  /// - 已注册的命名路由 → 压栈（深链）
  /// 未注册的深链直接忽略，避免 onGenerateRoute 返回 null 后抛错。
  void _syncRoute(String configuration) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    if (configuration.isEmpty || configuration == '/') {
      navigator.popUntil((route) => route.isFirst);
    } else if (pageBuilders.containsKey(configuration)) {
      navigator.pushNamed(configuration);
    }
  }
}

/// 基于 [EasySplitRouterDelegate] 的 RouterConfig（一行接入）
///
/// ```dart
/// MaterialApp.router(
///   routerConfig: easySplitNativeRouterConfig(
///     home: RootPage(),
///     pageBuilders: {'/detail': (_) => DetailPage()},
///   ),
/// )
/// ```
RouterConfig<String> easySplitNativeRouterConfig({
  required Widget home,
  required Map<String, WidgetBuilder> pageBuilders,
  RootBackButtonDispatcher? backButtonDispatcher,
}) {
  return EasySplit.nativeRouterConfig(
    delegate: EasySplitRouterDelegate(
      home: home,
      pageBuilders: pageBuilders,
    ),
    backButtonDispatcher: backButtonDispatcher,
  );
}
