import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  Color? get barrierColor => Colors.transparent;
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
    // 路由级命中裁剪：宽屏分栏时，整条路由只允许在右栏矩形内命中，
    // 左栏区域 100% 穿透到底部路由（不受业务页面内部结构影响）
    return _PaneHitTestScope(
      child: _PaneTeleport(child: _builder(context)),
    );
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

/// 路由级命中裁剪盒：
/// 宽屏分栏时，把本路由的命中测试严格限制在右栏矩形 [paneRect] 内，
/// 矩形之外（左栏区域）直接返回 false → 点击穿透到底部路由。
/// 这样即使业务页面内部有全屏 Material/Container，也无法挡住左栏。
class _PaneHitTestScope extends SingleChildRenderObjectWidget {
  const _PaneHitTestScope({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderPaneHitTest().._update(context);
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderObject renderObjectRaw) {
    (renderObjectRaw as _RenderPaneHitTest)._update(context);
  }
}

class _RenderPaneHitTest extends RenderProxyBox {
  BuildContext? _context;

  void _update(BuildContext context) {
    _context = context;
  }

  /// 实时计算命中矩形：null = 全屏命中（折叠/关闭态）
  Rect? get _paneRect {
    final ctx = _context;
    if (ctx == null) return null;
    if (!EasySplit.config.enabled.value || !EasySplit.isWide(ctx)) {
      return null;
    }
    return EasySplit.layoutOf(ctx).paneRect;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final rect = _paneRect;
    if (rect != null) {
      final inside = rect.contains(position);
      debugPrint('🟦 PaneRoute hitTest pos=$position inside=$inside '
          'rect=$rect');
      if (!inside) {
        return false; // 左栏区域：本路由完全不参与命中 → 穿透
      }
    }
    return super.hitTest(result, position: position);
  }
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
        // 宽屏：内容只占右栏矩形（与 EasySplitScope 共用同一布局，
        // 支持 EasySplit.config.layoutDelegate 自定义）。
        // 注意：这里不能铺满全屏——路由内容盒只落在右栏矩形，
        // 左栏区域在路由树中没有任何节点，手势自然穿透到底部路由
        final size = MediaQuery.sizeOf(context);
        final layout = EasySplit.layoutOf(context);
        final mq = MediaQuery.of(context);
        return Padding(
          // 整体右移：内容盒从 paneRect.left 开始
          padding: EdgeInsets.only(left: layout.paneRect.left),
          child: SizedBox(
            width: layout.paneRect.width,
            height: size.height,
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
        );
      },
    );
  }
}
