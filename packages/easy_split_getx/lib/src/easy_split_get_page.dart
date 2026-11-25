import 'package:easy_split/easy_split.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'easy_split_get_page_route.dart';

/// A [GetPage] that creates an [EasySplitGetPageRoute] on wide screens.
///
/// Use it for `GetMaterialApp.router` (`getPages`) / Navigator 2.0 pages mode.
/// In classic named-route mode (`GetMaterialApp` + `onGenerateRoute`) use
/// [easySplitGetRouteAdapter] instead, because GetX ignores `onGenerateRoute`
/// as soon as `getPages` is provided.
///
/// ```dart
/// GetMaterialApp.router(
///   getPages: [
///     GetPage(name: '/home', page: () => const EasySplitScope(child: HomePage())),
///     EasySplitGetPage(name: '/detail/:id', page: () => const DetailPage()),
///   ],
/// )
/// ```
class EasySplitGetPage<T> extends GetPage<T> {
  /// Creates a pane-aware GetX page.
  ///
  /// [fullscreen] keeps this page fullscreen on every window size (native
  /// [GetPageRoute]); it is equivalent to adding [name] to
  /// [EasySplitConfig.fullscreenRoutes].
  EasySplitGetPage({
    required super.name,
    required super.page,
    super.title,
    super.participatesInRootNavigator,
    super.gestureWidth,
    super.maintainState = true,
    super.curve = Curves.linear,
    super.alignment,
    super.parameters,
    super.opaque = true,
    super.transitionDuration,
    super.popGesture,
    super.binding,
    super.bindings = const [],
    super.transition,
    super.customTransition,
    super.fullscreenDialog = false,
    super.children = const <GetPage>[],
    super.middlewares,
    super.unknownRoute,
    super.arguments,
    super.showCupertinoParallax = true,
    super.preventDuplicates = true,
    this.fullscreen = false,
  });

  /// `true` = always fullscreen, never split.
  final bool fullscreen;

  @override
  Route<T> createRoute(BuildContext context) {
    final Route<T> route = super.createRoute(context);
    if (fullscreen || EasySplit.isFullscreen(this)) return route;
    if (route is GetPageRoute<T>) return EasySplitGetPageRoute<T>.from(route);
    return route;
  }

  /// GetX's `ParseRouteTree.matchRoute` copies every page while resolving path
  /// parameters, and the base implementation returns a plain [GetPage] — which
  /// would silently drop the pane route. Keep the subtype (and [fullscreen]).
  @override
  EasySplitGetPage<T> copy({
    String? name,
    GetPageBuilder? page,
    bool? popGesture,
    Map<String, String>? parameters,
    String? title,
    Transition? transition,
    Curve? curve,
    Alignment? alignment,
    bool? maintainState,
    bool? opaque,
    Bindings? binding,
    List<Bindings>? bindings,
    CustomTransition? customTransition,
    Duration? transitionDuration,
    bool? fullscreenDialog,
    RouteSettings? settings,
    List<GetPage>? children,
    GetPage? unknownRoute,
    List<GetMiddleware>? middlewares,
    bool? preventDuplicates,
    double Function(BuildContext context)? gestureWidth,
    bool? participatesInRootNavigator,
    Object? arguments,
    bool? showCupertinoParallax,
  }) {
    return EasySplitGetPage<T>(
      name: name ?? this.name,
      page: page ?? this.page,
      popGesture: popGesture ?? this.popGesture,
      parameters: parameters ?? this.parameters,
      title: title ?? this.title,
      transition: transition ?? this.transition,
      curve: curve ?? this.curve,
      alignment: alignment ?? this.alignment,
      maintainState: maintainState ?? this.maintainState,
      opaque: opaque ?? this.opaque,
      binding: binding ?? this.binding,
      bindings: bindings ?? this.bindings,
      customTransition: customTransition ?? this.customTransition,
      transitionDuration: transitionDuration ?? this.transitionDuration,
      fullscreenDialog: fullscreenDialog ?? this.fullscreenDialog,
      children: children ?? this.children,
      unknownRoute: unknownRoute ?? this.unknownRoute,
      middlewares: middlewares ?? this.middlewares,
      gestureWidth: gestureWidth ?? this.gestureWidth,
      preventDuplicates: preventDuplicates ?? this.preventDuplicates,
      participatesInRootNavigator:
          participatesInRootNavigator ?? this.participatesInRootNavigator,
      arguments: arguments ?? this.arguments,
      showCupertinoParallax:
          showCupertinoParallax ?? this.showCupertinoParallax,
      fullscreen: fullscreen,
    );
  }
}
