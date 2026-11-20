# easy_split_example

`easy_split` 的演示工程：同一套 demo 页面，分别用 **onGenerateRoute** 和
**MaterialApp.router** 两种方式接入分栏，页面代码完全不用改。

> 这是 demo，不发布到 pub.dev。库本身的说明见 [easy_split](https://pub.dev/packages/easy_split)。

## 两个入口

| 入口 | 接入方式 | 说明 |
| --- | --- | --- |
| `lib/main.dart` | `MaterialApp(onGenerateRoute: EasySplit.routeAdapter({...}))` | 最简接入，配合 `navigatorObservers: [EasySplit.dedupeObserver]` 获得重复路由去重 |
| `lib/main_1.dart` | `MaterialApp.router(routerConfig: easySplitNativeRouterConfig(...))` | 页面里仍是 `Navigator.pushNamed / pop`，`routerConfig` 只创建一次；去重已内置 |

```bash
flutter run -t lib/main.dart     # 方案一：onGenerateRoute
flutter run -t lib/main_1.dart   # 方案二：MaterialApp.router
```

宽屏（≥600 且横屏）自动左右分栏：首页是左栏，`/detail`、`/secondary`、`/dialogs`
进入右侧内容栏；窄屏时内容页全屏。`/home`、`/login` 在 `fullscreenRoutes` 里，作为全屏页自己分栏。

## Demo 里能看到什么

`lib/pages.dart`：

- **广告页 `AdPage`**：3 秒后或点按钮 `pushReplacementNamed('/home')` 进入首页；
- **首页 `HomePage`**（左栏）：右上角是登录按钮，下面是「分栏设置」卡片和内容列表；
- **登录拦截**：未登录时点首页任意入口，会先进入模拟登录页 `/login`（全屏、不分栏），
  登录成功后再进入目标页。相关代码是 `DemoAuth` / `ensureLoggedIn` / `openProtected`，
  纯本地模拟，不发请求；
- **分栏设置**：`DemoSplitLayout` 提供四种布局（左右分栏 / 内容在左 / 上下分栏 / 悬浮内容栏），
  可拖动滑块调整内容栏占比，立即生效且不重建路由栈（`EasySplit.updateLayout()`）；
- **一级页 `DetailPage`**：显示列表项内容、当前登录用户，可继续进二级页；
- **二级页 `SecondaryPage`**、**弹窗大全 `DialogsPage`**（分栏里的系统弹窗效果）。

卡片上的「开始 / 停止分屏适配」可随时关闭适配回到原生单栏；「分栏设置」里可以切换四种布局并调整内容栏占比。

## 测试

```bash
flutter test
```

`test/demo_layout_test.dart` 覆盖分栏设置弹窗：切换四种布局、拖动比例、恢复默认。

## 换到自己的项目

把 `lib/main.dart` 或 `lib/main_1.dart` 里的接线方式抄走，再把你自己的路由表塞进
`EasySplit.routeAdapter({...})` / `pageBuilders: {...}` 即可。更多配置见库的 README。
