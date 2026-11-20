import 'package:flutter/material.dart';

import '../easy_split.dart';

/// 原生 router 模式的现成分栏 RouterDelegate
///
/// 管理一个页面栈（根页 = EasySplitScope 包裹的首页，其余为分栏二级页）：
/// - 宽屏（横屏）：二级页自动渲染到右侧分栏区域
/// - 窄屏（折叠）：二级页自动恢复全屏（正常路由模式）
/// - 页面栈完全保留，折叠/展开纯表现层切换
///
/// ```dart
/// final delegate = EasySplitRouterDelegate(
///   home: RootPage(),
///   pageBuilders: {
///     '/detail': (context) => DetailPage(),
///     '/filter': (context) => FilterPage(),
///   },
/// );
///
/// MaterialApp.router(
///   routerConfig: EasySplit.nativeRouterConfig(delegate),
/// )
///
/// // 页面内跳转 / 返回：
/// delegate.push('/detail');
/// Navigator.of(context).pop();
/// ```
class EasySplitRouterDelegate extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  EasySplitRouterDelegate({
    required Widget home,
    required Map<String, WidgetBuilder> pageBuilders,
    List<String> initialPages = const [],
  })  : home = EasySplitScope(child: home),
        pageBuilders = pageBuilders,
        _stack = [...initialPages];

  /// 首页（自动包 EasySplitScope，作为左栏）
  final Widget home;

  /// 页面构建表：name → 页面构建器
  final Map<String, WidgetBuilder> pageBuilders;

  /// 当前页面栈（根页之后的部分）
  final List<String> _stack;

  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  /// 当前页面栈（只读视图）
  List<String> get stack => List.unmodifiable(_stack);

  /// push 一个页面（name 需在 pageBuilders 中注册）
  void push(String name) {
    assert(pageBuilders.containsKey(name),
        'EasySplitRouterDelegate: 页面 "$name" 未在 pageBuilders 中注册');
    _stack.add(name);
    notifyListeners();
  }

  /// pop 栈顶页面（栈只剩首页时忽略）
  void pop() {
    if (_stack.isEmpty) return;
    _stack.removeLast();
    notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: [
        // 根页：首页 + Scope（左栏）
        EasySplitPage<String>(
          name: '/',
          child: (_) => home,
        ),
        // 二级页：每级一个 EasySplitPage（宽屏分栏 / 折叠全屏）
        for (final name in _stack)
          EasySplitPage<String>(
            name: name,
            child: (_) => (pageBuilders[name] ?? (_) => const SizedBox())(
                context),
          ),
      ],
      onPopPage: (route, result) {
        if (!route.didPop(result)) return false;
        final name = route.settings.name;
        if (name != null) _stack.remove(name);
        notifyListeners();
        return true;
      },
    );
  }

  @override
  Future<void> setNewRoutePath(String configuration) async {
    if (pageBuilders.containsKey(configuration)) push(configuration);
  }
}

/// 基于 [EasySplitRouterDelegate] 的 RouterConfig（一行接入）
RouterConfig<String> easySplitNativeRouterConfig({
  required Widget home,
  required Map<String, WidgetBuilder> pageBuilders,
  RootBackButtonDispatcher? backButtonDispatcher,
}) {
  final delegate = EasySplitRouterDelegate(
    home: home,
    pageBuilders: pageBuilders,
  );
  return RouterConfig<String>(
    routerDelegate: delegate,
    routeInformationParser: const _EasySplitRouteInformationParser(),
    backButtonDispatcher: backButtonDispatcher ?? RootBackButtonDispatcher(),
  );
}

class _EasySplitRouteInformationParser extends RouteInformationParser<String> {
  const _EasySplitRouteInformationParser();

  @override
  Future<String> parseRouteInformation(RouteInformation routeInformation) async {
    return routeInformation.uri?.toString() ?? '/';
  }
}
