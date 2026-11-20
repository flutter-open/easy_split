# easy_split_go_router

[EasySplit](https://pub.dev/packages/easy_split) 的 GoRouter 适配：把普通 `GoRoute` 换成 `EasySplitGoRoute`，即可获得**宽屏自动左右分栏、窄屏全屏**，并内置**重复路由自动去重**。页面代码零改动，`context.push(...)` / `context.pop()` 照旧。

- 只依赖 `easy_split` 与 `go_router`，不修改 GoRouter 的配置方式
- 去重默认开启：栈里已有同一页面时再次 `push`，自动收敛到那一条（保留原页面状态），可全局或单条路由关闭
- 兼容 go_router 13 ~ 16，需要 Flutter 3.27+

## 安装

```yaml
dependencies:
  easy_split: ^0.1.0
  easy_split_go_router: ^0.1.0
  go_router: ">=13.0.0"
```

## 快速开始

```dart
import 'package:easy_split/easy_split.dart';
import 'package:easy_split_go_router/easy_split_go_router.dart';
import 'package:go_router/go_router.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    // 启动首屏：普通 GoRoute，永远全屏
    GoRoute(path: '/', builder: (_, __) => const AdPage()),

    // 首页 = 左栏：入口处显式包 EasySplitScope，一眼看到"谁是左栏"
    GoRoute(
      path: '/home',
      builder: (_, __) => EasySplitScope(child: const HomePage()),
    ),

    // 二级页：EasySplitGoRoute = 宽屏右栏 / 窄屏全屏
    EasySplitGoRoute(path: '/detail', builder: (_, __) => const DetailPage()),
  ],
);

MaterialApp.router(routerConfig: router);
```

首页不是启动首路由时（闪屏/广告 → `context.go('/home')`），把首页加入全屏名单，让它作为原生全屏页自己分栏：

```dart
EasySplit.config.fullscreenRoutes.add('/home');
```

## 重复路由去重

默认开启：`/home → /detail(a) → /detail(b) → /detail(a)` 之后，栈里只剩 `[home, detail(a)]`，返回直接回首页，`detail(b)` 不会被重复压栈。

```dart
// 单条路由关闭
EasySplitGoRoute(path: '/detail', dedupe: false, builder: ...)

// 全局关闭 / 自定义"同一页面"判定（与 easy_split 其他接入方式共用配置）
EasySplit.config
  ..dedupeRepeatedRoutes = false
  ..sameRoute = (a, b) => a.name == b.name && a.arguments == b.arguments;
```

实现方式：GoRouter 的 `push` 由框架内部的 RouteInformationProvider 处理，外部无法直接拦截，因此
`EasySplitGoRoute` 在生成页面时检测「新页面是否已在栈内」，若命中则在下一帧前用 `router.pop()`
把中间页收敛掉，效果与 `Navigator.pushNamed` 拦截一致，原页面 page key 不变、状态不重建。

## 用 go_router 16.3+ 的 `onEnter` 自己接管去重

如果你的项目已经升到 go_router **16.3.0+**，可以用 `onEnter` 在页面入栈**之前**判断重复，
并且命中时把已有页面「置顶」。判断与收敛都由库提供，不用自己写：

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
    // 已在栈顶：直接拦掉（不再压栈）。
    final action = easySplitDedupeAction(router, settings);
    if (action == null) {
      return const Block.stop();
    }
    // 页面在栈内但不在栈顶：先允许入栈，提交后把中间页收掉 → 已有页置顶。
    return Allow(then: action);
  },
  routes: [
    // 去重交给 onEnter，路由本身关掉内置去重
    EasySplitGoRoute(path: '/detail/:index', dedupe: false, builder: ...),
  ],
)
```

公开的三个函数：

- `easySplitDuplicateIndexOf(configuration, settings)`：返回栈内同一页的下标（没有则 `-1`）；
- `easySplitIsDuplicate(configuration, settings)`：布尔快捷版，遵守
  `EasySplit.config.dedupeRepeatedRoutes` / `sameRoute`；
- `easySplitDedupeAction(router, settings)`：返回「收掉中间页、已有页置顶」的回调，
  配合 `Allow(then: ...)` 使用；已在栈顶或没有重复时返回 `null`。

注意：

- 回调在导航提交之后执行，所以会有「先压栈、下一帧再收掉」的中间态；要完全没有中间态，
  请用默认的 `dedupe: true`（由 pageBuilder 在帧末收敛，效果一致）；
- 不要放进 `Block.then(...)` 里直接 `pop`：go_router 在解析阶段弹栈会把整个命令式栈收回栈底；
- `onEnter` 是 GoRouter 的构造参数（不是 `GoRoute` 的），需要整个 router 一起用。

完整可运行示例见 `example/lib/main_on_enter.dart`（`flutter run -t lib/main_on_enter.dart`，
需要 go_router >= 16.3.0）。

## 页面参数

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `builder` | 必填 | `GoRouterWidgetBuilder`，与 `GoRoute.builder` 用法一致 |
| `name` / `path` / `routes` / `parentNavigatorKey` | - | 透传给 `GoRoute` |
| `fullscreen` | `false` | 该页永远全屏（不参与分栏），如登录页、设置页 |
| `dedupe` | `true` | 是否参与重复路由去重 |
| `redirect` / `onExit` / `caseSensitive` | - | 与 `GoRoute` 同义，原样透传；分栏页同样能做路由级登录拦截、离开确认 |

分栏路由的外观参数（`maintainState`、`fullscreenDialog`、`allowSnapshotting`、`requestFocus`）
由内部 `EasySplitPage` 决定，默认与 `MaterialPageRoute` 行为一致；需要自定义时可直接使用
`EasySplitPage(child: ..., name: ..., maintainState: ...)` 作为 `GoRoute` 的 `pageBuilder`。

## 登录拦截（示例）

登录态校验交给 GoRouter 自己的 `redirect`，页面里直接 `context.push`，不需要手写“先登录再跳转”：

```dart
final router = GoRouter(
  refreshListenable: auth.currentUser, // 登录态变化立即重新解析路由
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

登录页完成后用 `router.pushReplacement(from)` 把登录页换成目标页（保留登录页下面的栈）即可；
注意 `redirect` 只能返回地址字符串，所以目标页参数要走路径参数（`/detail/:index`）而不是 `extra`，
否则改道时会丢。

## 已知限制

- `ShellRoute` / `StatefulShellRoute` 里的子页面暂不参与去重，保持原生行为。
- 去重只处理同一次「push 新页」的场景；`context.go(...)` 的整栈替换、`context.replace(...)` 保持 GoRouter 原生语义。

## 示例与测试

```bash
cd example
flutter run
```

`example/lib/main.dart` 是完整的广告页 → 首页 → 二级页 → 弹窗大全演示，登录拦截用 GoRouter 的
`redirect` + `refreshListenable` 实现：未登录访问 `/detail/:index`、`/secondary`、`/dialogs` 会自动改道
`/login?from=...`，登录成功后回到原目标（见 `example/lib/main.dart` 的 `_guard` 与 `pages.dart` 的
`DemoAuth`、`LoginPage._finish`），卡片上的「分栏设置」可实时切换左右分栏 / 内容在左 / 上下分栏 / 悬浮内容栏，并调整内容栏比例
（核心库 `EasySplit.updateLayout()`，与路由方案无关）；
`test/go_route_dedupe_test.dart` 覆盖宽/窄屏去重、全局关闭、自定义 `sameRoute`、单路由关闭；
`example/test/on_enter_dedupe_test.dart` 覆盖 `onEnter` 拦截版去重。

## License

MIT
