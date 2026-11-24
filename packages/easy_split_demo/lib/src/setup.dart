import 'package:easy_split/easy_split.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'demos.dart';
import 'pages.dart';

/// 自带 `EasySplitScope`、需要进 `EasySplit.config.fullscreenRoutes` 的首页路由。
///
/// 它们是栈底"首页"，自己负责分栏；加进全屏名单后不会被外层再分一次。
const Set<String> kDemoHomeRoutes = {'/home', '/tabs-home', '/login'};

/// ScreenUtil 适配：把面板实际生效的 `MediaQuery` 交给 ScreenUtil 全局单例，
/// 页面里的 `.w` / `.sp` 才会按面板宽度换算，而不是按整窗。
///
/// 在 `main()` 里调一次即可，页面代码零改动。
///
/// 注意 `splitScreenMode` / `minTextAdapt` 是 ScreenUtil 的 late 字段，第一次
/// `configure` 必须显式传，否则面板先于 `ScreenUtilInit` 构建时会抛
/// `LateInitializationError` —— 这里固定传 `false`，与 `ScreenUtilInit` 保持一致。
void installPaneScreenUtil() {
  EasySplit.config.onPaneMediaQuery = (data) => ScreenUtil.configure(
    data: data,
    designSize: kDesignSize,
    splitScreenMode: false,
    minTextAdapt: false,
  );
}

/// demo 主题（两个入口共用，只影响观感）。
ThemeData demoTheme() =>
    ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true);

/// demo 路由表：两种接入方式共用同一份。
///
/// - [scheme] 是入口页标题下方展示的"接入方式"文案，只影响展示；
/// - 首页 `/home`、tabbar 首页 `/tabs-home` 在入口处显式包 `EasySplitScope`；
/// - 登录页 `/login`、详情页 `/detail`、二级页 `/secondary`、弹窗大全 `/dialogs`
///   由 eager 的分栏路由接管。
Map<String, WidgetBuilder> demoRoutes({required String scheme}) => {
  '/home': (_) => EasySplitScope(child: HomePage(title: scheme)),
  '/tabs-home': (_) => EasySplitScope(child: TabsHomePage(title: scheme)),
  '/login': (_) => const LoginPage(),
  '/detail': (_) => const DetailPage(),
  '/secondary': (_) => const SecondaryPage(),
  '/dialogs': (_) => const DialogsPage(),
};
