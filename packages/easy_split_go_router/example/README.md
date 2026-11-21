# easy_split_go_router_example

`easy_split_go_router` 的演示工程：用 GoRouter 接入 EasySplit，演示**宽屏自动分栏**、
**登录拦截（redirect）** 和 **重复路由去重** 的两种实现方式。

> 这是 demo，不发布到 pub.dev。包本身的说明见
> [easy_split_go_router](https://pub.dev/packages/easy_split_go_router)。

## 两个入口

| 入口 | 去重方式 | 说明 |
| --- | --- | --- |
| `lib/main.dart` | `EasySplitGoRoute` 内置（`dedupe: true`） | 默认推荐，go_router 13 及以上可用；重复 push 时在帧末收敛并把已有页面置顶 |
| `lib/main_on_enter.dart` | go_router 16.3+ 的 `onEnter` + `easySplitIsDuplicate` / `easySplitDedupeAction` | 在入栈前判断重复：已在栈顶直接拦掉，栈内已有则入栈后收敛为「置顶」 |

```bash
flutter run -t lib/main.dart            # 内置去重
flutter run -t lib/main_on_enter.dart   # onEnter 拦截（需要 go_router >= 16.3.0）
```

本示例的 `pubspec.yaml` 把 go_router 约束在 `>=16.3.0`（为了 `onEnter`）；
库包本身支持 `>=15.0.0 <19.0.0`。工作区里通过 `pubspec_overrides.yaml` 把
`easy_split` 指向本仓库的本地路径。

宽屏（≥600 且横屏）时首页作为左栏，`/detail/:index`、`/secondary`、`/dialogs`
进入右栏；窄屏时这些页面全屏。`/home`、`/login` 是全屏路由，不参与分栏。

## Demo 里能看到什么

`lib/pages.dart`：

- **广告页 `AdPage`**：3 秒后或点按钮进入首页；
- **首页 `HomePage`**（左栏）：右上角登录按钮，下面是「分栏设置」卡片、登录状态卡片和内容列表；
- **登录拦截**：`GoRouter(redirect: _guard)` 在未登录访问 `/detail`、`/secondary`、`/dialogs`
  时改道 `/login?from=<原地址>`；登录页完成后回到原目标页。页面里直接
  `context.push('/detail/2')`，不写"先登录再跳转"；
- **去重**：连点同一个列表项不会反复压栈。`main.dart` 由 `EasySplitGoRoute` 内置逻辑收敛，
  `main_on_enter.dart` 由 `onEnter` 在入栈前拦截；
- **分栏设置**：`DemoSplitLayout` 提供四种布局（左右分栏 / 内容在左 / 上下分栏 / 悬浮内容栏），
  可拖动滑块调整内容栏占比，立即生效（`EasySplit.updateLayout()`）；
- **一级页 `DetailPage`**：用路径参数 `/detail/:index` 取列表项，显示当前登录用户，可进二级页；
- **二级页 `SecondaryPage`**、**弹窗大全 `DialogsPage`**。

## 测试

```bash
flutter test
```

- `test/demo_layout_test.dart`：分栏设置弹窗的四种布局、比例拖动、恢复默认；
- `test/on_enter_dedupe_test.dart`：`onEnter` 拦截版——登录后进入详情页、重复 push 同一页不压栈、
  不同页面正常压栈。

## 换到自己的项目

```dart
GoRouter(
  redirect: myAuthGuard, // 可选
  routes: [
    GoRoute(path: '/home', builder: (_, __) => EasySplitScope(child: HomePage())),
    EasySplitGoRoute(path: '/detail/:id', builder: (_, __) => DetailPage()),
  ],
)
```

首页不是启动首路由时，记得 `EasySplit.config.fullscreenRoutes.add('/home')`。
用 `onEnter` 接管去重的完整写法见包 README 的「用 go_router 16.3+ 的 `onEnter` 自己接管去重」。
