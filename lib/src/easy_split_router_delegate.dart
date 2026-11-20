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
///
/// 内置增强（页面代码依旧零改动）：
/// - **重复路由去重**：同一路由已在栈内时，再次 `Navigator.pushNamed`
///   会把栈内实例置顶而不是重复压栈（[EasySplitConfig.dedupeRepeatedRoutes]，
///   默认开启；"同一路由"默认按 name + arguments 判断，可用
///   [EasySplitConfig.sameRoute] 自定义）。
/// - **参数透传**：[observers] / [onUnknownRoute]；路由外观参数见
///   [EasySplitRoute] / [EasySplitPage]。
class EasySplitRouterDelegate extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  EasySplitRouterDelegate({
    required this.home,
    required this.pageBuilders,
    this.observers = const <NavigatorObserver>[],
    this.onUnknownRoute,
  });

  /// 启动首路由 '/' 的内容（原 MaterialApp.home）
  final Widget home;

  /// 页面构建表：name → 页面构建器（与原 onGenerateRoute 的 routes 表相同）
  final Map<String, WidgetBuilder> pageBuilders;

  /// 追加给内部 Navigator 的观察者（与原生 `navigatorObservers` 等价）
  final List<NavigatorObserver> observers;

  /// 未注册路由的兜底（命中不到 [pageBuilders] 时交给它）
  final RouteFactory? onUnknownRoute;

  final _navigatorKey = GlobalKey<NavigatorState>();

  /// 栈内路由跟踪器：去重时用来找到"已经在栈里"的那条路由
  final _RouteTracker _tracker = _RouteTracker();

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
    return _DedupingNavigator(
      key: navigatorKey,
      tracker: _tracker,
      // 用户观察者 + 内部路由跟踪器（顺序无关）
      observers: <NavigatorObserver>[...observers, _tracker],
      onUnknownRoute: onUnknownRoute,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  /// 关键：使用普通命名路由 Navigator，页面里的 Navigator.pushNamed/pop
  /// 无需任何改动；'/' 原样走 MaterialPageRoute（全屏），与 MaterialApp.home
  /// 的行为一致；其余路由交给 EasySplit.adaptRoute 决定分栏 / 全屏。
  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    if (settings.name == Navigator.defaultRouteName) {
      return MaterialPageRoute<dynamic>(
        builder: (_) => home,
        settings: settings,
      );
    }
    final builder = pageBuilders[settings.name];
    if (builder == null) return null;
    return EasySplit.adaptRoute(settings, builder);
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
  List<NavigatorObserver> observers = const <NavigatorObserver>[],
  RouteFactory? onUnknownRoute,
  RootBackButtonDispatcher? backButtonDispatcher,
}) {
  return EasySplit.nativeRouterConfig(
    delegate: EasySplitRouterDelegate(
      home: home,
      pageBuilders: pageBuilders,
      observers: observers,
      onUnknownRoute: onUnknownRoute,
    ),
    backButtonDispatcher: backButtonDispatcher,
  );
}

/// 记录当前导航栈内的路由（按入栈顺序），用于重复路由去重。
class _RouteTracker extends NavigatorObserver {
  final List<Route<dynamic>> _routes = <Route<dynamic>>[];

  /// 找到栈内与 [settings] 属于"同一页面"的路由（从栈顶往下找）
  Route<dynamic>? findSame(RouteSettings settings) {
    final same = EasySplit.config.sameRoute ?? _defaultSameRoute;
    for (final route in _routes.reversed) {
      if (!route.isActive) continue;
      if (same(route.settings, settings)) return route;
    }
    return null;
  }

  /// 默认匹配规则：name 相同且 arguments 相等
  static bool _defaultSameRoute(RouteSettings a, RouteSettings b) =>
      a.name == b.name && a.arguments == b.arguments;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes
      ..remove(route)
      ..add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _routes.remove(oldRoute);
    if (newRoute != null) {
      _routes
        ..remove(newRoute)
        ..add(newRoute);
    }
  }
}

/// 在 `pushNamed` 时做去重的 Navigator。
///
/// 只拦截 `Navigator.pushNamed`（"点左侧条目"的场景）；
/// `pushReplacementNamed` / `pushNamedAndRemoveUntil` / `push` 保持原生语义。
class _DedupingNavigator extends Navigator {
  _DedupingNavigator({
    super.key,
    required this.tracker,
    required super.observers,
    required super.onGenerateRoute,
    super.onUnknownRoute,
  });

  final _RouteTracker tracker;

  @override
  NavigatorState createState() => _DedupingNavigatorState();
}

class _DedupingNavigatorState extends NavigatorState {
  @override
  Future<T?> pushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    if (EasySplit.config.dedupeRepeatedRoutes) {
      final existing = (widget as _DedupingNavigator)
          .tracker
          .findSame(RouteSettings(name: routeName, arguments: arguments));
      if (existing != null) {
        // 已在栈内：置顶（若它就是栈顶则什么都不用做），不重复压栈
        if (!existing.isCurrent) {
          popUntil((route) => identical(route, existing));
        }
        return Future<T?>.value();
      }
    }
    return super.pushNamed<T>(routeName, arguments: arguments);
  }
}
