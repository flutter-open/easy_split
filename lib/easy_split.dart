import 'dart:ui' show DisplayFeatureType, PlatformDispatcher;

import 'package:flutter/material.dart';

import 'src/easy_split_dedupe_observer.dart';
import 'src/easy_split_pane_route.dart';
import 'src/easy_split_scope.dart';
import 'src/easy_split_router_delegate.dart';

export 'src/easy_split_dedupe_observer.dart';
export 'src/easy_split_pane_route.dart';
export 'src/easy_split_scope.dart';
export 'src/easy_split_router_delegate.dart';

/// 配置对象：所有 EasySplit 配置集中在这里（一层包装，符合 Flutter 传参习惯）
///
/// 两种用法：
/// 1. 直接修改全局默认配置：`EasySplit.config.paneRatio = 0.45;`
/// 2. 整体替换为自定义配置：`EasySplit.config = EasySplitConfig(paneRatio: 0.45);`
class EasySplitConfig {
  EasySplitConfig({
    ValueNotifier<bool>? enabled,
    this.breakpoint = 600,
    this.paneRatio = 0.5,
    this.placeholderBuilder,
    Set<String>? fullscreenRoutes,
    this.isWideOverride,
    this.layoutDelegate,
    this.paneDecoration,
    this.dedupeRepeatedRoutes = true,
    this.sameRoute,
  })  : enabled = enabled ?? ValueNotifier<bool>(true),
        fullscreenRoutes = fullscreenRoutes ?? {};

  /// 适配总开关（ValueNotifier：修改后正在显示的 pane 自动跟随）
  final ValueNotifier<bool> enabled;

  /// 宽屏断点（默认逻辑用），>= 此宽度视为折叠屏展开/桌面
  double breakpoint;

  /// 宽屏下右侧面板占屏幕宽度比例（默认布局用）
  double paneRatio;

  /// 右侧仅有首页时的占位页
  WidgetBuilder? placeholderBuilder;

  /// 全屏路由名单：命中的路由任何宽度都走原生全屏（内含 EasySplitScope 自行分栏）
  ///
  /// 典型场景：**首页不是启动首路由**的应用（闪屏/广告 → replace 到首页）——
  /// 把真正的首页路由加入名单即可：
  /// ```dart
  /// EasySplit.config.fullscreenRoutes.addAll({'/home'});
  /// // '/' 为闪屏页（不包 Scope），replace 到 '/home' 后：
  /// // '/home' 作为原生 opaque 路由全屏显示，内部 EasySplitScope 自行分栏；
  /// // 后续 '/detail' 依旧被拦截为透明分栏路由，叠加在首页之上
  /// ```
  final Set<String> fullscreenRoutes;

  /// 分栏模式判定回调（可选）：自行决议什么情况算"展开"；
  /// 不设置时使用内部默认逻辑：宽度 >= [breakpoint] 且横屏
  bool Function(BuildContext context)? isWideOverride;

  /// 自定义分栏布局委托（可选）：返回左栏与右栏区域，
  /// 左栏（Scope）与右栏（路由内容）共用同一布局结果；
  /// 不设置时使用内部默认布局：左右并排 + 铰链避让
  EasySplitLayout Function(BuildContext context)? layoutDelegate;

  /// 右栏面板装饰（可选）：默认 背景色 + 左边框 + 阴影
  Decoration? paneDecoration;

  /// 分栏布局构建器（可选）：**把左右两个 widget 交给你自己组合布局**。
  /// - `left`：首页（列表页）widget —— 放哪儿都行，这就是左栏
  /// - `right`：右栏 widget（含占位页；有二级路由时该区域会被路由内容原生覆盖）
  ///
  /// 注意：路由内容（push 的二级页）的落点由 [layoutDelegate] 的
  /// `paneRect` 决定（默认与右栏位置一致）。自定义 `layoutBuilder` 时
  /// 通常需要同时设置 `layoutDelegate`，让"骨架布局"与"路由落点"匹配
  Widget Function(BuildContext context, Widget left, Widget right)?
      layoutBuilder;

  /// 重复路由去重（默认开启）
  ///
  /// 同一路由已在栈内时，再次 `Navigator.pushNamed` **不会重复压栈**，
  /// 而是把栈内已有实例置顶（`popUntil` 掉它上面的路由），
  /// 避免"左侧点同一个条目反复压栈、返回要按很多次"。
  ///
  /// "同一路由"默认按 `name` + `arguments` 判断（见 [sameRoute]）。
  ///
  /// 目前由 [EasySplitRouterDelegate]（`MaterialApp.router` 方案）实现；
  /// `onGenerateRoute` 方案用的是框架自带的 Navigator，无法拦截 pushNamed。
  bool dedupeRepeatedRoutes;

  /// 判断两条路由是否"同一页面"（[dedupeRepeatedRoutes] 的匹配规则）
  ///
  /// 默认：`a.name == b.name && a.arguments == b.arguments`。
  /// 例如详情页想按业务 id 去重：
  /// ```dart
  /// EasySplit.config.sameRoute = (a, b) =>
  ///     a.name == '/detail' && (a.arguments as Item?)?.id ==
  ///         (b.arguments as Item?)?.id;
  /// ```
  bool Function(RouteSettings a, RouteSettings b)? sameRoute;
}

/// EasySplit · 折叠屏/宽屏快速分栏适配引擎
///
/// 仿鸿蒙"平行视界"：一个路由栈，折叠（窄屏）= 正常全屏路由模式，
/// 展开（宽屏）= 自动左右分栏，切换纯表现层、栈完全不动。
///
/// 纯适配器设计，不继承任何 App，与 MaterialApp / CupertinoApp /
/// GoRouter(routerConfig) / Navigator.pages 自由组合：
///
/// 1. 列表页（栈底）手动包 [EasySplitScope] —— 你自己决定谁是左栏
/// 2. 路由接入三选一（按你的路由方案）：
///    - MaterialApp/CupertinoApp：`onGenerateRoute: EasySplit.routeAdapter({...})`
///    - MaterialApp.router / Router：`easySplitNativeRouterConfig(home:, pageBuilders:)`
///    - GoRouter pageBuilder / Navigator.pages：`EasySplitPage(child: ..., name: ...)`
///    - 完全手动：`EasySplitRoute(builder: ...)`
/// 3. 配置：`EasySplit.config`（[EasySplitConfig]，也可用下方便捷存取器）
class EasySplit {
  EasySplit._();

  /// 全局默认配置（一层包装：所有配置集中在此对象上）
  static EasySplitConfig config = EasySplitConfig();

  // ---- 便捷存取器：转发到 config（老用法兼容） ----

  /// 适配总开关
  static bool get enabled => config.enabled.value;
  static set enabled(bool value) => config.enabled.value = value;

  /// 宽窄断点
  static double get breakpoint => config.breakpoint;
  static set breakpoint(double value) => config.breakpoint = value;

  /// 左右占比
  static double get paneRatio => config.paneRatio;
  static set paneRatio(double value) => config.paneRatio = value;

  /// 占位页
  static WidgetBuilder? get placeholderBuilder => config.placeholderBuilder;
  static set placeholderBuilder(WidgetBuilder? value) =>
      config.placeholderBuilder = value;

  /// 全屏路由名单
  static Set<String> get fullscreenRoutes => config.fullscreenRoutes;

  /// 分栏判定回调
  static bool Function(BuildContext context)? get isWideOverride =>
      config.isWideOverride;
  static set isWideOverride(bool Function(BuildContext context)? value) =>
      config.isWideOverride = value;

  /// 自定义分栏布局委托
  static EasySplitLayout Function(BuildContext context)? get layoutDelegate =>
      config.layoutDelegate;
  static set layoutDelegate(
          EasySplitLayout Function(BuildContext context)? value) =>
      config.layoutDelegate = value;

  /// 右栏面板装饰
  static Decoration? get paneDecoration => config.paneDecoration;
  static set paneDecoration(Decoration? value) => config.paneDecoration = value;

  /// 重复路由去重开关（默认开启，见 [EasySplitConfig.dedupeRepeatedRoutes]）
  static bool get dedupeRepeatedRoutes => config.dedupeRepeatedRoutes;
  static set dedupeRepeatedRoutes(bool value) =>
      config.dedupeRepeatedRoutes = value;

  /// 重复路由匹配规则（默认 name + arguments 相同）
  static bool Function(RouteSettings a, RouteSettings b)? get sameRoute =>
      config.sameRoute;
  static set sameRoute(bool Function(RouteSettings a, RouteSettings b)? value) =>
      config.sameRoute = value;

  /// 标准 Navigator 方案（`onGenerateRoute`）的一行去重接入：
  /// ```dart
  /// MaterialApp(
  ///   onGenerateRoute: EasySplit.routeAdapter({...}),
  ///   navigatorObservers: [EasySplit.dedupeObserver],
  /// )
  /// ```
  /// MaterialApp.router 方案（[EasySplitRouterDelegate]）已内置，无需添加。
  static NavigatorObserver get dedupeObserver => EasySplitDedupeObserver();

  // ---- 核心逻辑 ----

  /// 是否为宽屏分栏模式：
  /// 优先使用 [config.isWideOverride]（用户自定义决议），
  /// 未设置时使用内部默认逻辑：宽度 >= 断点 且横屏。
  /// 竖屏一律为正常路由模式（单栏全屏），不参与左右分栏
  static bool isWide(BuildContext context) {
    final override = config.isWideOverride;
    if (override != null) return override(context);
    final size = MediaQuery.sizeOf(context);
    return size.width >= config.breakpoint &&
        MediaQuery.orientationOf(context) == Orientation.landscape;
  }

  /// 面板安全区内边距（按屏幕方向决定）：
  /// 竖屏：上下避让（刘海/Home 指示条）；横屏：左右避让
  static EdgeInsets safePaneInsets(BuildContext context) {
    final mq = MediaQuery.of(context);
    final portrait = mq.orientation == Orientation.portrait;
    return portrait
        ? EdgeInsets.only(top: mq.padding.top, bottom: mq.padding.bottom)
        : EdgeInsets.only(left: mq.padding.left, right: mq.padding.right);
  }

  /// 右栏**内容**的内边距：只避让面板外露边的安全区。
  /// 横屏：仅右侧（面板左侧在屏内，不再避让左侧刘海）；
  /// 竖屏：上下（刘海/Home 指示条）
  static EdgeInsets paneContentInsets(BuildContext context) {
    final mq = MediaQuery.of(context);
    final portrait = mq.orientation == Orientation.portrait;
    return portrait
        ? EdgeInsets.only(top: mq.padding.top, bottom: mq.padding.bottom)
        : EdgeInsets.only(right: mq.padding.right);
  }

  /// 从 padding 中扣除已应用的安全区（防止内层 Scaffold 二次消费）
  static EdgeInsets removeInsets(EdgeInsets padding, EdgeInsets applied) {
    return EdgeInsets.only(
      left: (padding.left - applied.left).clamp(0.0, double.infinity),
      top: (padding.top - applied.top).clamp(0.0, double.infinity),
      right: (padding.right - applied.right).clamp(0.0, double.infinity),
      bottom: (padding.bottom - applied.bottom).clamp(0.0, double.infinity),
    );
  }

  /// 右栏宽度：屏幕宽 * paneRatio，并避让折叠屏铰链
  static double paneWidth(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    var width = size.width * config.paneRatio;
    for (final feature in MediaQuery.displayFeaturesOf(context)) {
      if (feature.type == DisplayFeatureType.hinge &&
          feature.bounds.left >= size.width / 2) {
        width -= feature.bounds.width;
      }
    }
    return width.clamp(0, size.width);
  }

  /// 当前生效布局（自定义委托或默认并排布局）
  static EasySplitLayout layoutOf(BuildContext context) =>
      config.layoutDelegate?.call(context) ?? defaultLayout(context);

  /// 默认布局：左右并排（右栏占 paneRatio，铰链避让）
  static EasySplitLayout defaultLayout(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pw = paneWidth(context);
    return EasySplitLayout(
      leftRect: Rect.fromLTWH(0, 0, size.width - pw, size.height),
      paneRect: Rect.fromLTWH(size.width - pw, 0, pw, size.height),
    );
  }

  /// 是否为全屏路由
  static bool isFullscreen(RouteSettings settings) =>
      config.fullscreenRoutes.contains(settings.name);

  /// 原生 router 模式（MaterialApp.router，无 go_router）的 RouterConfig
  ///
  /// 与 `onGenerateRoute` 方案行为一致，页面里的
  /// `Navigator.pushNamed` / `Navigator.pop` 无需任何改动。
  ///
  /// ```dart
  /// final delegate = EasySplitRouterDelegate(
  ///   home: RootPage(),
  ///   pageBuilders: {'/detail': (_) => DetailPage()},
  /// );
  /// MaterialApp.router(
  ///   routerConfig: EasySplit.nativeRouterConfig(delegate: delegate),
  /// )
  /// ```
  ///
  /// 不需要持有 delegate 时，直接用一行的 [easySplitNativeRouterConfig]。
  static RouterConfig<String> nativeRouterConfig({
    required EasySplitRouterDelegate delegate,
    RootBackButtonDispatcher? backButtonDispatcher,
  }) {
    return RouterConfig<String>(
      routerDelegate: delegate,
      routeInformationParser: const _EasySplitRouteInformationParser(),
      routeInformationProvider: PlatformRouteInformationProvider(
        // 平台启动路由（深链）；普通启动为 '/'
        initialRouteInformation: RouteInformation(
          uri: Uri.parse(PlatformDispatcher.instance.defaultRouteName),
        ),
      ),
      backButtonDispatcher: backButtonDispatcher ?? RootBackButtonDispatcher(),
    );
  }



  /// 路由表适配器：产出 onGenerateRoute 钩子（MaterialApp / CupertinoApp 通用）
  ///
  /// ```dart
  /// MaterialApp(
  ///   home: EasySplitScope(child: RootPage()),   // 左栏（列表页）手动包裹
  ///   onGenerateRoute: EasySplit.routeAdapter({
  ///     '/detail': (_) => DetailPage(),          // 宽屏分栏 / 窄屏全屏
  ///     '/login': (_) => LoginPage(),            // fullscreenRoutes 名单 → 永远全屏
  ///   }),
  /// )
  /// ```
  ///
  /// 未命中的路由返回 null（交由 onUnknownRoute 兜底，与原生行为一致）
  static RouteFactory routeAdapter(Map<String, WidgetBuilder> routes) {
    return (settings) {
      final builder = routes[settings.name];
      if (builder == null) return null;
      return adaptRoute(settings, builder);
    };
  }

  /// 单个路由适配器：用于 onGenerateRoute / GoRouter pageBuilder 等
  ///
  /// 全屏名单命中 → 原生 MaterialPageRoute（全屏）；否则 → [EasySplitRoute]
  static Route<dynamic> adaptRoute(
      RouteSettings settings, WidgetBuilder builder) {
    return isFullscreen(settings)
        ? MaterialPageRoute<dynamic>(builder: builder, settings: settings)
        : EasySplitRoute<dynamic>(builder: builder, settings: settings);
  }
}

/// 分栏布局信息：左栏与右栏的区域矩形（全局坐标）
class EasySplitLayout {
  final Rect leftRect;
  final Rect paneRect;
  const EasySplitLayout({required this.leftRect, required this.paneRect});
}

/// 原生 router 模式的路由信息解析器（透传 location 字符串）
class _EasySplitRouteInformationParser extends RouteInformationParser<String> {
  const _EasySplitRouteInformationParser();

  @override
  Future<String> parseRouteInformation(RouteInformation routeInformation) async {
    final path = routeInformation.uri.path;
    return path.isEmpty ? '/' : path;
  }
}
