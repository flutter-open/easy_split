import 'package:flutter/material.dart';

import '../easy_split.dart';

/// 宽屏 pane 路由：真·原生路由（PageRoute）
///
/// 与 MaterialPageRoute 的区别（仅为实现分栏所需的 4 点）：
/// - opaque=false：下层页面持续绘制（左栏首页可见、可点击、状态保留）
/// - 无 ModalBarrier：点击可穿透到左栏
/// - delegatedTransition 透传：抑制系统转场对下层页面的视差位移
/// - 内容自适应：宽屏渲染到右侧 pane 区域，折叠自动恢复全屏
///
/// 转场动画委托给原始路由的实现（Cupertino 滑动 / 主题平台转场），
/// 观感与系统原生一致，路由栈全程不动
class EasySplitRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  EasySplitRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : _builder = builder;

  final WidgetBuilder _builder;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  Widget buildModalBarrier() => const SizedBox.shrink();

  // 接管下层路由的转场：透传 child，
  // 抑制系统转场对下层页面（左栏首页）的视差位移
  @override
  DelegatedTransitionBuilder? get delegatedTransition => _passThroughTransition;

  static Widget? _passThroughTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    return child;
  }

  @override
  Widget buildContent(BuildContext context) {
    return _PaneTeleport(child: _builder(context));
  }

  // 转场：使用当前主题/平台的 Material 转场
  // （iOS=Cupertino 滑动+边缘阴影、Android=Zoom/FadeForwards，跟随业务主题配置），
  // 与原生 MaterialPageRoute 的动画实现完全一致，观感丝滑。
  // secondaryAnimation 恒定为 dismissed：中和系统视差位移，
  // 保证被其他 pane 路由覆盖时右栏内容始终对齐（左栏首页由
  // delegatedTransition 透传保护，同样不位移）
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return Theme.of(context).pageTransitionsTheme.buildTransitions<dynamic>(
      this,
      context,
      animation,
      kAlwaysDismissedAnimation,
      child,
    );
  }
}

/// GoRouter / Navigator.pages 模式的 Page 适配器
///
/// ```dart
/// MaterialApp.router(
///   routerConfig: GoRouter(
///     routes: [
///       GoRoute(
///         path: '/',
///         builder: (_, __) => EasySplitScope(child: RootPage()), // 左栏
///       ),
///       GoRoute(
///         path: '/detail',
///         pageBuilder: (context, state) => EasySplitPage(
///           name: state.uri.toString(),
///           arguments: state.extra,
///           child: (_) => const DetailPage(),
///         ),
///       ),
///     ],
///   ),
/// )
/// ```
class EasySplitPage<T> extends Page<T> {
  EasySplitPage({
    required WidgetBuilder child,
    super.name,
    super.arguments,
    super.restorationId,
    this.fullscreen = false,
  }) : _child = child;

  final WidgetBuilder _child;

  /// true = 任何宽度都全屏（原生 MaterialPageRoute）
  final bool fullscreen;

  @override
  Route<T> createRoute(BuildContext context) {
    // settings 必须是 Page 自身：pages 模式的 Navigator
    // 要求 route.settings is Page（否则断言失败）
    final routeSettings = this;
    if (fullscreen || EasySplit.isFullscreen(routeSettings)) {
      return MaterialPageRoute<T>(builder: _child, settings: routeSettings);
    }
    return EasySplitRoute<T>(builder: _child, settings: routeSettings);
  }
}

/// 默认 pane 内容包装：透明 Material
Widget _defaultPaneWrapper(BuildContext context, Widget child) {
  return Material(type: MaterialType.transparency, child: child);
}

/// 路由内容自适应容器
class _PaneTeleport extends StatelessWidget {
  final Widget child;

  const _PaneTeleport({required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: EasySplit.config.enabled,
      builder: (context, enabled, _) {
        final paneMode = enabled && EasySplit.isWide(context);
        if (!paneMode) {
          // 折叠态：全屏（正常路由模式）
          return child;
        }
        // 宽屏：内容渲染到右栏区域（与 EasySplitScope 共用同一布局，
        // 支持 EasySplit.config.layoutDelegate 自定义；背景铺满、内容避让安全区）
        final layout = EasySplit.layoutOf(context);
        final mq = MediaQuery.of(context);
        return SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: layout.paneRect,
                child: DecoratedBox(
                  decoration: EasySplit.config.paneDecoration ??
                      BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        border: Border(
                          left: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 0.5,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                  child: MediaQuery(
                    data: mq.copyWith(
                      padding: EasySplit.removeInsets(
                          mq.padding, EasySplit.paneContentInsets(context)),
                    ),
                    child: Padding(
                      padding: EasySplit.paneContentInsets(context),
                      child: Material(
                        type: MaterialType.transparency,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
