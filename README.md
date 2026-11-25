# EasySplit - split-pane parallel view for foldables and wide screens

[English](https://github.com/flutter-open/easy_split/blob/main/README.md) | [简体中文](https://github.com/flutter-open/easy_split/blob/main/README_CN.md)

A Flutter implementation of the HarmonyOS "parallel view" idea: **one route stack - a folded
(narrow) screen stays a normal full-screen app, an unfolded (wide) screen automatically splits
into a left and a right pane.** Switching between the two only changes presentation; the route
stack never moves.

Pure adapter design: it does not extend `MaterialApp`, does not replace any methods, and composes
freely with `MaterialApp` (including `.router`), `CupertinoApp` and `Navigator.pages`.

## Demo

A narrow (folded) screen stays full screen; unfold it and the same route stack splits into a left
list and a right detail pane:

![EasySplit demo - folded screen stays full screen, unfolded screen splits into two panes](https://raw.githubusercontent.com/flutter-open/resures-repository/master/docs/images/easy_split.gif)

## Installation

Requires Flutter 3.27+.

```yaml
dependencies:
  easy_split: ^0.2.0
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

GetX users can use the [easy_split_getx](packages/easy_split_getx/) adapter instead of
`EasySplit.routeAdapter`: it keeps GetX bindings, middleware, transitions and route reporting. See the
[classic named-route](packages/easy_split_getx/README.md#classic-named-routes) and
[Navigator 2.0](packages/easy_split_getx/README.md#navigator-20-getmaterialapprouter) setups.

### 2.1 Duplicate-route deduplication (on by default)

Tapping the same list item repeatedly no longer pushes duplicate routes; the existing entry is
brought to the top instead.

| Integration | How to enable |
| --- | --- |
| Option 1, onGenerateRoute | Add `navigatorObservers: [EasySplit.dedupeObserver]` |
| Option 2, MaterialApp.router | **Automatic** (the delegate intercepts `pushNamed`) |
| easy_split_getx, classic mode | Add `navigatorObservers: [EasySplit.dedupeObserver]` |

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

### 5. Inside a pane, "the screen" is the pane

EasySplit injects a **pane-scoped `MediaQuery`**, so inside the left pane and the right pane:

- `MediaQuery.sizeOf(context)` / `MediaQuery.of(context).size` is the pane size;
- `MediaQuery.orientationOf(context)` follows the pane;
- `padding` / `viewPadding` are already reduced by the safety insets the pane applied.

Percentage widths, grids, spacing factors and aspect ratios therefore adapt to the pane width -
**no page code changes**.

What intentionally stays window-based (otherwise the split itself would break):

- `EasySplit.isWide`, `EasySplit.layoutOf`, `EasySplit.paneWidth`, `EasySplit.paneContentInsets`
  keep computing from the whole window, so the breakpoint is never decided by the pane size;
- dialogs / bottom sheets opened from a pane still use the window size (they live in the overlay).

#### ScreenUtil

ScreenUtil does not read `MediaQuery`: `ScreenUtil.init(context)` and `ScreenUtilInit` go through
`View.maybeOf(context)` + `MediaQueryData.fromView(view)`, i.e. always the whole window. Forward the
pane data once in `main()` - pages stay untouched:

```dart
void main() {
  EasySplit.config.onPaneMediaQuery = (data) => ScreenUtil.configure(
        data: data,
        designSize: const Size(375, 812), // your design size
        splitScreenMode: false, // ScreenUtil late fields: pass them explicitly
        minTextAdapt: false,    // on the first configure call
      );
  runApp(const App());
}
```

Notes:

- `splitScreenMode` / `minTextAdapt` are late fields inside ScreenUtil: the **first** `configure`
  call must pass them explicitly, otherwise a pane building before `ScreenUtilInit` throws
  `LateInitializationError`;
- the callback fires synchronously while a pane builds - do not call `setState` inside it;
- ScreenUtil is a global singleton: with both panes visible the pane built last wins;
- after you change your own scaling settings, call `EasySplit.updateLayout()` so visible panes
  report again.

#### Custom layouts

With `EasySplit.config.layoutBuilder` the pane size is derived from the real constraints, so pages
still see their own size. To build the same data yourself, use `EasySplit.paneMediaQuery`:

```dart
final data = EasySplit.paneMediaQuery(
  MediaQuery.of(context),              // window data
  Rect.fromLTWH(0, 0, 600, 800),       // your pane rect
  insets: const EdgeInsets.only(top: 24),
);
```

## Project layout

```
lib/easy_split.dart                      EasySplitConfig (configuration wrapper) + core API
lib/src/easy_split_pane_route.dart       EasySplitRoute / EasySplitPage
lib/src/easy_split_scope.dart            EasySplitScope split container
lib/src/easy_split_router_delegate.dart  EasySplitRouterDelegate (MaterialApp.router)
lib/src/easy_split_dedupe_observer.dart  EasySplitDedupeObserver (one-line dedupe for onGenerateRoute)
lib/src/easy_split_window.dart           Window metrics + pane-scoped MediaQuery (internal)
test/                                    47 behavior tests (gestures, routing, dedupe, params, live layout, pane size)
packages/easy_split_go_router/            go_router adapter (separate package)
packages/easy_split_getx/                 GetX adapter (separate package, classic + Navigator 2.0)
packages/easy_split_demo/                Demo pages shared by both example entries
  `-- lib/src/pages.dart                 Demo screens (ad, home, detail, dialogs)
  `-- lib/src/demos.dart                 TabBar home + pane-width demo
  `-- lib/src/setup.dart                 Shared route table, ScreenUtil wiring, theme
example/
  `-- lib/main.dart                       Option 1: MaterialApp onGenerateRoute
  `-- lib/main_1.dart                     Option 2: MaterialApp.router RouterDelegate
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
3. **Hit-test fallback**: `EasySplitPaneHitTest` (`RenderProxyBox.hitTest`) converts the local position
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
`packages/easy_split_demo/lib/src/pages.dart` (`DemoAuth`, `ensureLoggedIn`, `openProtected`).

The example also ships a bottom-tabbar home page (`packages/easy_split_demo/lib/src/demos.dart`,
`TabsHomePage`; reachable
from the ad page and from the home list) that doubles as the walkthrough for pane-aware layouts:

- four bottom tabs: counter / scroll / input / width;
- folding or unfolding keeps the current tab, the counter, the scroll offset and the typed text;
- the **width** tab shows pane size vs window size, 100 / 50 / 25% blocks, a responsive grid and
  ScreenUtil (`.w` / `.sp`) values - all computed from the pane width.

No foldable is needed: the unfold icon in the app bar forces "folded / unfolded" through
`EasySplit.config.isWideOverride`, which runs exactly the same code path as a real fold on a phone.

To land directly on it (handy for screenshots or CI), pass the example-only switches - both entry
files support them:

```bash
cd example
# TabBar home, unfolded (two panes)
flutter run -t lib/main.dart \
  --dart-define=EASYSPLIT_FORCE_MODE=wide \
  --dart-define=EASYSPLIT_START_ROUTE=/tabs-home \
  --dart-define=EASYSPLIT_START_TAB=3

# TabBar home, folded
flutter run -t lib/main_1.dart --dart-define=EASYSPLIT_START_ROUTE=/tabs-home
```

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

## ☕ Buy Me a Coffee

If EasySplit has been helpful to you, you are welcome to buy me a coffee. Thank you for your support!

| Alipay | WeChat |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/flutter-open/resures-repository/master/docs/images/ali.jpg" width="260" alt="Alipay QR code" /> | <img src="https://raw.githubusercontent.com/flutter-open/resures-repository/master/docs/images/wechat.jpg" width="260" alt="WeChat QR code" /> |

