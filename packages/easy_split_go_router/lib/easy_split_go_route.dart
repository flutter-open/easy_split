import 'package:easy_split/easy_split.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

export 'package:easy_split/easy_split.dart'
    show EasySplitConfig, EasySplitLayout, EasySplitRoute, EasySplitPage, EasySplitScope;

/// EasySplitGoRoute · GoRoute 的分栏适配子类
///
/// 与 GoRoute 完全同参，只把生成的 Page 换成分栏路由：
/// - 宽屏（横屏）：页面渲染到右侧分栏区域
/// - 折叠（窄屏）：正常全屏路由模式
/// - [fullscreen] = true：任何宽度都全屏（沉浸页）
///
/// 结构完全自由：GoRoute / ShellRoute / StatefulShellRoute 混用均可，
/// 只是页面路由把 `GoRoute` 换成 `EasySplitGoRoute`：
///
/// ```dart
/// GoRouter(routes: [
///   GoRoute(path: '/', builder: (_, __) => EasySplitScope(child: RootPage())),
///   EasySplitGoRoute(path: '/detail', builder: (_, __) => DetailPage()),
///   ShellRoute(builder: ..., routes: [...]),
/// ])
/// ```
class EasySplitGoRoute extends GoRoute {
  EasySplitGoRoute({
    required super.path,
    required GoRouterWidgetBuilder builder,
    super.name,
    super.parentNavigatorKey,
    List<GoRoute> routes = const [],
    this.fullscreen = false,
  }) : super(
          pageBuilder: (context, state) => EasySplitPage(
            name: state.uri.toString(),
            arguments: state.extra,
            fullscreen: fullscreen,
            child: (_) => builder(context, state),
          ),
          routes: routes,
        );

  final bool fullscreen;
}
