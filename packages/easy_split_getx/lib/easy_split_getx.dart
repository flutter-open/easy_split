/// GetX adapter for EasySplit.
///
/// Two entry points, matching GetX's two navigation modes:
///
/// * Classic named routes (`GetMaterialApp` + `Get.toNamed`): pass
///   [easySplitGetRouteAdapter] as `onGenerateRoute`. Do **not** pass
///   `getPages`, otherwise GetX replaces `onGenerateRoute` with its own
///   generator.
/// * Navigator 2.0 (`GetMaterialApp.router`): use [EasySplitGetPage] entries
///   in `getPages` and navigate with `Get.rootDelegate.toNamed`.
library;

export 'src/easy_split_get_page.dart';
export 'src/easy_split_get_page_route.dart';
export 'src/easy_split_get_route_adapter.dart';
