import 'package:easy_split/easy_split.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'easy_split_get_page.dart';
import 'easy_split_get_page_route.dart';

/// Builds a `RouteFactory` for classic GetX named-route navigation.
///
/// ```dart
/// GetMaterialApp(
///   initialRoute: '/',
///   onGenerateRoute: easySplitGetRouteAdapter(pages: pages),
/// )
/// ```
///
/// Do **not** also pass `getPages` to [GetMaterialApp]: GetX swaps the whole
/// `onGenerateRoute` for its own generator when `getPages` is non-null.
/// For `GetMaterialApp.router` / `getPages`, use [EasySplitGetPage] instead.
///
/// [pages] are registered on [Get.routeTree] once, so `Get.toNamed`,
/// `Get.offNamed`, `Get.parameters` and route-specific middlewares keep
/// working. Fullscreen pages are those listed in
/// [EasySplitConfig.fullscreenRoutes], those with `fullscreenDialog` honored by
/// GetX, and [EasySplitGetPage]s created with `fullscreen: true`. Plain
/// `GetPage`s always keep their native full-screen route.
RouteFactory easySplitGetRouteAdapter({
  required List<GetPage> pages,
  GetPage? unknownRoute,
}) {
  _registerPages(pages);
  return (RouteSettings settings) {
    final route =
        PageRedirect(settings: settings, unknownRoute: unknownRoute).page();
    final String? name = settings.name;
    if (name == null) return route;

    if (EasySplit.isFullscreen(settings)) return route;

    final matched =
        Get.routeTree.matchRoute(name, arguments: settings.arguments).route;
    if (matched is! EasySplitGetPage) {
      // Plain GetPage: a normal full-screen route. The split host page
      // (usually `/home` wrapped in EasySplitScope) must stay native.
      return route;
    }
    if (matched.fullscreen) return route;

    return EasySplitGetPageRoute<dynamic>.from(route);
  };
}

void _registerPages(List<GetPage> pages) {
  final Set<String> registered = <String>{
    for (final GetPage page in Get.routeTree.routes) page.name,
  };
  for (final GetPage page in pages) {
    if (registered.add(page.name)) {
      Get.addPage(page);
    }
  }
}
