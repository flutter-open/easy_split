// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../easy_split.dart';

/// 根部适配容器：包在你的列表页（栈底）上
///
/// ```dart
/// MaterialApp(
///   home: EasySplitScope(child: RootPage()),
///   onGenerateRoute: EasySplit.routeAdapter({...}),
/// )
/// ```
///
/// 宽↔窄切换时路由栈完全不动，仅表现层自动切换：
/// - 窄屏（折叠态）：child 全屏 = 正常路由模式
/// - 宽屏（展开态）：**叠加布局**——child（首页）全屏铺底，
///   右栏区域叠加在顶层：无路由时显示占位页，
///   有路由时被 pane 路由内容原生覆盖。
///   两栏各自的 Scaffold 独立消费安全区，AppBar 顶点自然对齐
/// - 分栏布局支持自定义：[EasySplit.config.layoutBuilder]（左右 widget 组合）/
///   [EasySplit.config.layoutDelegate]（左右矩形，路由内容落点跟随）
///
/// 注意：**不要在 EasySplitScope 外面再包 SafeArea**。
/// 安全区由页面自身 Scaffold 与右栏内容分层处理，
/// 外层再包会导致 MediaQuery.padding 被清零/双倍消费，破坏 AppBar 避让。
class EasySplitScope extends StatelessWidget {
  final Widget child;

  /// 右栏空态占位页（优先于 [EasySplit.config.placeholderBuilder]）
  ///
  /// 不传时使用全局配置；都没配则用内置占位页。
  final WidgetBuilder? placeholderBuilder;

  const EasySplitScope({
    super.key,
    required this.child,
    this.placeholderBuilder,
  });

  /// 当前生效的占位页：本 Scope 指定 > 全局配置 > 内置默认
  WidgetBuilder get _effectivePlaceholder =>
      placeholderBuilder ??
      EasySplit.config.placeholderBuilder ??
      _defaultPlaceholder;

  @override
  Widget build(BuildContext context) {
    // 监听适配总开关与布局变更：EasySplit.enabled / EasySplit.updateLayout
    // 后立即生效（路由栈不动，纯表现层）
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        EasySplit.config.enabled,
        EasySplit.config.layoutVersion,
      ]),
      builder: (context, _) {
        final enabled = EasySplit.config.enabled.value;
        return LayoutBuilder(builder: (context, constraints) {
          // 宽屏判定统一走 EasySplit.isWide（可被 isWideOverride 自定义）
          final isWide = enabled && EasySplit.isWide(context);

          // 窄屏：正常全屏路由模式（原生行为）
          if (!isWide) {
            return child;
          }

          // 宽屏：分栏模式（布局可自定义：layoutBuilder / layoutDelegate）
          final mq = MediaQuery.of(context);
          final contentInsets = EasySplit.paneContentInsets(context);

          // Material 祖先：裸内容缺 Material 会渲染异常
          Widget wrapPane(Widget w) =>
              Material(type: MaterialType.transparency, child: w);

          // 左栏只消费自己外露边的安全区：右侧被右栏面板覆盖，
          // 不需要再避让（否则左栏内容与右栏之间会多出一条安全区距离）。
          // 横屏：去掉右侧；竖屏分栏（自定义布局）：去掉左右
          final homePadding = EasySplit.removeInsets(
            mq.padding,
            EdgeInsets.only(right: mq.padding.right, left: mq.padding.left),
          );

          // 自定义组合：左右 widget 交给用户（安全区由用户布局负责）
          final layoutBuilder = EasySplit.config.layoutBuilder;
          if (layoutBuilder != null) {
            final right = wrapPane(ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: _effectivePlaceholder(context),
            ));
            return layoutBuilder(context, wrapPane(child), right);
          }

          final layout = EasySplit.layoutOf(context);
          // 右栏：背景铺满右栏区域，内容避让外露边安全区
          //（内层 MediaQuery 已扣除 contentInsets，防止 Scaffold 二次消费）
          final right = Positioned.fromRect(
            rect: layout.paneRect,
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: MediaQuery(
                data: mq.copyWith(
                  padding: EasySplit.removeInsets(mq.padding, contentInsets),
                ),
                child: Padding(
                  padding: contentInsets,
                  child: wrapPane(_effectivePlaceholder(context)),
                ),
              ),
            ),
          );

          // 两栏按布局矩形约束摆放：
          // 左栏 Scaffold 在自身矩形内消费安全区，与右栏天然对齐
          return Stack(
            children: [
              Positioned.fromRect(
                rect: layout.leftRect,
                child: MediaQuery(
                  data: mq.copyWith(
                    padding: homePadding,
                    viewPadding: EasySplit.removeInsets(
                        mq.viewPadding,
                        EdgeInsets.only(
                            right: mq.padding.right, left: mq.padding.left)),
                  ),
                  child: child,
                ),
              ),
              right,
            ],
          );
        });
      },
    );
  }
}

/// 默认占位页
Widget _defaultPlaceholder(BuildContext context) {
  final theme = Theme.of(context);
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.touch_app_outlined, size: 48, color: theme.disabledColor),
        const SizedBox(height: 12),
        Text('从左侧选择内容查看详情',
            style: TextStyle(color: theme.hintColor, fontSize: 14)),
      ],
    ),
  );
}
