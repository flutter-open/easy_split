# 分栏适配：非 go_router 跳转 / 浮层 落地指南

> 面向「分栏适配排查清单」的执行方。目标：让宽屏分栏时，本该进右栏的页面进右栏，本该整窗的页面
> 明确整窗，浮层不再按整窗布局。本文所有代码都可直接抄。

## 0. 先明确一件事：SDK 不能自动接管

EasySplit 只接管**经过路由表**的页面（`EasySplitGoRoute` / `EasySplitPage` / `EasySplit.routeAdapter`）。
以下三类入口 SDK 拿不到，宽屏时只能整窗显示：

| 类型 | 典型写法 | 能否自动接管 |
| --- | --- | --- |
| A | `context.push('/xxx')` / `pushNamed('/xxx')`，`/xxx` 在 `EasySplitGoRoute` 路由表里 | ✅ 已接管 |
| B | `Navigator.pushNamed('/xxx')`，`/xxx` 只登记在 `onGenerateRoute` | ⚠️ 需要 `EasySplit.routeAdapter` 或改成 A |
| C | `Navigator.push(MaterialPageRoute(...))` / `Navigator.push(PageRouteBuilder(...))`，没有 name | ❌ 永远整窗，必须逐点改 |
| D | `OverlayEntry` / 面板内自绘浮层 | ❌ 按整窗布局，需要按栏约束 |

原因是 C 类路由在入栈时就已经定型（没有 name、也没有 easy_split 的 route 包装），事后从
`NavigatorObserver` 里改不了——路由内容不可访问，替换会破坏 `push` 的 Future、转场和返回栈。
所以策略是**逐点收口**，而不是找统一钩子。

## 1. 第一步：开审计，把所有漏网点找出来

```dart
final router = GoRouter(
  routes: [...],
  observers: [EasySplit.auditObserver], // debug 下才生效
);
```

> go_router 16 的参数名是 `observers:`（老版本为 `navigatorObservers:`），以工程实际版本为准。

之后每次跳转到「SDK 接管不了的路由」，控制台会出现：

```
[easy_split] 裸路由入栈（分栏无法接管，宽屏下将整窗全屏）：name=/ad, type=MaterialPageRoute<dynamic>。
请改用 EasySplitGoRoute / EasySplit.routeAdapter / EasySplitPage 建路由，或把该路由加入
EasySplit.fullscreenRoutes 明确声明为全屏。
```

把清单里的每一条都走一遍，日志即为「实际漏网列表」，和清单互相印证。
如果某个页面**本来就该整窗**（广告页、登录页、引导蒙层、loading），把它登记掉，告警即消失：

```dart
EasySplit.config.fullscreenRoutes.addAll(<String>{'/ad', '/login', '/splash'});
```

注意 `fullscreenRoutes` 是**精确匹配**（`Set.contains`），带 query 的地址（`/webview?url=...`）匹配不上，
这类页面用下一页的 `fullscreen:` 参数，不要靠白名单。

## 2. 参数化页面：一条 `/webview` 路由吃掉所有 H5 入口

清单里 12 个入口（#4 #5 #6 #7 #8 #13 #14 #18 #19 #20 #21 #22）本质是同一个 WebView 页，
只是 url / header 不同。**不要**给每个入口建一条路由，统一成一条 + `extra`：

```dart
// 1) 参数类：必须实现值相等，否则「同 url + 同 header」去重不命中
class WebViewArgs {
  const WebViewArgs({
    required this.url,
    this.title = 'H5',
    this.headers = const <String, String>{},
    this.fullscreen = false, // 支付/风控等必须整窗的入口
  });

  final String url;
  final String title;
  final Map<String, String> headers;
  final bool fullscreen;

  static WebViewArgs fromExtra(Object? extra) =>
      extra is WebViewArgs ? extra : const WebViewArgs(url: 'https://example.com/empty');

  @override
  bool operator ==(Object other) =>
      other is WebViewArgs &&
      other.url == url &&
      other.title == title &&
      other.fullscreen == fullscreen &&
      mapEquals(other.headers, headers);

  @override
  int get hashCode => Object.hash(url, title, fullscreen,
      Object.hashAllUnordered(headers.entries.map((e) => Object.hash(e.key, e.value))));
}
```

```dart
// 2) 路由表：用 go_router 的 GoRoute + pageBuilder，内部返回 EasySplitPage
GoRoute(
  path: '/webview',
  pageBuilder: (BuildContext context, GoRouterState state) {
    final WebViewArgs args = WebViewArgs.fromExtra(state.extra);
    return EasySplitPage<void>(
      name: state.uri.toString(),
      arguments: args,
      fullscreen: args.fullscreen, // 不走白名单，见上一节说明
      child: (_) => FlutterWebViewPage(args: args),
    );
  },
),
```

```dart
// 3) 导航层收口：业务只调这一个方法
Future<T?> openWebView<T>(BuildContext context, WebViewArgs args, {bool replace = false}) {
  if (replace) {
    context.pushReplacement('/webview', extra: args); // go_router 16 返回 void
    return Future<T?>.value();
  }
  return context.push<T>('/webview', extra: args);
}
```

调用点改造（把原来的 `Navigator.push(route: JdeCupertinoPageRoute(builder: ...))` 换成）：

```dart
openWebView(context, WebViewArgs(
  url: url,
  headers: headerMap,
  fullscreen: isPayOrRiskControl,
));
```

**为什么参数必须放 `extra`**：go_router 的 `matchedLocation` 是拼出来的路径，**不含 query**；
easy_split 的去重身份是 `{name: matchedLocation, arguments: extra}`。参数放 query 有两个后果：
所有 `/webview` 页面 name 相同、arguments 都是 null → 只要 url 不同就永远不去重，或者只要
`sameRoute` 自定义不当就误去重。放 `extra` 后：url 不同 → arguments 不同 → 正常叠页；
url + header 都相同 → 自动去重（SDK 默认按内容深比较，嵌套 header Map 也覆盖）。

## 3. 独立页面：需要分栏就建路由，需要整窗就标 fullscreen

清单里 #17 商品识别、#23 桌面组件 FAQ 是独立页面，按产品意图二选一：

```dart
// 进右栏（默认）：直接 GoRouter 路由 + EasySplitGoRoute
EasySplitGoRoute(
  path: '/goods/recognize',
  builder: (_, __) => const GoodsRecognizePage(),
),

// 必须全屏（例如带全屏弹层、摄像头预览按窗格尺寸不生效）
EasySplitGoRoute(
  path: '/goods/recognize',
  fullscreen: true,
  pageBuilder: (_, __) => EasySplitPage(
    fullscreenDialog: true, // 保留原来的模态转场
    child: (_) => const GoodsRecognizePage(),
  ),
),
```

需要自定义转场（原来 #23 是 `FadeTransition`）就传 `transitionsBuilder`：

```dart
EasySplitGoRoute(
  path: '/desktop/faq',
  pageBuilder: (_, __) => EasySplitPage(
    transitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    child: (_) => const DeskTopFAQWidget(),
  ),
),
```

## 4. 浮层：按栏约束，或挂到页面自己的 Stack

**根 Overlay 的浮层永远在所有路由之上**，这是 Overlay 的语义，改不了。所以先判断浮层该在哪一层：

| 场景 | 做法 |
| --- | --- |
| 浮层属于「当前页面」（如 #2 二楼底导遮罩、#9 引导蒙层） | 挂到该页面自己的 `Stack`（`Positioned.fill(child: ...)`），随页面一起被限制在栏内 |
| 浮层是全局的、但只需盖住某一栏（如 #3 揭层、单独遮罩） | `EasySplit.showPaneOverlay(side: ...)` |

```dart
// 全局浮层，贴右栏；缩放/折叠时自动重排，栏外点击穿透
final OverlayEntry entry = EasySplit.showPaneOverlay(
  context,
  side: EasySplitPaneSide.right, // 左栏首页用 left
  builder: (_) => MyMask(onClose: () => entry.remove()),
);
// 关闭：entry.remove()
```

```dart
// 页面内浮层：随页面被裁到栏内，不需要 SDK
Stack(
  children: <Widget>[
    pageContent,
    if (showMask) const Positioned.fill(child: MyMask()),
  ],
)
```

`EasySplit.paneOverlayEntry` 只创建不插入，适合需要自己控制 `Overlay.of(...).insert` 的场景；
`EasySplitPaneOverlay` 是底层 widget，可以包进已有 `OverlayEntry` 的 builder。

## 5. 混合栈的两个必改点

### 5.1 `popUntil((r) => r.isFirst)` → `router.go('/')`

`Navigator.popUntil` 直接动 Navigator 的栈，go_router 的 match list 不会同步：之后 `context.pop()`、
`GoRouter.canPop`、`easySplitDuplicateIndexOf`、深链同步都会错位（表现为「返回一次没反应」或
「返回到了错误的页面」）。

```dart
// 旧
Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
// 新
context.go('/home'); // 或 router.go('/')
```

对应清单 #11 #12。

### 5.2 页面内的 `Navigator.pop()` → `context.pop()`

路由化之后页面在 go_router 的栈里，直接 `Navigator.pop` 同样会让 match list 失步。页面里的
「返回」「关闭」按钮统一改成 `context.pop()`（`easy_split_go_router` 已依赖 go_router，无需额外引入）。

## 6. 逐条改造清单

编号沿用排查清单（2026-11-25）的条目号，方便逐条对照打勾。

| # | 位置 | 现状 | 改法 |
| --- | --- | --- | --- |
| 1 | `lib/feature/home/widgets/recommend_pull_region.dart:553-571` | 二楼 `PageRouteBuilder` + `rootNavigator.push` | 产品若接受整窗：保持不动 + 登记 fullscreen；要求分栏：建 `/refresh-down` 路由，用 `EasySplitPage(transitionsBuilder: 上滑)` |
| 2 | 同文件 `:367-396` | 二楼底导遮罩 `OverlayEntry(rootOverlay)` | 挂到二楼页面自己的 `Stack`；不要用 root Overlay（会盖住右栏页面） |
| 3 | `lib/feature/home/widgets/top_action_widget.dart:295-302` | 一键寄万物-CN 揭层 | `EasySplit.showPaneOverlay(side: right)` |
| 4 | 同文件 `:305-313` | 一键寄万物-非CN → FlutterWebView | `openWebView(...)` |
| 5 | 同文件 `:619-627` | 地址编辑 → FlutterWebView(addressEdit) | `openWebView(...)` |
| 6 | `lib/feature/holder/main_holder_page.dart:740-749` | 广告页跳转 `h5JumpUrl` | `openWebView(...)`；若为首页首屏广告则该页本身登记 fullscreen |
| 7 | `lib/page/holder_page.dart:947-956` | 广告页旧入口 | 同 #6；确认旧入口是否已废弃，废弃则删 |
| 8 | `lib/feature/home/widgets/coupon_banner/coupon_buy_dialog.dart:687-692` | 优惠券支付 → FlutterWebView(payUrl) | `openWebView(..., fullscreen: true)` |
| 9 | `main_holder_page.dart:127-141` | 引导蒙层 OverlayEntry | 页面内 `Stack`（通常该页整窗，保持 fullscreen） |
| 11 | `main_holder_page.dart:549` | `popUntil` 回首页 | `context.go('/home')` |
| 12 | `holder_page.dart:1084` | `popUntil` 回首页 | `context.go('/home')` |
| 13 | `jde_base_package/login/utils/utils.dart:228-231` | 登录成功 `pushReplacement` → FlutterWebView(redirectURL) | `openWebView(..., replace: true)` |
| 14 | `jde_base_package/login/superapp/superapp_login_sheet.dart:931-936` | 登录面板跳转 | `openWebView(...)` |
| 17 | `jde_base_package/channels/route_channel.dart:128-135` | 商品识别 `JdeCupertinoPageRoute(fullscreenDialog)` | 建 `/goods/recognize` 路由；用 `EasySplitPage(fullscreenDialog: true)` 保留模态转场 |
| 18 | `jde_base_package/widgets/login_gesture_detector.dart:160-169` | 跳 FlutterWebView | `openWebView(...)` |
| 19 | `jde_base_package/web/jssdk/handlers/navigation_handler.dart:179-189` | JSSDK `openNewWebView` | `openWebView(...)` |
| 20 | 同文件 `:355-367` | JSSDK routeAction open | `openWebView(...)` |
| 21 | 同文件 `:318-319` | JSSDK `pushReplacement` | `openWebView(..., replace: true)` |
| 22 | `.../second_express_handler.dart:111-120` | 二次寄递 → FlutterWebView | `openWebView(...)` |
| 23 | `jde_base_package/widgets/desktop_widget/desktop_bottom_sheet_widget.dart:168` | 桌面 FAQ `PageRouteBuilder` Fade | 建 `/desktop/faq` 路由 + `EasySplitPage(transitionsBuilder: FadeTransition)` |
| 24 | `desktop_bottom_sheet_widget.dart:31-54` | 嵌套 Navigator + MaterialPageRoute | 保留（独立 Navigator 无法分栏）；若要分栏需把嵌套栈改成 go_router 子路由 |
| 26–29 | `jde_home_package`：coupon_activity_widget:211、coupon_buy_dialog:684、home_base_gestureDetector:149、search_head_widget:316-321 | 旧代码 | 先确认是否死代码：是则删，否则按同类改法（WebView 用 `openWebView`，MessagePage 建路由） |

> 行号以清单日期为准，改造时以审计日志核对。

## 7. 验收

1. 打开 `EasySplit.auditObserver`，把清单涉及的入口全部点一遍：除已登记 fullscreen 的路由外，
   不应再有告警。
2. 宽屏（≥ 宽屏断点且横屏）逐条验证：目标页出现在右栏、左栏仍可滚动/点击、返回手势正常。
3. 窄屏折叠态逐条验证：页面整窗显示，行为与改造前一致。
4. 去重：同一 H5 连点两次只保留一页；不同 header 正常叠两层；`context.pop()` 能逐层返回。
5. 浮层：宽屏下只盖住目标栏，缩放窗口后自动重排，栏外点击穿透（纯遮罩加 `ignorePointer: true`）。
6. 混合栈：`context.go('/home')` 之后 `context.pop()` 不会错位；深链进 `/webview` 能直接打开。

## 8. 参考实现

- 可运行最小示例：`packages/easy_split_go_router/example/lib/main_mixed.dart`
  （`flutter run -t lib/main_mixed.dart`），覆盖参数化页 + 去重 + 整窗 + 双栏浮层 + 裸 push 告警；
- 对应测试：`packages/easy_split_go_router/example/test/mixed_navigation_test.dart`；
- 参数与 API 说明：根 README「混合导航：go_router 之外的 push 与浮层」、
  `packages/easy_split_go_router/README.md`「混合导航」。
