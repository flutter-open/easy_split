# Changelog

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
