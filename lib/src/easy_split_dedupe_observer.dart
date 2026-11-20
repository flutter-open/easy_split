import 'dart:async';

import 'package:flutter/widgets.dart';

import '../easy_split.dart';

/// 标准 Navigator（`onGenerateRoute` 方案）下的重复路由去重观察者
///
/// `MaterialApp` 自己创建 Navigator，框架不提供 `pushNamed` 拦截点，
/// 所以在路由压栈后把"重复的那条"立刻摘掉，并把栈内已有的同页路由置顶。
///
/// 一行接入（[EasySplit.routeAdapter] 方案）：
/// ```dart
/// MaterialApp(
///   onGenerateRoute: EasySplit.routeAdapter({...}),
///   navigatorObservers: [EasySplit.dedupeObserver],
/// )
/// ```
/// 默认按 name + arguments 判断"同一页面"，可用
/// [EasySplitConfig.sameRoute] 自定义；[EasySplitConfig.dedupeRepeatedRoutes]
/// 为 false 时完全不做处理。
///
/// 注：MaterialApp.router（[EasySplitRouterDelegate]）方案自带拦截式去重，
/// 无需再添加本观察者。
class EasySplitDedupeObserver extends NavigatorObserver {
  /// 按 Navigator 分别记录路由栈（Expando：Navigator 销毁后自动释放）。
  ///
  /// 用共享状态而不是实例字段，这样即使 widget 每次 build 都新建
  /// 观察者实例（`navigatorObservers: [EasySplit.dedupeObserver]`），
  /// 已记录的路由也不会丢。
  static final Expando<List<Route<dynamic>>> _routesByNavigator =
      Expando<List<Route<dynamic>>>('easySplitRoutes');

  List<Route<dynamic>> _routesOf(NavigatorState navigator) =>
      _routesByNavigator[navigator] ??= <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final navigator = route.navigator;
    if (navigator == null) return;
    final routes = _routesOf(navigator)
      // 顺手清掉已经不在栈里的路由（didPop 时 navigator 可能已被置空）
      ..removeWhere((r) => !r.isActive || identical(r, route))
      ..add(route);

    if (!EasySplit.config.dedupeRepeatedRoutes || !route.isActive) return;

    final same = EasySplit.config.sameRoute ?? _defaultSameRoute;
    Route<dynamic>? older;
    for (final candidate in routes.reversed) {
      if (identical(candidate, route) || !candidate.isActive) continue;
      if (same(candidate.settings, route.settings)) {
        older = candidate;
        break;
      }
    }
    if (older == null) return;

    // didPush 处在 Navigator 的历史刷新过程中，不能同步改栈：
    // 放到 microtask，先摘掉刚压入的重复路由，再把旧的那条置顶。
    final target = older;
    scheduleMicrotask(() {
      if (!route.isActive || !target.isActive) return;
      navigator.removeRoute(route);
      navigator.popUntil((r) => identical(r, target));
    });
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final navigator = route.navigator;
    if (navigator != null) _routesOf(navigator).remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final navigator = route.navigator;
    if (navigator != null) _routesOf(navigator).remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final navigator = newRoute?.navigator ?? oldRoute?.navigator;
    if (navigator == null) return;
    final routes = _routesOf(navigator);
    if (oldRoute != null) routes.remove(oldRoute);
    if (newRoute != null) {
      routes
        ..remove(newRoute)
        ..add(newRoute);
    }
  }

  /// 默认匹配规则：name 相同且 arguments 相等
  static bool _defaultSameRoute(RouteSettings a, RouteSettings b) =>
      a.name == b.name && a.arguments == b.arguments;
}
