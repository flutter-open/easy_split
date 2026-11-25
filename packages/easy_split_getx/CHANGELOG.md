# Changelog

## 0.1.0

- Initial release.
- `EasySplitGetPageRoute`: a `GetPageRoute` subclass that renders into the right pane on wide
  screens (click-through left pane, pane-scoped `MediaQuery`, pane decoration and GetX transitions).
- `EasySplitGetPage`: a `GetPage` subclass for `GetMaterialApp.router` / Navigator 2.0 pages mode;
  `copy` is overridden so the page keeps its type after GetX resolves route parameters.
- `easySplitGetRouteAdapter`: `onGenerateRoute` adapter for classic `GetMaterialApp` named routes
  (`Get.toNamed`, `Navigator.pushNamed`).
- Fullscreen pages via `EasySplitGetPage(fullscreen: true)` or
  `EasySplit.config.fullscreenRoutes`.
