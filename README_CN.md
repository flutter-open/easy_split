# EasySplit - 折叠屏与宽屏的左右分屏并行视图

[English](https://github.com/flutter-open/easy_split/blob/main/README.md) | [简体中文](https://github.com/flutter-open/easy_split/blob/main/README_CN.md)

这是 HarmonyOS「平行视界」思路的 Flutter 实现：**只维护一个路由栈——折叠（窄）屏仍然是普通的
全屏应用，展开（宽）屏则自动分成左右两个窗格。** 两种状态之间切换只改变呈现方式，路由栈本身
不移动。

纯适配器设计：不继承 `MaterialApp`、不重写任何方法，可以与 `MaterialApp`（包括 `.router`）、
`CupertinoApp` 和 `Navigator.pages` 自由组合。

## 演示

折叠（窄）屏保持全屏展示；展开后同一个路由栈自动分成左侧列表与右侧详情两个窗格：

![EasySplit 演示 - 折叠屏保持全屏，展开后自动左右分栏](https://raw.githubusercontent.com/flutter-open/resures-repository/master/docs/images/easy_split.gif)

## 安装

要求 Flutter 3.27+。

```yaml
dependencies:
  easy_split: ^0.1.2
```

## 接入步骤

### 1. 用 `EasySplitScope` 包住底部（列表）页面——左窗格显示哪个页面由你决定

```dart
MaterialApp(
  home: EasySplitScope(child: RootPage()),
)
```

### 2. 路由集成（二选一，页面代码保持不变）

```dart
// 方式一：MaterialApp / CupertinoApp - onGenerateRoute
MaterialApp(
  home: const AdPage(),                                   // 首个页面（全屏）
  onGenerateRoute: EasySplit.routeAdapter({
    '/home': (_) => EasySplitScope(child: HomePage()),    // 首页自己决定左窗格
    '/detail': (_) => DetailPage(),
  }),
)

// 方式二：MaterialApp.router - RouterDelegate（纯 Flutter，无第三方路由）
// 页面继续使用 Navigator.pushNamed / pop / pushReplacementNamed，参数通过 ModalRoute 获取
final routerConfig = easySplitNativeRouterConfig(
  home: const AdPage(),                                   // 全屏首屏，不包 Scope
  pageBuilders: {
    '/home': (_) => EasySplitScope(child: HomePage()),    // 首页自己决定左窗格
    '/detail': (_) => DetailPage(),
  },
);
MaterialApp.router(routerConfig: routerConfig)
```

> 方式二的 `routerConfig` 只能创建一次（顶层 `final` 或某个 `State` 的字段）。如果在
> `build()` 里创建，每次重建都会替换 delegate 和 `Navigator`，路由栈会丢失。

其他路由体系（`Navigator.pages` 等）可以使用 `EasySplitPage(child: ..., name: ...)` 作为
`Page`，它由同一个 `EasySplitRoute` 支撑。

### 2.1 重复路由去重（默认开启）

反复点击同一个列表项不会再压入重复路由，而是把已有路由提到栈顶。

| 集成方式 | 如何开启 |
| --- | --- |
| 方式一，onGenerateRoute | 添加 `navigatorObservers: [EasySplit.dedupeObserver]` |
| 方式二，MaterialApp.router | **自动生效**（delegate 拦截 `pushNamed`） |

默认「同一个页面」指 `name + arguments` 相同，也可以自定义：

```dart
EasySplit.config
  ..dedupeRepeatedRoutes = true                      // 设为 false 可关闭
  ..sameRoute = (a, b) => a.name == b.name && ...    // 按业务 id 匹配
```

> 只拦截 `Navigator.pushNamed`；`pushReplacementNamed`、`pushNamedAndRemoveUntil` 和
> `push` 保持原生语义。

### 3. 配置：`EasySplit.config`（统一入口）

```dart
EasySplit.config
  ..paneRatio = 0.45            // 左右比例
  ..fullscreenRoutes.addAll({'/login'})  // 保持全屏的沉浸式页面
  ..fullscreenRoutes.addAll({'/home'})   // 首页不是第一个路由时（splash -> replace -> home）
  ..placeholderBuilder = (ctx) => EmptyView()  // 右窗格空状态
  ..breakpoint = 600            // 窄屏/宽屏断点
  ..layoutDelegate = (ctx) => ...  // 自定义分屏布局（左/右矩形区域）
  ..paneDecoration = ...        // 右窗格装饰
  ..isWideOverride = (ctx) => ...  // 自定义「是否展开」判断（例如真实铰链）
  ..dedupeRepeatedRoutes = true  // 重复路由提到栈顶（默认）
  ..sameRoute = (a, b) => ...    // 自定义「同一页面」判断
```

快捷访问器：`EasySplit.enabled`（运行时开关）、`EasySplit.paneRatio` 等。

与几何相关的设置（`paneRatio`、`breakpoint`、`layoutDelegate`、`layoutBuilder`）不是响应式的：
修改后调用一次 `EasySplit.updateLayout()`，可见的分屏会立即重新布局（路由栈保持不变）：

```dart
EasySplit.paneRatio = 0.35;   // 或替换 layoutDelegate
EasySplit.updateLayout();     // 立即重新布局
```

### 4. 参数透传（路由外观 / 占位页）

```dart
// 窗格路由和全屏路由的常用外观参数（与 MaterialPageRoute 对齐）
EasySplitRoute(
  builder: (_) => const DetailPage(),
  maintainState: true,      // 保留被覆盖页面的状态
  fullscreenDialog: false,  // 使用全屏对话框转场
  allowSnapshotting: true,  // 转场期间允许快照
  requestFocus: null,       // 自动请求焦点
  settings: const RouteSettings(name: '/detail'),
)

// Navigator.pages 场景
EasySplitPage(
  child: (_) => const DetailPage(), name: '/detail',
  fullscreen: false, maintainState: true, /* ...同上 */
)

// 每个 scope 可以提供自己的右窗格占位页（优先于全局占位页）
EasySplitScope(
  placeholderBuilder: (_) => const EmptyView(),
  child: HomePage(),
)
```

使用 `MaterialApp.router` 时还可以透传内部 `Navigator` 参数：
`easySplitNativeRouterConfig(home: ..., pageBuilders: ..., observers: [...], onUnknownRoute: ...)`。

### 5. 窗格内的"屏幕"就是窗格本身

EasySplit 会给左右窗格分别注入**窗格自己的 `MediaQuery`**，于是窗格内的页面：

- `MediaQuery.sizeOf(context)` / `MediaQuery.of(context).size` 是窗格尺寸；
- `MediaQuery.orientationOf(context)` 跟随窗格；
- `padding` / `viewPadding` 已扣除窗格自己避让掉的安全区。

百分比宽度、栅格、间距系数、宽高比这类布局因此按窗格宽度适配，**业务页面不用改一行代码**。

以下仍按整窗计算（否则分屏本身就会失效）：

- `EasySplit.isWide`、`EasySplit.layoutOf`、`EasySplit.paneWidth`、
  `EasySplit.paneContentInsets` 继续按整窗几何算，断点不会被窗格尺寸带偏；
- 从窗格里打开的对话框 / 底部弹层仍在 overlay 里，尺寸按整窗。

#### ScreenUtil

ScreenUtil 不读 `MediaQuery`：`ScreenUtil.init(context)` 与 `ScreenUtilInit` 走的是
`View.maybeOf(context)` + `MediaQueryData.fromView(view)`，永远拿到整窗。在 `main()` 里转发一次
即可，页面零改动：

```dart
void main() {
  EasySplit.config.onPaneMediaQuery = (data) => ScreenUtil.configure(
        data: data,
        designSize: const Size(375, 812), // 你的设计稿尺寸
        splitScreenMode: false, // ScreenUtil 的 late 字段，第一次 configure
        minTextAdapt: false,    // 必须显式传，否则面板先构建会抛 LateInitializationError
      );
  runApp(const App());
}
```

注意：

- 回调在窗格 build 期间同步触发，**不要在回调里 setState**；
- ScreenUtil 是全局单例：左右窗格同时可见时，后构建的那个生效；
- 自己调整缩放配置后，调用 `EasySplit.updateLayout()` 让可见窗格重新上报。

#### 自定义布局

用 `EasySplit.config.layoutBuilder` 时，窗格尺寸按实际约束反推，页面同样拿到自己的尺寸；
需要自己换算时用 `EasySplit.paneMediaQuery`：

```dart
final data = EasySplit.paneMediaQuery(
  MediaQuery.of(context),              // 整窗数据
  const Rect.fromLTWH(0, 0, 600, 800), // 你的窗格矩形
  insets: const EdgeInsets.only(top: 24),
);
```

## 项目结构

```
lib/easy_split.dart                      EasySplitConfig（配置包装）+ 核心 API
lib/src/easy_split_pane_route.dart       EasySplitRoute / EasySplitPage
lib/src/easy_split_scope.dart            EasySplitScope 分屏容器
lib/src/easy_split_router_delegate.dart  EasySplitRouterDelegate（MaterialApp.router）
lib/src/easy_split_dedupe_observer.dart  EasySplitDedupeObserver（onGenerateRoute 一行接入去重）
lib/src/easy_split_window.dart           整窗几何 + 窗格 MediaQuery（内部实现）
test/                                    47 个行为测试（手势、路由、去重、参数、实时布局、窗格尺寸）
packages/easy_split_go_router/            go_router 适配包
packages/easy_split_demo/                两个 example 入口共用的演示包
  `-- lib/src/pages.dart                 演示页面（广告、首页、详情、弹窗大全）
  `-- lib/src/demos.dart                 TabBar 首页 + 窗格宽度演示
  `-- lib/src/setup.dart                 共用路由表、ScreenUtil 接入、主题
example/
  `-- lib/main.dart                       方式一：MaterialApp onGenerateRoute
  `-- lib/main_1.dart                     方式二：MaterialApp.router RouterDelegate
```

## 手势穿透是如何实现的

分屏里的详情页是一个真实的 `PageRoute`，其 `opaque = false`；它天生希望占满整个屏幕并接管
所有手势。EasySplit 通过三层把它限制在右窗格内：

1. **视觉层**：`opaque = false` 加上零尺寸的 `buildModalBarrier()`——下层页面继续绘制，
   也不会出现全屏遮罩。
2. **布局层（关键）**：`buildTransitions` 先产出原生主题/平台转场，然后把整个转场子树包进
   `Padding + SizedBox`，将其收缩到 `paneRect` 内。

   `buildTransitions` 的输出在 `Overlay` 里总是拿到全屏约束，而框架正是在这一层插入自己的手势
   探测器——最明显的是 `CupertinoPageTransitionsBuilder` 的 iOS 返回滑动手势热区
   （`Stack[child, PositionedDirectional(start: 0, width: 20, child: Listener(...))]`，钉在
   路由盒子的左边缘）。如果路由盒子是全屏的，热区就落在屏幕左边缘，也就是左窗格内，结果是：

   - 从**屏幕左边缘**滑动会 pop 右窗格的详情页（左窗格手势被劫持）
   - 从**右窗格左边缘**滑动没有任何反应（符合直觉的手势失效）

   把整个路由收缩到窗格内，热区就移动到右窗格的左边缘，转场在窗格内播放，Cupertino 的拖动
   进度也相对窗格宽度计算（手势与动画 1:1）。`buildContent` 里的命中测试裁剪够不到这一层，
   所以位置必须在这里修正。
3. **命中测试兜底**：`_PaneHitTestScope`（`RenderProxyBox.hitTest`）用 `localToGlobal` 转换
   局部坐标并与 `paneRect` 比较；在右窗格外返回 `false`，指针便落到下层。即使页面画到了自己
   边界之外（例如使用 `OverflowBox`），也无法挡住左窗格。

在窄屏/竖屏（不分屏）上，原生路由原样透传，表现与 `MaterialPageRoute` 完全一致。

回归测试覆盖：

- `test/pane_route_gesture_test.dart` - 左窗格点击/滚动可穿透、右窗格内容盒等于 `paneRect`、
  iOS 返回滑动手势热区锚定在右窗格左边缘且不会在左窗格触发、窄屏全屏、转场过程中左窗格仍可
  交互、pop/push 往返；
- `test/router_delegate_test.dart` - 宽屏/窄屏下的 MaterialApp.router 导航、
  `pushNamed`/`pop`/`pushReplacementNamed`/`pushNamedAndRemoveUntil`、`delegate.push`/`pop`、
  深链同步、去重、参数透传；
- `test/dedupe_observer_test.dart` - onGenerateRoute 去重观察者；
- `test/layout_update_test.dart` - 修改 `paneRatio` 或自定义布局后通过 `updateLayout()` 立即
  重新布局，包含垂直分屏。

## 运行示例

```bash
cd example
flutter run -t lib/main.dart          # 方式一：onGenerateRoute
flutter run -t lib/main_1.dart        # 方式二：MaterialApp.router RouterDelegate
```

右上角的开关可以随时关闭适配器；下拉框切换布局模式（auto / custom / split off）；「Split settings」
可在并排、内容在左、垂直和悬浮窗格布局之间切换，并实时调整窗格比例（拖动即重新布局）。旋转
模拟器（Cmd + 方向键）可以检查折叠/展开切换。

示例还包含一个模拟登录门禁：未登录时，首页每个入口都会先打开模拟登录页（`/login`，全屏，
永不分屏）；登录后继续打开目标页面。右上角可以退出登录。代码位于
`packages/easy_split_demo/lib/src/pages.dart`（`DemoAuth`、`ensureLoggedIn`、`openProtected`）。

示例里还有一个底部 tabbar 形式的首页（`packages/easy_split_demo/lib/src/demos.dart` 的
`TabsHomePage`，广告页和首页
列表都有入口），同时也是窗格适配的走查页：

- 底部 4 个 tab：计数 / 滚动 / 输入 / 宽度；
- 折叠 ⇄ 展开后，当前 tab、计数、滚动位置、输入内容都保留；
- **宽度** tab 展示面板尺寸 vs 整窗尺寸、100 / 50 / 25% 色块、自适应栅格和 ScreenUtil
  （`.w` / `.sp`）换算值，全部按面板宽度计算。

不需要真折叠屏：AppBar 的「折叠 / 展开」菜单通过 `EasySplit.config.isWideOverride` 强制切换，
走的是与真机折叠完全相同的代码路径。

想直接冷启动到它（截图 / CI 用），加两个 example 专属开关（两个入口文件都支持）：

```bash
cd example
# TabBar 首页，已展开（双栏），并停在"宽度"tab
flutter run -t lib/main.dart \
  --dart-define=EASYSPLIT_FORCE_MODE=wide \
  --dart-define=EASYSPLIT_START_ROUTE=/tabs-home \
  --dart-define=EASYSPLIT_START_TAB=3

# TabBar 首页，折叠态
flutter run -t lib/main_1.dart --dart-define=EASYSPLIT_START_ROUTE=/tabs-home
```

## 设计说明

- 只有一个路由栈 = 原生 `Navigator`；`EasySplitRoute` 只在这五处不同
  （`opaque = false`、无遮罩、透传委托转场、整个路由收缩进窗格、内容自适应），因此返回手势、
  系统返回和转场都是原生的
- 手势与命中测试边界：见上文「手势穿透是如何实现的」——指针处理和路由自身的手势层都通过
  **布局**限制在窗格内；命中测试裁剪只是兜底
- 折叠/展开切换：路由栈永不移动；`EasySplitRoute` 的内容在「右窗格区域」和「全屏」之间自适应
- 方向感知安全区：竖屏避开上/下，横屏避开左/右；旋转通过 `MediaQuery` 更新
- 铰链避让：`paneWidth` 会从 `displayFeatures` 中减去铰链区域

## 许可证

MIT

## ☕ 请我喝咖啡

如果这个项目帮到了你，欢迎请我喝杯咖啡，感谢你的支持！

| 支付宝 | 微信 |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/flutter-open/resures-repository/master/docs/images/ali.jpg" width="260" alt="支付宝收款码" /> | <img src="https://raw.githubusercontent.com/flutter-open/resures-repository/master/docs/images/wechat.jpg" width="260" alt="微信收款码" /> |
