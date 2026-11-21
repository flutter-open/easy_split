# easy_split_go_router

[English](https://github.com/flutter-open/easy_split/blob/main/packages/easy_split_go_router/README.md) | [简体中文](https://github.com/flutter-open/easy_split/blob/main/packages/easy_split_go_router/README_CN.md)

[EasySplit](https://pub.dev/packages/easy_split) 的 GoRouter 适配器：把普通的 `GoRoute` 换成
`EasySplitGoRoute`，即可获得**宽屏自动左右分屏、窄屏全屏**，并**内置重复路由去重**。页面代码
无需改动：`context.push(...)` 和 `context.pop()` 照常使用。

- 只依赖 `easy_split` 和 `go_router`，不改变你配置 GoRouter 的方式。
- 去重默认开启：压入一个已在栈中的页面时，会收敛到该条目并保留其状态；可以全局或按路由关闭。
- 兼容 go_router 13 及以上（已在 16.3.0 和 18.1.4 上测试）；要求 Flutter 3.27+。

## 安装

```yaml
dependencies:
  easy_split: ^0.1.2
  easy_split_go_router: ^0.1.2
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
    // 首个页面：普通 GoRoute，始终全屏。
    GoRoute(path: '/', builder: (_, __) => const AdPage()),

    // 首页 = 左窗格：显式用 EasySplitScope 包住，左窗格显示哪个页面一目了然。
    GoRoute(
      path: '/home',
      builder: (_, __) => EasySplitScope(child: const HomePage()),
    ),

    // 二级页面：EasySplitGoRoute = 宽屏在右窗格，窄屏全屏。
    EasySplitGoRoute(path: '/detail', builder: (_, __) => const DetailPage()),
  ],
);

MaterialApp.router(routerConfig: router);
```

如果首页不是初始路由（闪屏/广告页之后 `context.go('/home')`），把它加入全屏路由列表，让它像
原生全屏页面一样工作并自行创建窗格：

```dart
EasySplit.config.fullscreenRoutes.add('/home');
```

## 重复路由去重

默认开启：`/home -> /detail(a) -> /detail(b) -> /detail(a)` 之后，栈中只保留
`[home, detail(a)]`；返回会直接回到首页，`detail(b)` 不会被重复压栈。

```dart
// 对单条路由关闭。
EasySplitGoRoute(path: '/detail', dedupe: false, builder: ...)

// 全局关闭，或自定义「同一页面」的判断（与 easy_split 的其他集成方式共享）。
EasySplit.config
  ..dedupeRepeatedRoutes = false
  ..sameRoute = (a, b) => a.name == b.name && a.arguments == b.arguments;
```

实现原理：GoRouter 在自己的 `RouteInformationProvider` 内部处理 `push`，外部无法拦截。因此
`EasySplitGoRoute` 在构建页面时检查新页面是否已在栈中；若已在，就在下一帧之前用 `router.pop()`
收敛掉中间页面。效果与拦截 `Navigator.pushNamed` 相同：原页面的 key 保留，状态不会重建。

## 使用 go_router 16.3+ 的 `onEnter` 接管去重

如果项目已经使用 go_router **16.3.0+**，可以用 `onEnter` 在页面被压入**之前**识别重复并把已有
页面**提到栈顶**。库同时提供了判断和收敛能力：

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
    // 已经在栈顶：直接阻止这次压栈。
    final action = easySplitDedupeAction(router, settings);
    if (action == null) {
      return const Block.stop();
    }
    // 在栈中但不在栈顶：允许压栈，然后移除已有页面上方的页面，
    // 让它重新成为栈顶页面。
    return Allow(then: action);
  },
  routes: [
    // 去重已由 onEnter 处理，关闭内置去重。
    EasySplitGoRoute(path: '/detail/:index', dedupe: false, builder: ...),
  ],
)
```

三个公开辅助函数：

- `easySplitDuplicateIndexOf(configuration, settings)`：同一页面在栈中的下标（不存在时为 `-1`）；
- `easySplitIsDuplicate(configuration, settings)`：布尔快捷判断，遵循
  `EasySplit.config.dedupeRepeatedRoutes` / `sameRoute`；
- `easySplitDedupeAction(router, settings)`：移除中间页面并把已有页面提到栈顶的回调，配合
  `Allow(then: ...)` 使用。页面已在栈顶或不存在重复时返回 `null`。

注意事项：

- 回调在导航提交之后执行，因此会存在一个短暂的「先压入、下一帧再移除」的中间状态。若希望没有
  中间步骤，请使用默认的 `dedupe: true`（页面构建器在帧末收敛，结果相同）。
- 不要在 `Block.then(...)` 里直接调用 `pop`：在 go_router 的解析阶段 pop 会把整个命令式路由栈
  收敛回根页面。
- `onEnter` 是 `GoRouter` 的构造参数（不是 `GoRoute` 的），因此必须整个路由器一起启用。

完整可运行示例见 `example/lib/main_on_enter.dart`
（`flutter run -t lib/main_on_enter.dart`，要求 go_router >= 16.3.0）。

## 路由参数

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `builder` | 必填 | `GoRouterWidgetBuilder`，用法与 `GoRoute.builder` 相同 |
| `name` / `path` / `routes` / `parentNavigatorKey` | - | 透传给 `GoRoute` |
| `fullscreen` | `false` | 该页面保持全屏（永不分屏），例如登录页或设置页 |
| `dedupe` | `true` | 该路由是否参与去重 |
| `redirect` / `onExit` / `caseSensitive` | - | 含义与 `GoRoute` 上相同，原样透传；分屏页面支持路由级守卫和离开确认 |

窗格路由的外观参数（`maintainState`、`fullscreenDialog`、`allowSnapshotting`、`requestFocus`）
来自内部的 `EasySplitPage`，默认行为与 `MaterialPageRoute` 一致。需要自定义时，直接把
`EasySplitPage(child: ..., name: ..., maintainState: ...)` 用作 `GoRoute` 的 `pageBuilder`。

## 登录拦截（示例）

让 GoRouter 自己的 `redirect` 负责登录校验，页面里直接调用 `context.push`，无需手写「先登录、
再跳转」的逻辑：

```dart
final router = GoRouter(
  refreshListenable: auth.currentUser, // 会话变化时重新解析路由
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

登录完成后，用 `router.pushReplacement(from)` 把登录页替换为目标页面（保留下层页面）。注意
`redirect` 只能返回位置字符串，因此目标参数必须是路径参数（`/detail/:index`）而不是 `extra`，
否则位置被重写时参数会丢失。

## 已知限制

- `ShellRoute` / `StatefulShellRoute` 内的页面暂不参与去重，保持原生行为。
- 去重只处理压入新页面的场景；`context.go(...)`（整栈替换）和 `context.replace(...)` 保持
  GoRouter 的原生语义。

## 示例与测试

```bash
cd example
flutter run
```

`example/lib/main.dart` 是完整的「广告页 -> 首页 -> 详情页 -> 对话框」示例。登录拦截使用
GoRouter 的 `redirect` + `refreshListenable`：未登录访问 `/detail/:index`、`/secondary` 或
`/dialogs` 会被重定向到 `/login?from=...`，登录成功后回到原目标页面（见
`example/lib/main.dart` 中的 `_guard` 以及 `pages.dart` 中的 `DemoAuth` / `LoginPage._finish`）。
「Split settings」卡片可在并排、内容在左、垂直和悬浮窗格布局之间切换，并在运行时调整窗格比例
（通过 `EasySplit.updateLayout()`，与路由方案无关）；`test/go_route_dedupe_test.dart` 覆盖宽屏
与窄屏去重、全局开关、自定义 `sameRoute` 和按路由关闭；`example/test/on_enter_dedupe_test.dart`
覆盖 `onEnter` 拦截方案。

## 许可证

MIT

## ☕ 请我喝咖啡

如果这个项目帮到了你，欢迎请我喝杯咖啡，感谢你的支持！

| 支付宝 | 微信 |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/flutter-open/resures-repository/master/docs/images/ali.jpg" width="260" alt="支付宝收款码" /> | <img src="https://raw.githubusercontent.com/flutter-open/resures-repository/master/docs/images/wechat.jpg" width="260" alt="微信收款码" /> |
