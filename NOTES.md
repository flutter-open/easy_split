# EasySplit 开发记录（问题与踩坑）

这份文档记录实现过程中实际遇到的问题、排查方式和最终结论，方便后来者（和未来的自己）少踩坑。
发文进度、版本变更见 [CHANGELOG.md](CHANGELOG.md)。

## 1. `RouterConfig` 必须同时提供 parser 与 provider

最初 `easySplitNativeRouterConfig` 只组装了 `routeInformationParser`，没给 `routeInformationProvider`，
`Router` 在 `initState` 里直接断言崩溃：

```
'package:flutter/src/widgets/router.dart': Failed assertion: line 148 pos 15:
'(routeInformationProvider == null) == (routeInformationParser == null)': is not true.
```

结论：两者要么都给，要么都不给。最终提供
`PlatformRouteInformationProvider(initialRouteInformation: RouteInformation(uri: Uri.parse(PlatformDispatcher.instance.defaultRouteName)))`。
另外 `RouteInformation.location` 已弃用，改为 `uri`（`parseRouteInformation` 取 `routeInformation.uri.path`）。

## 2. `MaterialApp.router` 方案下 `Navigator.pushNamed` 必须能直接用

最初 delegate 内部用声明式 `pages:` 构建 Navigator，没有 `onGenerateRoute`。页面里一句
`Navigator.pushReplacementNamed(context, '/home')` 就抛：

```
Navigator.onGenerateRoute was null, but the route named "/home" was referenced.
```

这正是需求的核心：**页面代码零改动**。最终把 delegate 改成返回一个普通的命令式
`Navigator(key: ..., onGenerateRoute: ...)`，初始路由 `/` 交给 `home`，其余名字查 `pageBuilders` 并用
`EasySplit.adaptRoute` 决定全屏还是分栏。`setNewRoutePath` 只负责深链同步，不参与页面栈的日常演进。

这样 `pushNamed` / `pop` / `pushReplacementNamed` / `pushNamedAndRemoveUntil` 全部是原生语义。

## 3. `addPostFrameCallback` 在测试里"永远不执行"

`setNewRoutePath` 里用 `WidgetsBinding.instance.addPostFrameCallback(...)` 延迟推路由，结果在
`testWidgets` 里调用 `pumpAndSettle()` 后什么也没发生。原因：

- 空闲时注册的 post-frame callback **不会**主动安排新帧；
- `pumpAndSettle` 只在 `hasScheduledFrame` 为真时才 `pump`。

所以回调一直挂到测试结束。结论：

- 启动阶段（Navigator 还没建出来）把 location 存进 `_pendingLocation`，在 `build()` 那一帧的 post-frame 里消费；
- 运行阶段（Navigator 已就绪）直接同步调用 `_syncRoute`。

教训：凡是"下一帧再做"的 UI 逻辑，测试里都要保证有帧被安排，或者干脆不依赖下一帧。

## 4. `pushReplacementNamed` 触发的是 `didReplace` 而不是 `didPush`

写测试断言 `NavigatorObserver.didPush` 收到了 `/home` 时得到 `Actual: ['/']`：
`pushReplacementNamed` 在内部走 `didReplace`。记录 observer 事件时两个回调都要覆盖。

## 5. 分栏路由是 `opaque=false`，测试里"看不见"的页面仍然在树上

`EasySplitRoute.opaque => false` 是分栏的核心（右栏只覆盖右半屏）。副作用：底下的页面从未离屏，
`find.text(...)` 仍然能找到，`find.byType(Scaffold)` 数量等于**栈深度**而不是"可见页数"。

教训：

- 不要用 `findsNothing` 断言被覆盖的页面；
- 用 `find.byType(Scaffold).evaluate().length` 作为栈深度的可靠代理。

## 6. iOS 侧滑热区必须靠 `buildTransitions` 定位置，`hitTest` 管不到

`CupertinoPageTransitionsBuilder` 会把 `Listener` 贴在**路由盒子**的左边，而这个盒子由
`buildTransitions` 产物在 Overlay 里决定。初始实现只在 `buildContent` 里做 hitTest 裁剪，结果：

- 从屏幕左缘右滑 → pop 的是右栏详情（左栏手势被劫持）
- 从右栏左缘右滑 → 没反应

最终在 `buildTransitions` 里把整棵转场子树套进 `Padding + SizedBox(paneRect)`，热区与动画随之下移到右栏；
`EasySplitPaneHitTest` 的 `localToGlobal` 比对只作为越界绘制的兜底。

## 7. `Page` 不能不带 key

早期声明式写法里 `EasySplitPage` 的 `key` 全是 null，`Page.canUpdate` 永远为 true，栈变化时 page 复用
完全靠类型猜。现在 delegate 走命令式 Navigator，`EasySplitPage` 仅作为 `Navigator.pages` / GoRouter
`pageBuilder` 的显式入口，`name`、`arguments` 都由调用方给出。

另外 `onPopPage` 在 3.16 之后已弃用，命令式 Navigator 不再需要它。

## 8. GoRouter 无法拦截 `push`，只能"入栈后收敛"

需求是"同一页面已在栈内则置顶"。但 GoRouter：

- `GoRouter.push` 直接调框架内部的 `RouteInformationProvider.push`，外部拿不到拦截点；
- `routeInformationProvider` 不可注入；
- `onEnter`（Allow/Block）只有 go_router 16.x 才有，而我们声明的是 `>=13.0.0`，不能抬门槛。

最终方案：`EasySplitGoRoute` 的 `pageBuilder` 里比对 `routerDelegate.currentConfiguration`，发现
"新页与栈内某页相同"就记录目标，在 post-frame 回调里连续 `router.pop()` 把中间页弹掉。

实现细节：

- 用 `Expando<RouteMatchList>` 按 `GoRouter` 实例记录"已检查过的配置"，避免 build 重建时反复调度；
- `didPush`/帧末回调都在路由栈变更过程中执行，直接同步 `removeRoute` 不安全，必须放到微任务/下一帧；
- `ShellRouteMatch` 直接跳过（子路由的 match 结构和普通页不同）。

## 9. `GoRouterState.of(context)` 在 `pageBuilder` 的 context 里会抛异常

探针测试里在 `pageBuilder` 的闭包内调用 `GoRouterState.of(context)`，得到：

```
There is no GoRouterState above the current context.
```

`GoRouterState` 是通过 `ModalRoute` + `GoRouterStateRegistryScope` 注入到**页面内部**的，`pageBuilder`
拿到的 context 在 page 之上，取不到。delegate 里统一用 `match.matchedLocation` 与 `match.matches.extra`
自行组装 `RouteSettings`，不依赖 `GoRouterState`。

## 10. Flutter 3.50 里 `AppBar` 不是 const 构造

测试里写 `const AppBar(title: Text('...'))` 编译失败：

```
Cannot invoke a non-'const' constructor where a const expression is expected.
```

改成 `AppBar(title: const Text('...'))`。

## 11. 不要用 Dart 3.14 的新格式化器整体 reformat

`dart format --set-exit-if-changed` 会想重排 `lib/easy_split.dart` 与测试文件，但这是 Dart 3.14 新
"tall style" 与仓库既有风格的差异，不是本次改动引入的。整体 reformat 会制造海量无关 diff，已刻意跳过。

## 12. 发布前的检查清单（本次踩到的）

- **path 依赖不能发布**：`easy_split_go_router` 对 `easy_split` 的 `path: ../../` 必须换成版本约束
  `^0.1.0`；本地开发用 `pubspec_overrides.yaml`（pub 不会发布该文件）继续走本地路径。
- **LICENSE / CHANGELOG 必须有**：pub.dev 要求每个包都有 `LICENSE` 与 `CHANGELOG.md`，否则 pana 扣分/拒绝。
- **description 长度 60–180 字符**：太短会报 warning，两个包的 description 都已按此调整。
- **`repository` 必填**：利于 pana 评分与来源校验，monorepo 子包指向子目录。
- **子包与主包的 `.pubignore` 冲突**：pub 会把仓库根的 ignore 规则按「仓库根相对路径」套用到子包发布上，所以根 `.pubignore` **不能**写 `packages/`（否则在 `packages/easy_split_go_router` 里 publish 时全部文件都会被隐藏）。取舍：主包发布会连同 `packages/` 子包源码一起打包（约 50 KB，不影响发布）；`.pubignore` 只排除 `NOTES.md` 与临时目录。
- 发布前用 `flutter pub publish --dry-run` 两个包各跑一遍，确认文件清单与告警。

## 13. GoRouter 的 redirect 只能返回地址字符串，`extra` 会在改道时丢失

给 demo 加登录拦截时，`GoRouter.redirect` 很适合统一做鉴权（配合 `refreshListenable` 监听登录态），
但它返回的是 location 字符串，没有 `extra` 通道：

- 目标页参数原来走 `context.push('/detail', extra: item)`，未登录被改道 `/login?from=/detail` 后，
  登录完成再 `push('/detail')`，`extra` 已丢失，`GoRouterState.of(context).extra` 为 null；
- 改成路径参数（`/detail/:index`）后，参数就是地址的一部分，`from` 里天然带着，
  登录页回来 `push(from)` 也能完整还原。`DetailPage` 改为读
  `GoRouterState.of(context).pathParameters['index']`。

另外：`onEnter`（允许/拦截导航）只有 go_router 16.3+ 才有，而本包支持 13 及以上，不能用；
`EasySplitGoRoute` 为此补了 `redirect` / `onExit` / `caseSensitive` 三个透传参数，
分栏页面同样能写路由级拦截。

## 14. `DemoAuth.login()` 和 `router.pop()` 写在同一帧，登录页会残留

GoRouter 示例的登录页最初是这么收尾的：

```dart
DemoAuth.login();        // refreshListenable 触发重新解析路由
router.pop();            // 同一帧执行的 pop
router.push(from);       // 回原目标页
```

结果登录页没被弹掉，还会叠在目标页下面，返回时又露出来（表现为“登录后又弹一次登录页”）。
原因是登录态变化触发的 refreshListenable 重解析与同帧的 `pop()` 相互覆盖，`pop()` 作用在了被
替换掉的旧路由上。

修法：
- 有 `from` 时用 `router.pushReplacement(from)` 直接把登录页替换成目标页（`/home` 仍在栈底）；
- 没有 `from` 时把 `pop()` 放进 `WidgetsBinding.instance.addPostFrameCallback`，等下一帧再关登录页。

## 15. 改了 `paneRatio` / `layoutDelegate` 分栏没变化

`EasySplit.config` 里的几何配置（`paneRatio`、`breakpoint`、`layoutDelegate`、`layoutBuilder`）
不是响应式的：`EasySplitScope` 与分栏路由的 `EasySplitPaneFrame` / `EasySplitPaneTeleport` 之前只监听
`EasySplit.enabled`，改比例不会触发重建，demo 里「选择分栏比例」看起来没生效。

修法：`EasySplitConfig` 增加 `layoutVersion`（`ValueNotifier<int>`），新增
`EasySplit.updateLayout()` 递增它；Scope 与分栏路由改用
`ListenableBuilder(listenable: Listenable.merge([enabled, layoutVersion]))`，
改完配置调用一次 `EasySplit.updateLayout()` 即可立即重排，且不重建路由栈。

另外：widget 测试环境的 CJK 回退字体把中文渲染得比真机宽不少，卡片里 `Row(Icon + Text)`
会溢出（`A RenderFlex overflowed`），真机上不明显但窄栏仍可能碰到，文本外层加 `Expanded`
更稳。

## 16. `onEnter` 里怎么"置顶已有页面"；以及它和 `refreshListenable` 一起用的坑

`onEnter` 是 go_router **16.3.0** 才有的（16.0–16.2 没有），在匹配、建页和 `redirect`
之前执行，`router.routerDelegate.currentConfiguration` 里**还没有**这次要 push 的页面，
所以能安全地用它判断「栈里是否已有同一页」。

踩到的坑（都在 `packages/easy_split_go_router/example/test/on_enter_dedupe_test.dart` 的
调试过程中复现过）：

- `Block.then(() { while (...) router.pop(); })` 里弹栈不可靠：block 的收尾阶段
  `pop()` 会把整个命令式栈收敛回栈底（探针里栈从 `[/home, /detail/0, /detail/1]` 变成
  `[/home]`），目标页反而丢失。
- 可行做法是 `Allow(then: action)`：先让这次 push 真正提交，再在回调里（`await
  Future.delayed(Duration.zero)` 之后）弹栈。回调里必须带两个保险，否则会"弹过头"：
  1. 只处理「确实追加了一页」的情况：进入回调前记下 `expectedLength = 旧长度 + 1`，
     回调里长度对不上就直接返回——因为 `pop()` 之后 go_router 会为恢复出来的地址再跑一次
     `onEnter`，那一轮并没有 push，处理它就会把栈继续弹空；
  2. 查找下标时**跳过栈顶**（刚压进来的新页面），只找它下面的同一页，然后
     `pop` 到「该页成为栈顶」为止。
  实测（`example/test/on_enter_dedupe_test.dart`）：`[/home, /detail/0, /detail/1]`
  再 push `/detail/0` → 最终 `[/home, /detail/0]`，页面 state 保留。
- 想用 `router.restore(RouteMatchList(matches: 裁剪后的列表, ...))` 直接改栈也不行：
  入参必须是一份完整、自洽的 match 列表，手搓出来的列表会让 `currentConfiguration.matches`
  变成空数组，路由直接黑屏。
- 登录页里「先 `DemoAuth.login()`（触发 `refreshListenable` 重解析）再
  `router.pushReplacement(from)`」在带 `onEnter` 的路由表上会把栈压成只剩目标页
  （`[/detail/0]`），因为重解析会先把登录页这条 imperative 路由收掉，`pushReplacement`
  于是替换到了栈底。该示例最终**不挂 `refreshListenable`**，登录/退出由登录页自己收尾；
  `redirect` 仍然负责下一次导航的拦截。

结论：
- 已在栈顶 → `Block.stop()`；在栈内但不在栈顶 → `Allow(then: easySplitDedupeAction(...))`；
- 公开函数：`easySplitDuplicateIndexOf` / `easySplitIsDuplicate` / `easySplitDedupeAction`；
- 不想自己接 `onEnter` 就用默认的 `dedupe: true`（pageBuilder + 帧末收敛），效果一致。

