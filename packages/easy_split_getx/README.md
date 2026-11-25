# easy_split_getx

[English](https://github.com/flutter-open/easy_split/blob/main/packages/easy_split_getx/README.md) | [简体中文](https://github.com/flutter-open/easy_split/blob/main/packages/easy_split_getx/README_CN.md)

GetX adapter for [EasySplit](https://pub.dev/packages/easy_split): keep the **side-by-side split on
wide screens, full screen on narrow ones** behavior while keeping GetX's bindings, middleware,
transitions and route reporting intact.

- One `EasySplitGetPage` instead of `GetPage` for pages that should open in the right pane.
- Two integration modes: classic named routes (`GetMaterialApp` + `onGenerateRoute`) and
  Navigator 2.0 (`GetMaterialApp.router` + `getPages`).
- No page-code changes: pages keep using `Get.toNamed`, `Get.offNamed`, `Get.parameters`,
  `Get.back`, `Get.dialog`, etc.
- Requires Flutter 3.27+ and GetX 4.6.5+.

## Why an adapter is needed

GetX does not let an application replace the `Route` it creates:

- `Get.toNamed` / `Get.offNamed` in classic mode call `Navigator.pushNamed`, which reaches
  `GetMaterialApp.onGenerateRoute`. EasySplit already has `EasySplit.routeAdapter`, but it returns a
  plain `EasySplitRoute`; GetX's `PageRouteReportMixin`, middleware, bindings and transition mixin are
  lost, and `Get.currentRoute` stops tracking the page.
- `Get.to(() => page)` pushes a `GetPageRoute` directly, bypassing `onGenerateRoute` entirely.
- Navigator 2.0 builds pages through `GetPage.createRoute`, which also hardcodes `GetPageRoute`.

This package therefore provides a *subclass of `GetPageRoute`* (`EasySplitGetPageRoute`) that reuses
GetX's content/transition pipeline and only overrides the five things a pane route needs
(`opaque`, barrier, delegated transition, content wrapper, transition wrapper).

## Install

```yaml
dependencies:
  easy_split: ^0.2.1
  easy_split_getx: ^0.1.0
  get: ">=4.6.5 <5.0.0"
```

## Classic named routes

```dart
import 'package:easy_split/easy_split.dart';
import 'package:easy_split_getx/easy_split_getx.dart';
import 'package:get/get.dart';

final List<GetPage> pages = [
  GetPage(name: '/', page: () => const AdPage()),
  GetPage(
    name: '/home',
    page: () => const EasySplitScope(child: HomePage()), // left pane
  ),
  EasySplitGetPage(
    name: '/detail/:index',
    page: () => const DetailPage(),
    binding: DetailBinding(),
  ),
  EasySplitGetPage(name: '/secondary', page: () => const SecondaryPage()),
];

void main() {
  runApp(
    GetMaterialApp(
      initialRoute: '/',
      onGenerateRoute: easySplitGetRouteAdapter(pages: pages),
      // Optional: full-stack duplicate-route collapsing (same as EasySplit.routeAdapter).
      navigatorObservers: [EasySplit.dedupeObserver],
    ),
  );
}
```

> Do **not** pass `getPages` in this mode. When `getPages != null`, GetX replaces your
> `onGenerateRoute` with its internal generator, and the adapter is never called. Use
> `unknownRoute:` or the adapter's `unknownRoute` parameter for the fallback page.

Navigation stays unchanged:

```dart
Get.toNamed('/detail/1');
Get.parameters['index'];
Get.back();
```

## Navigator 2.0 (`GetMaterialApp.router`)

```dart
GetMaterialApp.router(
  getPages: [
    GetPage(name: '/', page: () => const AdPage()),
    GetPage(name: '/home', page: () => const EasySplitScope(child: HomePage())),
    EasySplitGetPage(name: '/detail/:index', page: () => const DetailPage()),
  ],
  unknownRoute: GetPage(name: '/not-found', page: () => const NotFoundPage()),
);
```

In this mode the `Navigator` is driven by `pages`, so navigate through the delegate:

```dart
Get.rootDelegate.toNamed('/detail/1');
Get.rootDelegate.offNamed('/home');
Get.rootDelegate.popRoute();
```

`Get.toNamed` uses `Navigator.pushNamed`, which is not compatible with a `pages`-driven Navigator;
do not mix the two in this mode.

`EasySplitGetPage.copy` is overridden on purpose: GetX's route tree calls `copy` while matching a
location, and the base `GetPage.copy` returns a plain `GetPage`, which would lose the pane route.

## Left pane, fullscreen pages and configuration

A plain `GetPage` always keeps a native full-screen route. That is exactly what the split host
(usually `/home`) needs, because `EasySplitScope` creates the panes itself:

```dart
GetPage(name: '/home', page: () => const EasySplitScope(child: HomePage()));
```

Only `EasySplitGetPage` is turned into a pane route, so the initial ad/splash page and `/home` do not
need any fullscreen configuration. Keep a pane page full screen on all widths with either mechanism:

```dart
// Per page.
EasySplitGetPage(name: '/login', page: () => const LoginPage(), fullscreen: true);

// Or globally (checked for EasySplitGetPage routes).
EasySplit.config.fullscreenRoutes.add('/login');
```

All other configuration (`breakpoint`, `paneRatio`, `paneDecoration`, `layoutDelegate`,
`placeholderBuilder`, ...) is the core EasySplit configuration and is unchanged:

```dart
EasySplit.config
  ..breakpoint = 600
  ..paneRatio = 0.5
  ..enabled.value = true;
EasySplit.updateLayout(); // after geometry changes
```

## What is preserved

- `Bindings` / `Get.put` / `Get.lazyPut`: `EasySplitGetPageRoute` extends `GetPageRoute`, so
  `buildContent` still runs GetX's `_getChild()` pipeline (bindings, `onPageBuildStart`, ...).
- `GetMiddleware`: classic mode goes through `PageRedirect.page()` (same as GetX), Navigator 2.0
  through `GetDelegate`; `redirect` / `onPageCalled` / `onBindingsStart` keep working.
- Transitions: `GetPageRouteTransitionMixin` still builds the transition; the pane wrapper is applied
  around it, so the iOS back-gesture area moves into the right pane instead of the screen edge.
- `Get.currentRoute` and `RouterReportManager`: `PageRouteReportMixin` is inherited, so route
  reporting and GetX's route-dependent logic keep working.
- `Get.dialog`, `Get.bottomSheet`, `Get.snackbar`: untouched; overlays still cover the whole window.

## Duplicate routes

- Classic mode: add `navigatorObservers: [EasySplit.dedupeObserver]` (the same observer used by
  `EasySplit.routeAdapter`). It honors `EasySplit.config.dedupeRepeatedRoutes` / `sameRoute` and
  collapses intermediate duplicates.
- Navigator 2.0: GetX's own `preventDuplicates` only checks the current (top) page. Full-stack
  collapsing is not provided by this adapter yet.

## Known limitations

- `Get.to(() => widget)` creates a plain `GetPageRoute`; it cannot be intercepted and will always be
  full screen. Use named routes (`EasySplitGetPage`) for pages that should split.
- `Get.offAllNamed`, `Get.until` and `Get.offUntil` keep their native GetX semantics.
- Shell/ nested navigators are not specially handled; only routes on the root navigator are adapted.
- The pane content relies on the public `EasySplitPaneFrame` / `EasySplitPaneTeleport` /
  `EasySplitPaneHitTest` widgets added in easy_split 0.2.1.

## Examples and tests

```bash
cd example
flutter run                 # classic named routes
flutter run -t lib/main_router.dart  # Navigator 2.0
flutter test
```

- `example/lib/main.dart`: `GetMaterialApp` + `onGenerateRoute` adapter.
- `example/lib/main_router.dart`: `GetMaterialApp.router` + `getPages`.
- `example/lib/pages.dart`: shared demo pages (left pane home, detail with a `Binding`, dialogs,
  fullscreen page).
- `test/easy_split_getx_test.dart`: route construction, fullscreen, `copy`, adapter behavior.
- `example/test/navigation_test.dart`: both modes, pane preservation and fullscreen behavior.
