# Changelog

## Unreleased

### Fixed

- Duplicate-route deduplication now compares `RouteSettings.arguments` by content instead of by
  reference. `Map` / `List` arguments are compared recursively (nested maps such as `headerMap`
  included), so pushing the same page with a freshly built but equal argument map — e.g. tapping
  the same H5 link twice, or a go_router `extra` map — is deduplicated again. The comparison is
  budgeted (12 levels / 256 nodes) and fails closed (treated as different) on deeper, oversized or
  self-referencing arguments, so it can neither mis-dedupe nor overflow the stack. The same default
  is used by `EasySplit.dedupeObserver`, `EasySplitRouterDelegate` and `easy_split_go_router`, and is
  exposed as `easySplitSameRoute` / `easySplitArgumentsEqual`.

## 0.2.1

### Added

- Exposed the pane route building blocks as public widgets so router adapters can reuse them:
  `EasySplitPaneHitTest` (left-pane click-through), `EasySplitPaneFrame` (pane positioning /
  transitions) and `EasySplitPaneTeleport` (pane decoration, insets and pane-scoped `MediaQuery`).
  `EasySplitRoute` and `EasySplitPage` behaviour is unchanged; the widgets were previously private
  (`_PaneHitTestScope`, `_PaneFrame`, `_PaneTeleport`).
- `EasySplitPage` and `EasySplitRoute` accept `key`, `transitionsBuilder`, `transitionDuration` and
  `reverseTransitionDuration`, so router adapters (such as `easy_split_go_router`'s `pageBuilder`
  support) can carry over custom page transitions into the pane.

## 0.2.0

### Fixed

- Folding or unfolding no longer resets the pages' state. `EasySplitScope`, `_PaneFrame` and
  `_PaneTeleport` keep an identical widget structure in narrow and wide mode (only layout
  parameters change), so pages are reused: a tabbed home page keeps its current tab, scroll
  offsets, text fields and counters after expanding. Custom `layoutBuilder` layouts keep their
  state through a stable `GlobalKey`.
- Regression tests: `test/layout_state_test.dart` (5 cases).

### Added

- Pane-scoped `MediaQuery`: inside the left and right panes `MediaQuery.sizeOf(context)` is the pane
  size, orientation follows the pane and padding is already reduced by the pane's safety insets, so
  percentage widths, grids and scaling adapt to the pane width without page code changes.
- `EasySplit.paneMediaQuery(parent, paneRect, {insets})` to build the same data for custom layouts.
- `EasySplitConfig.onPaneMediaQuery` callback to forward the pane size to solutions that read the
  raw `FlutterView` instead of `MediaQuery` (e.g. ScreenUtil).
- Regression tests: `test/pane_media_query_test.dart` (7 cases).

### Changed

- `EasySplit.isWide` / `layoutOf` / `paneWidth` / `paneContentInsets` still compute from the whole
  window, so the breakpoint is never decided by the pane size. Dialogs and bottom sheets stay
  window-sized (they live in the overlay).

### Upgrade

- No breaking changes; page code does not change.
- ScreenUtil users add one line in `main()`, otherwise `.w` / `.sp` keep using the whole window:

  ```dart
  EasySplit.config.onPaneMediaQuery = (data) => ScreenUtil.configure(
        data: data,
        designSize: const Size(375, 812), // your design size
        splitScreenMode: false, // late fields: pass them on the first configure()
        minTextAdapt: false,
      );
  ```

- If a page deliberately needs the window size, read it from your own `MediaQuery` or use
  `EasySplit.isWide` / `layoutOf` / `paneWidth`.

Problem write-ups (symptoms, root cause, regression tests): [`doc/fixes.md`](doc/fixes.md).

## 0.1.2

- Documentation only: the English/Chinese switch at the top of the README now uses absolute GitHub
  links, so it is clickable on pub.dev as well as on GitHub.
- No API or behavior changes.

## 0.1.1

- Documentation only: the package description, `README.md` and `CHANGELOG.md` are now written in English
  so the package follows pub.dev conventions.
- Added a Chinese README (`README_CN.md`) with a language switcher between the English and Chinese
  versions, and a "Buy Me a Coffee" section in both.
- No API or behavior changes.

## 0.1.0

First public release.

### Features

- Parallel-view split layout: a single route stack; narrow screens stay full screen, wide screens split into
  left/right panes automatically, and folding/unfolding only changes presentation, never the stack.
- Routing integration:
  - `EasySplit.routeAdapter({...})` for `MaterialApp` / `CupertinoApp` `onGenerateRoute`
  - `easySplitNativeRouterConfig(home:, pageBuilders:)` for `MaterialApp.router` (built-in
    `Navigator.pushNamed` / `pop` support, deep-link sync, `observers` / `onUnknownRoute` passthrough)
  - `EasySplitPage(child:, name:)` for `Navigator.pages` and other `Page`-based routing
  - `EasySplitRoute(builder:)` to build a pane route manually
- Duplicate-route deduplication (on by default): pushing a page that is already in the stack brings the
  existing instance to the top instead of stacking a duplicate. Configurable with
  `EasySplit.config.dedupeRepeatedRoutes` / `sameRoute`; the `onGenerateRoute` setup needs one line:
  `navigatorObservers: [EasySplit.dedupeObserver]`.
- Live layout updates: after changing `paneRatio` / `breakpoint` / `layoutDelegate` / `layoutBuilder`,
  call `EasySplit.updateLayout()` once and visible panes re-layout immediately without touching the stack.
  The demo card also has a "split settings" dialog to switch between side-by-side, content-on-the-left,
  stacked and floating layouts and to change the pane ratio.
- Gesture pass-through: `opaque = false` plus a zero-size barrier, a transition subtree inset to `paneRect`
  and `hitTest` clipping, so taps/scrolls on the left pane are not captured by the right-pane route, and the
  iOS back-swipe hot zone stays anchored to the left edge of the pane.
- Parameter passthrough: `maintainState`, `fullscreenDialog`, `allowSnapshotting`, `requestFocus` and
  `settings` on `EasySplitRoute` / `EasySplitPage`; `EasySplitScope.placeholderBuilder`; `fullscreen` to
  force a full-screen page.
- Configuration through `EasySplit.config`: `paneRatio`, `breakpoint`, `fullscreenRoutes`,
  `placeholderBuilder`, `layoutDelegate`, `layoutBuilder`, `paneDecoration`, `isWideOverride` and the
  `enabled` toggle.
- Hinge and safe-area support: `paneWidth` excludes the `displayFeatures` hinge area (top/bottom in
  portrait, left/right in landscape).

### Known limitations

- Deduplication only intercepts `Navigator.pushNamed`; `pushReplacementNamed`, `pushNamedAndRemoveUntil` and
  `push` keep their native semantics.
- Pane routes are not opaque, so covered pages remain in the widget tree (consistent with native
  `PageRoute` behavior; keep this in mind when writing test assertions).
