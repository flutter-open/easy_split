import 'package:flutter/foundation.dart' show kDebugMode;
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../easy_split.dart';

/// 裸路由审计：debug 下把「easy_split 无法接管」的入栈打印出来。
///
/// easy_split 只能接管它自己创建的路由（[EasySplitRoute] /
/// [EasySplitPage]），或由 [EasySplit.routeAdapter] / `EasySplitGoRoute`
/// 产出的页面。业务侧直接 `Navigator.push(MaterialPageRoute(...))`（含
/// `CupertinoPageRoute`、`PageRouteBuilder`）时，路由是原生全屏的：
/// 宽屏分栏下会整窗盖住左栏，且绕过 go_router 的 redirect / URL 同步 /
/// 去重，属于最隐蔽的一类问题。
///
/// 开发期把它挂到导航器上即可把漏网点全部打出来：
///
/// ```dart
/// MaterialApp(
///   onGenerateRoute: EasySplit.routeAdapter({...}),
///   navigatorObservers: [
///     EasySplit.dedupeObserver,
///     EasySplit.auditObserver, // debug 下告警，release 自动静默
///   ],
/// )
///
/// GoRouter(
///   routes: [...],
///   navigatorObservers: [
///     EasySplit.dedupeObserver,
///     EasySplit.auditObserver,
///   ],
/// )
/// ```
///
/// 判定为「预期全屏」而不告警的路由：
/// - 非 [PageRoute]（`showDialog` / `showModalBottomSheet` / loading 等
///   `PopupRoute`，它们本就该整窗）
/// - [EasySplitRoute]（easy_split 自己的 pane 路由）
/// - `settings is EasySplitPage`（[EasySplitPage] 创建的页面，含其
///   `fullscreen` 分支）
/// - [EasySplit.isFullscreen] 命中的路由（显式全屏名单）
///
/// 只在 debug 构建生效；[EasySplit.enabled] 为 false 时不检查。
class EasySplitAuditObserver extends NavigatorObserver {
  /// [onWarn] 为 null 时用 `debugPrint` 输出，测试可传入回调捕获。
  EasySplitAuditObserver({this.onWarn});

  /// 告警回调（默认 `debugPrint`）
  final void Function(String message)? onWarn;

  /// 已告警的路由，避免同一条路由重复打印
  final Set<Route<dynamic>> _warned = Set<Route<dynamic>>.identity();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _audit(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _audit(newRoute);
  }

  void _audit(Route<dynamic> route) {
    if (!kDebugMode) return;
    if (!EasySplit.config.enabled.value) return;
    if (_isExpectedFullscreenRoute(route)) return;
    if (!_warned.add(route)) return;

    final String name = route.settings.name ?? '<匿名>';
    final String message = '[easy_split] 裸路由入栈（分栏无法接管，宽屏下将整窗全屏）：'
        'name=$name, type=${route.runtimeType}。'
        '请改用 EasySplitGoRoute / EasySplit.routeAdapter / EasySplitPage 建路由，'
        '或把该路由加入 EasySplit.fullscreenRoutes 明确声明为全屏。';
    final void Function(String message)? warn = onWarn;
    if (warn != null) {
      warn(message);
    } else {
      debugPrint(message);
    }
  }

  /// 该路由是否属于「无需分栏」的预期全屏
  static bool _isExpectedFullscreenRoute(Route<dynamic> route) {
    // 对话框 / 底部弹层 / loading 等：本来就是整窗，
    // 且不参与页面栈的分栏语义
    if (route is! PageRoute) return true;
    if (route is EasySplitRoute) return true;
    final RouteSettings settings = route.settings;
    if (settings is EasySplitPage) return true;
    return EasySplit.isFullscreen(settings);
  }
}
