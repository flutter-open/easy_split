import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../easy_split.dart';

/// 宽屏 pane 路由：真·原生路由（PageRoute）
///
/// 与 MaterialPageRoute 的区别（仅为实现分栏所需的 5 点）：
/// - opaque=false：下层页面持续绘制（左栏首页可见、可点击、状态保留）
/// - 无 ModalBarrier：点击可穿透到左栏
/// - delegatedTransition 透传：抑制系统转场对下层页面的视差位移
/// - 整条路由缩进右栏：位置定在 buildTransitions 外层（见该处注释），
///   让 PageRoute 自带的手势层（iOS 侧滑返回热区）也锚定在 pane 左缘
/// - 内容自适应：宽屏渲染到右侧 pane 区域，折叠自动恢复全屏
///
/// 转场动画委托给原始路由的实现（Cupertino 滑动 / 主题平台转场），
/// 观感与系统原生一致，路由栈全程不动
class EasySplitRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  EasySplitRoute({
    required WidgetBuilder builder,
    super.settings,
    super.requestFocus,
    super.fullscreenDialog = false,
    super.allowSnapshotting = true,
    this.maintainState = true,
  }) : _builder = builder;

  final WidgetBuilder _builder;

  /// 是否保留被遮挡页面的状态（默认 true，与 MaterialPageRoute 一致）
  @override
  final bool maintainState;

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
    // 关键：把「转场 + PageRoute 自带的手势层」整体缩进右栏，而不是先全屏
    // 再在 content 内部做定位。
    //
    // buildTransitions 的产物在 Overlay 里拿到的始终是「全屏」约束，而框架
    // （以及自定义 PageTransitionsBuilder）会在这一层插入自己的手势探测器：
    // 最典型的是 CupertinoPageTransitionsBuilder 的 iOS 侧滑返回热区
    // —— Stack[child, PositionedDirectional(start: 0, width: 20,
    // child: Listener(...))]，它贴着「路由盒子」的左边。路由盒子若是全屏，
    // 热区就落在屏幕最左 = 左栏里：
    //   · 从屏幕左缘右滑 → 把右栏详情 pop 掉（左栏手势被路由劫持）
    //   · 从右栏左缘右滑 → 毫无反应（用户直觉的位置反而失效）
    // buildContent 内部的 hitTest 裁剪管不到这一层。
    //
    // 所以这里先按主题/平台产出原始转场，再由 _PaneFrame 统一套上位置与
    // 尺寸：整棵转场子树（含手势层）都在 pane 约束内布局。副作用同样正向：
    // 转场动画只在右栏内播放，不再横扫左栏；Cupertino 的拖拽进度按 pane
    // 宽度换算（手势与动画 1:1 跟手）。
    final transition = Theme.of(context).pageTransitionsTheme
        .buildTransitions<dynamic>(
      this,
      context,
      animation,
      kAlwaysDismissedAnimation,
      child,
    );
    return _PaneFrame(child: transition);
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
    this.maintainState = true,
    this.fullscreenDialog = false,
    this.allowSnapshotting = true,
    this.requestFocus,
  }) : _child = child;

  final WidgetBuilder _child;

  /// true = 任何宽度都全屏（原生 MaterialPageRoute）
  final bool fullscreen;

  /// 是否保留被遮挡页面的状态（透传给底层路由，默认 true）
  final bool maintainState;

  /// 是否作为全屏对话框（影响 AppBar 返回按钮样式 / iOS 转场）
  final bool fullscreenDialog;

  /// 是否允许系统在转场期间对页面做快照（透传给底层路由，默认 true）
  final bool allowSnapshotting;

  /// 路由入栈时是否请求焦点（null = 跟随 Navigator，默认行为）
  final bool? requestFocus;

  @override
  Route<T> createRoute(BuildContext context) {
    // settings 必须是 Page 自身：pages 模式的 Navigator
    // 要求 route.settings is Page（否则断言失败）
    final routeSettings = this;
    if (fullscreen || EasySplit.isFullscreen(routeSettings)) {
      return MaterialPageRoute<T>(
        builder: _child,
        settings: routeSettings,
        maintainState: maintainState,
        fullscreenDialog: fullscreenDialog,
        allowSnapshotting: allowSnapshotting,
        requestFocus: requestFocus,
      );
    }
    return EasySplitRoute<T>(
      builder: _child,
      settings: routeSettings,
      maintainState: maintainState,
      fullscreenDialog: fullscreenDialog,
      allowSnapshotting: allowSnapshotting,
      requestFocus: requestFocus,
    );
  }
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
      // paneRect 是全局坐标，position 是本渲染对象的局部坐标，必须先换算：
      // 宽屏下本对象已被 _PaneFrame 缩进右栏，两者不再相等。
      if (!rect.contains(localToGlobal(position))) {
        return false; // 左栏区域：本路由完全不参与命中 → 穿透
      }
    }
    return super.hitTest(result, position: position);
  }
}

/// 把整条路由（转场 + 框架自带的手势层）放进右栏
///
/// 位置和尺寸必须在这一层决定：buildTransitions 的产物拿到的是全屏约束，
/// 只有在这里把约束缩成 pane，框架插入的手势探测器（iOS 侧滑返回热区）
/// 和转场动画才会以 pane 为坐标系 —— 见 EasySplitRoute.buildTransitions。
class _PaneFrame extends StatelessWidget {
  const _PaneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        EasySplit.config.enabled,
        EasySplit.config.layoutVersion,
      ]),
      builder: (context, _) {
        final enabled = EasySplit.config.enabled.value;
        if (!(enabled && EasySplit.isWide(context))) {
          // 折叠态：全屏（正常路由模式）
          return child;
        }
        final size = MediaQuery.sizeOf(context);
        final pane = EasySplit.layoutOf(context).paneRect;
        return Padding(
          padding: EdgeInsets.only(
            left: pane.left,
            top: pane.top,
            right: math.max(0.0, size.width - pane.right),
            bottom: math.max(0.0, size.height - pane.bottom),
          ),
          child: SizedBox(
            width: pane.width,
            height: pane.height,
            child: child,
          ),
        );
      },
    );
  }
}

/// 右栏面板装饰 + 安全区处理（位置/尺寸由 [_PaneFrame] 决定）
class _PaneTeleport extends StatelessWidget {
  final Widget child;

  const _PaneTeleport({required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        EasySplit.config.enabled,
        EasySplit.config.layoutVersion,
      ]),
      builder: (context, _) {
        final enabled = EasySplit.config.enabled.value;
        final paneMode = enabled && EasySplit.isWide(context);
        if (!paneMode) {
          // 折叠态：全屏（正常路由模式）
          return child;
        }
        final mq = MediaQuery.of(context);
        return DecoratedBox(
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
        );
      },
    );
  }
}
