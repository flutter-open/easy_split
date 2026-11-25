// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:easy_split/easy_split.dart';
import 'package:get/get.dart';

/// A [GetPageRoute] that renders into EasySplit's right pane on wide screens.
///
/// It keeps everything GetX does for a normal page route — middlewares,
/// bindings, `Get.currentRoute` reporting and the configured transition — and
/// only replaces the parts that make a route fullscreen:
///
/// * `opaque = false` so the left pane keeps painting;
/// * no modal barrier, so taps on the left pane reach the page below;
/// * a pass-through `delegatedTransition` so the left page does not parallax;
/// * the whole transition (including iOS back-gesture hot zone) is laid out
///   inside the pane rectangle.
///
/// Usually you do not construct this class directly: [EasySplitGetPage] and
/// [easySplitGetRouteAdapter] wrap GetX's own [GetPageRoute] instances with
/// [EasySplitGetPageRoute.from].
class EasySplitGetPageRoute<T> extends GetPageRoute<T> {
  EasySplitGetPageRoute._({
    required super.settings,
    required super.transitionDuration,
    required super.parameter,
    required super.gestureWidth,
    required super.curve,
    required super.alignment,
    required super.transition,
    required super.popGesture,
    required super.customTransition,
    required super.binding,
    required super.bindings,
    required super.routeName,
    required super.page,
    required super.title,
    required super.showCupertinoParallax,
    required super.barrierLabel,
    required super.maintainState,
    required super.middlewares,
    required super.fullscreenDialog,
  });

  /// Copies every GetX-specific field from [base].
  factory EasySplitGetPageRoute.from(GetPageRoute<T> base) {
    return EasySplitGetPageRoute<T>._(
      settings: base.settings,
      transitionDuration: base.transitionDuration,
      parameter: base.parameter,
      gestureWidth: base.gestureWidth,
      curve: base.curve,
      alignment: base.alignment,
      transition: base.transition,
      popGesture: base.popGesture,
      customTransition: base.customTransition,
      binding: base.binding,
      bindings: base.bindings,
      routeName: base.routeName,
      page: base.page,
      title: base.title,
      showCupertinoParallax: base.showCupertinoParallax,
      barrierLabel: base.barrierLabel,
      maintainState: base.maintainState,
      middlewares: base.middlewares,
      fullscreenDialog: base.fullscreenDialog,
    );
  }

  /// The left pane must keep painting below this route.
  @override
  bool get opaque => false;

  /// Taps outside the right pane must reach the left pane.
  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => false;

  @override
  Widget buildModalBarrier() => const SizedBox.shrink();

  /// Do not move the page below (the left pane) during transitions.
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
    return EasySplitPaneHitTest(
      child: EasySplitPaneTeleport(child: super.buildContent(context)),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Same reason as EasySplitRoute: lay out the transition, the framework's
    // gesture layer and the pane styling in one place, and neutralise the
    // secondary animation so the pane never parallaxes.
    return EasySplitPaneFrame(
      child: super.buildTransitions(
        context,
        animation,
        kAlwaysDismissedAnimation,
        child,
      ),
    );
  }
}
