import 'package:flutter/widgets.dart';

import 'pages.dart';

/// Navigator 2.0（GetX Router）：
/// `GetMaterialApp.router(getPages: [...])`，分栏页面用 `EasySplitGetPage`。
///
/// 注意：此模式下用 `Get.rootDelegate.toNamed(...)` 导航，
/// 不要用 `Get.toNamed`（它走 `Navigator.pushNamed`，与 `pages` 驱动不兼容）。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runGetxDemo(routerMode: true);
}
