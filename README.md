# EasySplit - split-pane parallel view for foldables and wide screens

A Flutter implementation of the HarmonyOS "parallel view" idea: **one route stack - a folded
(narrow) screen stays a normal full-screen app, an unfolded (wide) screen automatically splits
into a left and a right pane.** Switching between the two only changes presentation; the route
stack never moves.

Pure adapter design: it does not extend `MaterialApp`, does not replace any methods, and composes
freely with `MaterialApp` (including `.router`), `CupertinoApp` and `Navigator.pages`.

## Installation

Requires Flutter 3.27+.

```yaml
dependencies:
  easy_split: ^0.1.1
```

## Setup

### 1. Wrap the bottom (list) page in `EasySplitScope` - you decide which page is the left pane

```dart
MaterialApp(
  home: EasySplitScope(child: RootPage()),
)
```

### 2. Route integration (pick one; page code stays untouched)

```dart
// Option 1: MaterialApp / CupertinoApp - onGenerateRoute
MaterialApp(
  home: const AdPage(),                                   // first screen (full screen)
  onGenerateRoute: EasySplit.routeAdapter({
    '/home': (_) => EasySplitScope(child: HomePage()),    // home chooses its own left pane
    '/detail': (_) => DetailPage(),
  }),
)

// Option 2: MaterialApp.router - RouterDelegate (pure Flutter, no third-party router)
// Pages keep using Navigator.pushNamed / pop / pushReplacementNamed, arguments via ModalRoute
final routerConfig = easySplitNativeRouterConfig(
  home: const AdPage(),                                   // full-screen first screen, not wrapped
  pageBuilders: {
    '/home': (_) => EasySplitScope(child: HomePage()),    // home chooses its own left pane
    '/detail': (_) => DetailPage(),
  },
);
MaterialApp.router(routerConfig: routerConfig)
```

> Create the option-2 `routerConfig` only once (top-level `final` or a `State` field). If it is built
> inside `build()`, every rebuild replaces the delegate and the `Navigator`, and the route stack is lost.

Other routing systems (`Navigator.pages`, etc.) can use `EasySplitPage(child: ..., name: ...)` as a
`Page`; it is backed by the same `EasySplitRoute`.

### 2.1 Duplicate-route deduplication (on by default)

Tapping the same list item repeatedly no longer pushes duplicate routes; the existing entry is
brought to the top instead.

| Integration | How to enable |
| --- | --- |
| Option 1, onGenerateRoute | Add `navigatorObservers: [EasySplit.dedupeObserver]` |
| Option 2, MaterialApp.router | **Automatic** (the delegate intercepts `pushNamed`) |

"Same page" means the same `name + arguments` by default, and can be customized:

```dart
EasySplit.config
  ..dedupeRepeatedRoutes = true                      // set to false to disable
  ..sameRoute = (a, b) => a.name == b.name && ...    // match by business id
```

> Only `Navigator.pushNamed` is intercepted; `pushReplacementNamed`, `pushNamedAndRemoveUntil` and
> `push` keep their native semantics.

### 3. Configuration: `EasySplit.config` (one wrapper)

```dart
EasySplit.config
  ..paneRatio = 0.45            // left/right ratio
  ..fullscreenRoutes.addAll({'/login'})  // immersive pages that stay full screen
  ..fullscreenRoutes.addAll({'/home'})   // when home is not the first route (splash -> replace -> home)
  ..placeholderBuilder = (ctx) => EmptyView()  // empty state of the right pane
  ..breakpoint = 600            // narrow/wide breakpoint
  ..layoutDelegate = (ctx) => ...  // custom split layout (left / right rectangles)
  ..paneDecoration = ...        // right-pane decoration
  ..isWideOverride = (ctx) => ...  // custom "unfolded" check (e.g. a real hinge)
  ..dedupeRepeatedRoutes = true  // bring duplicate routes to the top (default)
  ..sameRoute = (a, b) => ...    // custom "same page" check
```

Convenience accessors: `EasySplit.enabled` (runtime switch), `EasySplit.paneRatio`, etc.

Geometry-related settings (`paneRatio`, `breakpoint`, `layoutDelegate`, `layoutBuilder`) are not
reactive: call `EasySplit.updateLayout()` once after changing them, and the visible split re-lays
out immediately (the route stack stays put):

```dart
EasySplit.paneRatio = 0.35;   // or replace layoutDelegate
EasySplit.updateLayout();     // re-layout now
```

### 4. Parameter pass-through (route appearance / placeholder)

```dart
// Common appearance parameters for pane and full-screen routes (aligned with MaterialPageRoute)
EasySplitRoute(
  builder: (_) => const DetailPage(),
  maintainState: true,      // keep the state of covered pages
  fullscreenDialog: false,  // use the full-screen dialog transition
  allowSnapshotting: true,  // allow snapshots during the transition
  requestFocus: null,       // request focus automatically
  settings: const RouteSettings(name: '/detail'),
)

// Navigator.pages case
EasySplitPage(
  child: (_) => const DetailPage(), name: '/detail',
  fullscreen: false, maintainState: true, /* ...same as above */
)

// Each scope can provide its own right-pane placeholder (takes precedence over the global one)
EasySplitScope(
  placeholderBuilder: (_) => const EmptyView(),
  child: HomePage(),
)
```

With `MaterialApp.router` you can also pass through inner `Navigator` parameters:
`easySplitNativeRouterConfig(home: ..., pageBuilders: ..., observers: [...], onUnknownRoute: ...)`.

## Project layout

```
lib/easy_split.dart                      EasySplitConfig (configuration wrapper) + core API
lib/src/easy_split_pane_route.dart       EasySplitRoute / EasySplitPage
lib/src/easy_split_scope.dart            EasySplitScope split container
lib/src/easy_split_router_delegate.dart  EasySplitRouterDelegate (MaterialApp.router)
lib/src/easy_split_dedupe_observer.dart  EasySplitDedupeObserver (one-line dedupe for onGenerateRoute)
test/                                    35 behavior tests (gestures, routing, dedupe, params, live layout)
example/
  `-- lib/main.dart                       Option 1: MaterialApp onGenerateRoute
  `-- lib/main_1.dart                     Option 2: MaterialApp.router RouterDelegate
  `-- lib/pages.dart                      Shared demo pages
```

## How gesture pass-through works

A detail page inside the split is a real `PageRoute` with `opaque = false`; by nature it wants to
fill the whole screen and take over all gestures. EasySplit confines it to the right pane in three
layers:

1. **Visual layer**: `opaque = false` plus a zero-size `buildModalBarrier()` - the page underneath
   keeps painting and there is no full-screen scrim.
2. **Layout layer (the important one)**: `buildTransitions` first produces the native theme/platform
   transition and then wraps the whole transition subtree in `Padding + SizedBox` that shrinks it
   into `paneRect`.

   The output of `buildTransitions` always receives full-screen constraints inside the `Overlay`,
   and that is where the framework inserts its own gesture detectors - the most visible one being
   the iOS back-swipe hotspot of `CupertinoPageTransitionsBuilder`
   (`Stack[child, PositionedDirectional(start: 0, width: 20, child: Listener(...))]`, pinned to the
   route box's left edge). With a full-screen route box the hotspot lands on the screen's left edge,
   i.e. inside the left pane, which means:

   - swiping from the **screen's left edge** pops the right-pane detail (left pane gestures hijacked)
   - swiping from the **right pane's left edge** does nothing (the intuitive gesture fails)

   Shrinking the whole route into the pane moves the hotspot to the right pane's left edge, plays the
   transition inside the pane, and makes Cupertino's drag progress relative to the pane width
   (gesture and animation 1:1). Clipping hit tests in `buildContent` cannot reach this layer, so the
   position has to be fixed here.
3. **Hit-test fallback**: `_PaneHitTestScope` (`RenderProxyBox.hitTest`) converts the local position
   with `localToGlobal` and compares it with `paneRect`; outside the right pane it returns `false`, so
   the pointer falls through to the layer below. Even if a page paints outside its bounds (e.g. with
   an `OverflowBox`), it cannot block the left pane.

On a narrow/portrait screen (no split) the native route is passed through unchanged, exactly like a
`MaterialPageRoute`.

Regression coverage:

- `test/pane_route_gesture_test.dart` - left-pane taps/scrolls pass through, the right-pane content
  box equals `paneRect`, the iOS back-swipe hotspot is anchored to the right pane's left edge and does
  not fire in the left pane, narrow screens are full screen, the left pane stays interactive during a
  transition, pop/push round trips;
- `test/router_delegate_test.dart` - MaterialApp.router navigation on wide/narrow screens,
  `pushNamed`/`pop`/`pushReplacementNamed`/`pushNamedAndRemoveUntil`, `delegate.push`/`pop`, deep-link
  sync, dedupe, parameter pass-through;
- `test/dedupe_observer_test.dart` - the onGenerateRoute dedupe observer;
- `test/layout_update_test.dart` - changing `paneRatio` or a custom layout re-lays out immediately via
  `updateLayout()`, including a vertical split.

## Running the demo

```bash
cd example
flutter run -t lib/main.dart          # Option 1: onGenerateRoute
flutter run -t lib/main_1.dart        # Option 2: MaterialApp.router RouterDelegate
```

The switch in the top-right corner turns the adapter off at any time; the dropdown switches layout
mode (auto / custom / split off); "Split settings" switches between side-by-side, content on the
left, vertical and floating pane layouts and adjusts the pane ratio live (dragging re-lays out
immediately). Rotate the simulator (Cmd + arrow keys) to check folded/unfolded switching.

The demo also includes a simulated login gate: while logged out, every entry on the home page first
opens a mock login page (`/login`, full screen, never split); after logging in it continues to the
target page. The top-right corner lets you log out. The code lives in
`example/lib/pages.dart` (`DemoAuth`, `ensureLoggedIn`, `openProtected`).

## Design notes

- One route stack only = the native `Navigator`; `EasySplitRoute` differs in just five ways
  (`opaque = false`, no barrier, pass-through delegated transition, the whole route shrunk into the
  pane, adaptive content), so back gestures, system back and transitions are all native
- Gesture and hit-test boundaries: see "How gesture pass-through works" above - pointer handling and
  the route's own gesture layers are confined to the pane by **layout**; the hit-test clip is only a
  fallback
- Fold/unfold switching: the stack never moves; `EasySplitRoute` content adapts between "right-pane
  area" and "full screen"
- Orientation-aware safe areas: portrait avoids top/bottom, landscape avoids left/right; rotation
  updates through `MediaQuery`
- Hinge avoidance: `paneWidth` subtracts the hinge area from `displayFeatures`

## License

MIT
