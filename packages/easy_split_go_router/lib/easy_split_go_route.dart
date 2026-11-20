import 'package:easy_split/easy_split.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

export 'package:easy_split/easy_split.dart'
    show
        EasySplitConfig,
        EasySplitLayout,
        EasySplitRoute,
        EasySplitPage,
        EasySplitScope;

/// EasySplitGoRoute · GoRoute 的分栏适配子类
///
/// 与 GoRoute 完全同参，只把生成的 Page 换成分栏路由：
/// - 宽屏（横屏）：页面渲染到右侧分栏区域
/// - 折叠（窄屏）：正常全屏路由模式
/// - [fullscreen] = true：任何宽度都全屏（沉浸页）
///
/// 结构完全自由：GoRoute / ShellRoute / StatefulShellRoute 混用均可，
/// 只是页面路由把 `GoRoute` 换成 `EasySplitGoRoute`（机械复用，一个词的改动）：
///
/// ```dart
/// GoRouter(routes: [
///   GoRoute(path: '/', builder: (_, __) => EasySplitScope(child: RootPage())),
///   EasySplitGoRoute(path: '/detail', builder: (_, __) => DetailPage()),
///   ShellRoute(builder: ..., routes: [...]),
/// ])
/// ```
///
/// 重复路由去重（[dedupe]，默认 true）：
/// 和 MaterialApp.router 方案一致——当 `context.push('/detail')` 的目标页面
/// 已经存在于当前路由栈中时，不再重复压栈，而是把栈内已有的那一页置顶
/// （中间页面弹掉，返回键直接回到上一页）。判断规则复用
/// [EasySplitConfig.sameRoute] / [EasySplitConfig.dedupeRepeatedRoutes]，
/// 默认按「匹配位置 + extra」判断是否为同一页。
///
/// 说明：GoRouter 的 push 由框架内部的 RouteInformationProvider 处理，
/// 无法像 MaterialApp.router 方案那样拦截 `pushNamed`，因此去重是基于
/// pageBuilder 在「新页面入栈后」自动收敛路由栈实现的；对页面代码零改动。
/// ShellRoute / StatefulShellRoute 内的子页面暂不参与去重（保持原生行为）。
class EasySplitGoRoute extends GoRoute {
  EasySplitGoRoute({
    required String path,
    required GoRouterWidgetBuilder builder,
    String? name,
    GlobalKey<NavigatorState>? parentNavigatorKey,
    List<GoRoute> routes = const [],
    this.fullscreen = false,
    this.dedupe = true,
  }) : super(
          path: path,
          name: name,
          parentNavigatorKey: parentNavigatorKey,
          routes: routes,
          pageBuilder: (context, state) {
            if (dedupe) _scheduleDedupe(context);
            return EasySplitPage(
              name: state.uri.toString(),
              arguments: state.extra,
              fullscreen: fullscreen,
              child: (_) => builder(context, state),
            );
          },
        );

  /// true = 任何宽度都全屏（原生 MaterialPageRoute）
  final bool fullscreen;

  /// 是否启用「同一页面已在栈内则置顶」去重（默认 true）
  final bool dedupe;
}

/// 每个 GoRouter 最近一次已处理的 RouteMatchList 身份，
/// 避免同一次构建里多个 pageBuilder 重复调度 / 重建时反复调度。
final Expando<RouteMatchList> _lastChecked =
    Expando<RouteMatchList>('easySplitGoRouteDedupe');

/// 在 pageBuilder 阶段检测「栈内已有同一页」，并在帧结束后把栈收敛回去。
void _scheduleDedupe(BuildContext context) {
  if (!EasySplit.config.dedupeRepeatedRoutes) {
    return;
  }
  final GoRouter router;
  try {
    router = GoRouter.of(context);
  } on Object {
    return;
  }
  final RouteMatchList config = router.routerDelegate.currentConfiguration;
  if (identical(_lastChecked[router], config)) {
    return;
  }
  final int targetIndex = _duplicateTargetIndex(config);
  if (targetIndex < 0) {
    return;
  }
  _lastChecked[router] = config;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final RouteMatchList current = router.routerDelegate.currentConfiguration;
    final int target = identical(current, config)
        ? targetIndex
        : _duplicateTargetIndex(current);
    if (target < 0) {
      return;
    }
    // 弹掉置顶页与该页之间的所有页面；每 pop 一次 GoRouter 会同步
    // 从 match list 里移除对应 match，因此直接循环即可。
    var guard = 0;
    while (router.routerDelegate.currentConfiguration.matches.length >
            target + 1 &&
        router.canPop() &&
        guard++ < 32) {
      router.pop();
    }
  });
}

/// 返回「栈内已有的、与新页相同的 match」的下标；没有则 -1。
///
/// 只处理顶层 Navigator 上的普通路由 / push 进来的页面；
/// ShellRoute 子树暂不参与（保持原生行为）。
int _duplicateTargetIndex(RouteMatchList config) {
  final List<RouteMatchBase> matches = config.matches;
  if (matches.length < 2) {
    return -1;
  }
  final RouteMatchBase newest = matches.last;
  if (newest is ShellRouteMatch) {
    return -1;
  }
  final bool Function(RouteSettings, RouteSettings) same =
      EasySplit.config.sameRoute ?? _sameSettings;
  for (var i = matches.length - 2; i >= 0; i--) {
    final RouteMatchBase candidate = matches[i];
    if (candidate is ShellRouteMatch) {
      continue;
    }
    if (same(_settingsOf(config, candidate), _settingsOf(config, newest))) {
      return i;
    }
  }
  return -1;
}

/// 把 match 还原成 RouteSettings（name = 匹配到的位置，arguments = extra），
/// 以便复用 [EasySplitConfig.sameRoute] 这一套比较规则。
RouteSettings _settingsOf(RouteMatchList config, RouteMatchBase match) {
  if (match is ImperativeRouteMatch) {
    return RouteSettings(
      name: match.matchedLocation,
      arguments: match.matches.extra,
    );
  }
  return RouteSettings(name: match.matchedLocation, arguments: config.extra);
}

bool _sameSettings(RouteSettings a, RouteSettings b) =>
    a.name == b.name && a.arguments == b.arguments;
