import 'package:flutter/widgets.dart';

import 'pages.dart';

/// 经典 GetX 命名路由：
/// `GetMaterialApp(onGenerateRoute: easySplitGetRouteAdapter(...))`。
///
/// 页面里的 `Get.toNamed` / `Get.offNamed` / `Get.parameters` 保持原样。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runGetxDemo(routerMode: false);
}
