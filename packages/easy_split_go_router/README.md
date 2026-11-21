# easy_split_go_router

[English](https://github.com/flutter-open/easy_split/blob/main/packages/easy_split_go_router/README.md) | [简体中文](https://github.com/flutter-open/easy_split/blob/main/packages/easy_split_go_router/README_CN.md)

GoRouter adapter for [EasySplit](https://pub.dev/packages/easy_split): replace a plain `GoRoute` with
`EasySplitGoRoute` to get automatic **side-by-side split on wide screens and full screen on narrow ones**,
with **built-in duplicate-route deduplication**. No page code changes: `context.push(...)` and
`context.pop()` keep working as usual.

- Depends only on `easy_split` and `go_router`; it does not change how you configure GoRouter.
- Deduplication is on by default: pushing a page that is already in the stack converges to that entry and
  keeps its state; can be disabled globally or per route.
- Works with go_router 13 and later (tested on 16.3.0 and 18.1.4); requires Flutter 3.27+.

## Install

```yaml
dependencies:
  easy_split: ^0.1.2
  easy_split_go_router: ^0.1.2
  go_router: ">=13.0.0"
```

## Quick start

```dart
import 'package:easy_split/easy_split.dart';
import 'package:easy_split_go_router/easy_split_go_router.dart';
import 'package:go_router/go_router.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    // First screen: a plain GoRoute, always full screen.
    GoRoute(path: '/', builder: (_, __) => const AdPage()),

    // Home page = left pane: wrap it in EasySplitScope explicitly, so it is
    // obvious which page is the left pane.
    GoRoute(
      path: '/home',
      builder: (_, __) => EasySplitScope(child: const HomePage()),
    ),

    // Secondary page: EasySplitGoRoute = right pane on wide, full screen on narrow.
    EasySplitGoRoute(path: '/detail', builder: (_, __) => const DetailPage()),
  ],
);

MaterialApp.router(routerConfig: router);
```

If the home page is not the initial route (splash/ad -> `context.go('/home')`), add it to the fullscreen
list so it behaves as a native full-screen page and creates the panes itself:

```dart
EasySplit.config.fullscreenRoutes.add('/home');
```

## Duplicate-route deduplication

On by default: after `/home -> /detail(a) -> /detail(b) -> /detail(a)` the stack only contains
`[home, detail(a)]`; going back returns to the home page directly and `detail(b)` is not pushed twice.

```dart
// Disable for a single route.
EasySplitGoRoute(path: '/detail', dedupe: false, builder: ...)

// Disable globally, or customize what counts as "the same page"
// (shared with the other easy_split integration schemes).
EasySplit.config
  ..dedupeRepeatedRoutes = false
  ..sameRoute = (a, b) => a.name == b.name && a.arguments == b.arguments;
```

How it works: GoRouter handles `push` inside its own `RouteInformationProvider`, which cannot be
intercepted from outside. `EasySplitGoRoute` therefore checks, while building the page, whether the new
page is already in the stack; if so, it collapses the intermediate pages with `router.pop()` before the
next frame. The result is the same as intercepting `Navigator.pushNamed`: the original page key stays and
its state is not rebuilt.

## Taking over deduplication with go_router 16.3+ `onEnter`

If your project already uses go_router **16.3.0+**, you can use `onEnter` to detect duplicates **before**
the page is pushed and bring the existing page **back to the top**. The library provides both the check
and the convergence:

```dart
GoRouter(
  redirect: myAuthGuard,
  onEnter: (context, current, next, router) {
    final settings = RouteSettings(
      name: next.matchedLocation,
      arguments: next.extra,
    );
    final config = router.routerDelegate.currentConfiguration;
    if (!easySplitIsDuplicate(config, settings)) {
      return const Allow();
    }
    // Already on top: block the push entirely.
    final action = easySplitDedupeAction(router, settings);
    if (action == null) {
      return const Block.stop();
    }
    // In the stack but not on top: allow the push, then drop the pages above
    // the existing one, so it becomes the top page again.
    return Allow(then: action);
  },
  routes: [
    // Deduplication is handled by onEnter; turn the built-in one off.
    EasySplitGoRoute(path: '/detail/:index', dedupe: false, builder: ...),
  ],
)
```

The three public helpers:

- `easySplitDuplicateIndexOf(configuration, settings)`: index of the same page in the stack (`-1` if absent);
- `easySplitIsDuplicate(configuration, settings)`: boolean shortcut honoring
  `EasySplit.config.dedupeRepeatedRoutes` / `sameRoute`;
- `easySplitDedupeAction(router, settings)`: callback that removes the intermediate pages and brings the
  existing one to the top; use it with `Allow(then: ...)`. Returns `null` when the page is already on top
  or no duplicate exists.

Notes:

- The callback runs after the navigation is committed, so there is a short "pushed, then removed on the
  next frame" intermediate state. For a state with no intermediate step, use the default `dedupe: true`
  (the page builder converges at the end of the frame, with the same result).
- Do not call `pop` directly inside `Block.then(...)`: popping during go_router's resolution phase
  collapses the whole imperative stack back to its root.
- `onEnter` is a `GoRouter` constructor parameter (not a `GoRoute` one), so the router must opt in as a whole.

A complete runnable example lives in `example/lib/main_on_enter.dart`
(`flutter run -t lib/main_on_enter.dart`, requires go_router >= 16.3.0).

## Route parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `builder` | required | `GoRouterWidgetBuilder`, same usage as `GoRoute.builder` |
| `name` / `path` / `routes` / `parentNavigatorKey` | - | forwarded to `GoRoute` |
| `fullscreen` | `false` | keep this page full screen (never split), e.g. login or settings |
| `dedupe` | `true` | whether this route participates in deduplication |
| `redirect` / `onExit` / `caseSensitive` | - | same meaning as on `GoRoute`, forwarded as-is; split pages support route-level guards and leave confirmation |

The appearance parameters of a pane route (`maintainState`, `fullscreenDialog`, `allowSnapshotting`,
`requestFocus`) come from the internal `EasySplitPage` and default to the same behavior as
`MaterialPageRoute`. To customize them, use `EasySplitPage(child: ..., name: ..., maintainState: ...)`
directly as the `pageBuilder` of a `GoRoute`.

## Login guard (example)

Let GoRouter's own `redirect` handle the authentication check, and call `context.push` directly from pages,
with no hand-written "login first, then navigate" logic:

```dart
final router = GoRouter(
  refreshListenable: auth.currentUser, // re-parse routes when the session changes
  redirect: (context, state) {
    if (!auth.isLoggedIn && state.matchedLocation.startsWith('/detail')) {
      return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    EasySplitGoRoute(path: '/detail/:index', builder: (_, __) => const DetailPage()),
  ],
);
```

When login completes, use `router.pushReplacement(from)` to replace the login page with the target page
(keeping the pages below it). Note that `redirect` can only return a location string, so the target
parameters must be path parameters (`/detail/:index`) rather than `extra`, otherwise they are lost when
the location is rewritten.

## Known limitations

- Pages inside `ShellRoute` / `StatefulShellRoute` do not participate in deduplication yet and keep their
  native behavior.
- Deduplication only handles pushing a new page; `context.go(...)` (whole-stack replacement) and
  `context.replace(...)` keep GoRouter's native semantics.

## Examples and tests

```bash
cd example
flutter run
```

`example/lib/main.dart` is the full ad page -> home -> detail -> dialogs demo. The login guard uses
GoRouter's `redirect` + `refreshListenable`: unauthenticated access to `/detail/:index`, `/secondary` or
`/dialogs` is redirected to `/login?from=...` and, after a successful login, the user lands back on the
original target (see `_guard` in `example/lib/main.dart` and `DemoAuth` / `LoginPage._finish` in
`pages.dart`). The "split settings" card switches between side-by-side, content-on-the-left, stacked and
floating layouts and adjusts the pane ratio at runtime (via `EasySplit.updateLayout()`, independent of the
routing scheme); `test/go_route_dedupe_test.dart` covers deduplication on wide and narrow screens, the
global switch, a custom `sameRoute` and per-route opt-out; `example/test/on_enter_dedupe_test.dart` covers
the `onEnter` interception variant.

## License

MIT

## ☕ Buy Me a Coffee

If easy_split_go_router has been helpful to you, you are welcome to buy me a coffee. Thank you for your support!

| Alipay | WeChat |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/flutter-open/resures-repository/master/docs/images/ali.jpg" width="260" alt="Alipay QR code" /> | <img src="https://raw.githubusercontent.com/flutter-open/resures-repository/master/docs/images/wechat.jpg" width="260" alt="WeChat QR code" /> |
