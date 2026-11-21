import 'dart:async';

import 'package:easy_split/easy_split.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
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
///   GoRoute(path: '/', builder: (_, _) => EasySplitScope(child: RootPage())),
///   EasySplitGoRoute(path: '/detail', builder: (_, _) => DetailPage()),
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
///
/// [redirect] / [onExit] / [caseSensitive] 与 [GoRoute] 同义，原样透传给父类，
/// 因此分栏页面同样可以写路由级登录拦截、离开确认。
class EasySplitGoRoute extends GoRoute {
  EasySplitGoRoute({
    required String path,
    required GoRouterWidgetBuilder builder,
    String? name,
    GlobalKey<NavigatorState>? parentNavigatorKey,
    List<GoRoute> routes = const [],
    GoRouterRedirect? redirect,
    ExitCallback? onExit,
    bool caseSensitive = true,
    this.fullscreen = false,
    this.dedupe = true,
  }) : super(
          path: path,
          name: name,
          parentNavigatorKey: parentNavigatorKey,
          routes: routes,
          redirect: redirect,
          onExit: onExit,
          caseSensitive: caseSensitive,
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

/// 在一个 GoRouter 的 match 栈里查找与 [settings] 相同的分栏页面，返回其下标
/// （没有则 -1）。
///
/// 供 go_router **16.3.0 及以上**的 `onEnter` 做去重判断，示例见
/// `example/lib/main_on_enter.dart`：
///
/// ```dart
/// onEnter: (context, current, next, router) {
///   final settings = RouteSettings(
///     name: next.matchedLocation,
///     arguments: next.extra,
///   );
///   if (easySplitIsDuplicate(
///     router.routerDelegate.currentConfiguration,
///     settings,
///   )) {
///     return const Block.stop();
///   }
///   return const Allow();
/// }
/// ```
///
/// 判断规则与 [EasySplitGoRoute] 内置去重一致：默认「匹配位置 + extra」相同
/// 视为同一页，可用 [EasySplitConfig.sameRoute] 覆盖；`ShellRoute` 子树不参与。
int easySplitDuplicateIndexOf(
  RouteMatchList configuration,
  RouteSettings settings,
) {
  final bool Function(RouteSettings, RouteSettings) same =
      EasySplit.config.sameRoute ?? _sameSettings;
  for (var i = configuration.matches.length - 1; i >= 0; i--) {
    final RouteMatchBase match = configuration.matches[i];
    if (match is ShellRouteMatch) {
      continue;
    }
    if (same(_settingsOf(configuration, match), settings)) {
      return i;
    }
  }
  return -1;
}

/// `easySplitDuplicateIndexOf` 的布尔快捷版：命中重复且
/// [EasySplitConfig.dedupeRepeatedRoutes] 开启时返回 true。
///
/// go_router 16.3+ 的 `onEnter` 里最常见的写法就是：
///
/// ```dart
/// onEnter: (context, current, next, router) {
///   final settings = RouteSettings(
///     name: next.matchedLocation,
///     arguments: next.extra,
///   );
///   if (easySplitIsDuplicate(router.routerDelegate.currentConfiguration, settings)) {
///     return const Block.stop();
///   }
///   return const Allow();
/// }
/// ```
bool easySplitIsDuplicate(
  RouteMatchList configuration,
  RouteSettings settings,
) {
  return EasySplit.config.dedupeRepeatedRoutes &&
      easySplitDuplicateIndexOf(configuration, settings) >= 0;
}

/// 去重动作：若 [settings] 对应的页面已在栈内（不含刚入栈的栈顶），返回一个
/// 「把中间页收掉、已有页面置顶」的回调；没有可收敛的页面则返回 null。
///
/// 用在 go_router 16.3+ 的 `onEnter` 里、配合 `Allow(then: ...)`：
///
/// ```dart
/// onEnter: (context, current, next, router) {
///   final settings = RouteSettings(
///     name: next.matchedLocation,
///     arguments: next.extra,
///   );
///   if (!easySplitIsDuplicate(router.routerDelegate.currentConfiguration, settings)) {
///     return const Allow();
///   }
///   final action = easySplitDedupeAction(router, settings);
///   return action == null ? const Block.stop() : Allow(then: action);
/// }
/// ```
///
/// 回调在导航提交之后执行：跳过栈顶的新页面，找到下面已有的同一页，把两者之间
/// 的页面全部 `pop` 掉（原页面 state 保留）。效果与 [EasySplitGoRoute] 内置去重
/// 一致。遵守 [EasySplitConfig.dedupeRepeatedRoutes] 与 [EasySplitConfig.sameRoute]。
FutureOr<void> Function()? easySplitDedupeAction(
  GoRouter router,
  RouteSettings settings,
) {
  if (!EasySplit.config.dedupeRepeatedRoutes) {
    return null;
  }
  final RouteMatchList configuration = router.routerDelegate.currentConfiguration;
  if (_duplicateIndexBelowTop(configuration, settings) < 0) {
    return null;
  }
  // 预期这次导航会往栈顶追加一页；回调里用它判断"确实发生了 push"。
  var expectedLength = configuration.matches.length + 1;
  return () async {
    // 等导航提交（页面真正入栈）后再收敛。
    await Future<void>.delayed(Duration.zero);
    var guard = 0;
    while (true) {
      final RouteMatchList config = router.routerDelegate.currentConfiguration;
      // 没有真的追加页面（例如 pop 后 go_router 重新解析当前地址），不处理。
      if (config.matches.length != expectedLength) {
        return;
      }
      final int index = _duplicateIndexBelowTop(config, settings);
      if (index < 0 || config.matches.length <= index + 1 || !router.canPop()) {
        return;
      }
      router.pop();
      expectedLength--;
      if (guard++ >= 32) {
        return;
      }
    }
  };
}

/// 在栈内查找 [settings] 对应的页面，**跳过栈顶**（刚 push 进来的新页面）。
int _duplicateIndexBelowTop(RouteMatchList configuration, RouteSettings settings) {
  final bool Function(RouteSettings, RouteSettings) sameRoute =
      EasySplit.config.sameRoute ?? _sameSettings;
  for (var i = configuration.matches.length - 2; i >= 0; i--) {
    final RouteMatchBase match = configuration.matches[i];
    if (match is ShellRouteMatch) {
      continue;
    }
    if (sameRoute(_settingsOf(configuration, match), settings)) {
      return i;
    }
  }
  return -1;
}
