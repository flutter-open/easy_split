# Changelog

## 0.1.1

- Documentation only: the package description, `README.md` and `CHANGELOG.md` are now written in English
  so the package follows pub.dev conventions.
- No API or behavior changes.

## 0.1.0

First public release.

### Features

- `EasySplitGoRoute`: a split-pane `GoRoute`; pages go to the right pane on wide screens and stay full
  screen on narrow ones, with zero page-code changes.
- Duplicate-route deduplication (on by default): pushing a page that is already in the stack converges the
  stack to the existing instance and brings it to the top while keeping its state. Can be disabled per route
  with `dedupe: false`, globally with `EasySplit.config.dedupeRepeatedRoutes = false`, or customized with
  `sameRoute`.
- `fullscreen` flag to keep a route always full screen (login, settings, ...).
- `redirect` / `onExit` / `caseSensitive` passthrough, so split pages keep route-level guards and
  leave-confirmation.
- Public deduplication helpers `easySplitDuplicateIndexOf(configuration, settings)` and
  `easySplitIsDuplicate(...)` for intercepting duplicates before a push with go_router 16.3+ `onEnter`
  (see `example/lib/main_on_enter.dart`).
- `easySplitDedupeAction(router, settings)` to bring an existing page to the top together with
  `Allow(then: ...)` in go_router 16.3+.
- The example uses `GoRouter(redirect:)` plus `refreshListenable` for login gating: unauthenticated
  navigation is redirected to `/login?from=...` and returns to the original target after login.
- Reuses the `easy_split` configuration and split-pane capabilities (`EasySplitScope`,
  `EasySplit.config.fullscreenRoutes`, `paneRatio`, ...).
- Works with go_router 13 and later (no upper bound; tested with 16.3.0 and 18.1.4).

### Known limitations

- Pages inside `ShellRoute` / `StatefulShellRoute` do not participate in deduplication.
- Only "push a new page" is handled; `go` / `replace` keep GoRouter's native semantics.
