// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../easy_split.dart';
import 'easy_split_window.dart';

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
/// 展开/折叠只改布局参数（Positioned 的 rect、MediaQuery 的 padding），
/// **不改变 child 在树中的位置**，因此首页的 State（TabController 当前页、
/// 滚动位置、输入内容…）在切换时原样保留。
///
/// 注意：**不要在 EasySplitScope 外面再包 SafeArea**。
/// 安全区由页面自身 Scaffold 与右栏内容分层处理，
/// 外层再包会导致 MediaQuery.padding 被清零/双倍消费，破坏 AppBar 避让。
class EasySplitScope extends StatefulWidget {
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

  @override
  State<EasySplitScope> createState() => _EasySplitScopeState();
}

class _EasySplitScopeState extends State<EasySplitScope> {
  /// 自定义 [EasySplitConfig.layoutBuilder] 时，窄屏（首页全屏）与宽屏
  /// （首页交给用户布局）的产物结构必然不同，无法靠固定 widget 结构保状态；
  /// 用稳定 GlobalKey 让首页子树整体搬迁，State 不重建。
  final GlobalKey _homeKey = GlobalKey(debugLabel: 'EasySplitScope.home');

  /// 当前生效的占位页：本 Scope 指定 > 全局配置 > 内置默认
  WidgetBuilder get _effectivePlaceholder =>
      widget.placeholderBuilder ??
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

          final mq = MediaQuery.of(context);

          // Material 祖先：裸内容缺 Material 会渲染异常
          Widget wrapPane(Widget w) =>
              Material(type: MaterialType.transparency, child: w);

          // 自定义组合：左右 widget 交给用户（安全区由用户布局负责）
          final layoutBuilder = EasySplit.config.layoutBuilder;
          if (layoutBuilder != null) {
            // GlobalKey 挂在首页自身（而不是外层包装）上，两态下 key 下方
            // 的子树完全一致，搬迁时首页 State（Tab/滚动/输入）全部保留
            final home = KeyedSubtree(
              key: _homeKey,
              // 自定义布局拿不到精确矩形，按实际约束反推"自己的尺寸"
              child: _PaneViewport(child: widget.child),
            );
            if (!isWide) {
              // 窄屏：layoutBuilder 不参与，首页照常全屏
              return home;
            }
            // 面板内 EasySplit.isWide / layoutOf 仍按整窗几何计算
            Widget host(Widget w) => EasySplitWindowMetrics(
                  mediaQuery: mq,
                  child: wrapPane(w),
                );
            final right = host(ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: _PaneViewport(child: _effectivePlaceholder(context)),
            ));
            return layoutBuilder(context, host(home), right);
          }

          // 无界约束（非路由场景）：退回原生全屏，Stack 依赖有界约束
          if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
            return widget.child;
          }

          final contentInsets = EasySplit.paneContentInsets(context);
          final layout = EasySplit.layoutOf(context);

          // 左栏只消费自己外露边的安全区：右侧被右栏面板覆盖，
          // 不需要再避让（否则左栏内容与右栏之间会多出一条安全区距离）。
          // 横屏：去掉右侧；竖屏分栏（自定义布局）：去掉左右
          final homePadding = EasySplit.removeInsets(
            mq.padding,
            EdgeInsets.only(right: mq.padding.right, left: mq.padding.left),
          );

          // 首页：窄屏沿用整窗 MediaQuery；宽屏 = 左栏矩形尺寸（页面里
          // MediaQuery.sizeOf 拿到的就是左栏宽度）+ 扣除被右栏占用的安全区。
          // 外层始终是同一个 MediaQuery + Positioned，只换参数不换结构，
          // 展开/折叠时首页 element 原地复用（State 不丢）。
          final home = EasySplitPaneMetrics(
            data: isWide
                ? mq.copyWith(
                    size: layout.leftRect.size,
                    padding: homePadding,
                    viewPadding: EasySplit.removeInsets(
                        mq.viewPadding,
                        EdgeInsets.only(
                            right: mq.padding.right, left: mq.padding.left)),
                  )
                : mq,
            onData: EasySplit.config.onPaneMediaQuery,
            child: widget.child,
          );

          // 右栏：背景铺满右栏区域，内容避让外露边安全区
          //（内层 MediaQuery 已扣除 contentInsets，防止 Scaffold 二次消费）
          final right = Positioned.fromRect(
            rect: layout.paneRect,
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: EasySplitPaneMetrics(
                data: EasySplit.paneMediaQuery(
                  mq,
                  layout.paneRect,
                  insets: contentInsets,
                ),
                onData: EasySplit.config.onPaneMediaQuery,
                child: Padding(
                  padding: contentInsets,
                  child: wrapPane(_effectivePlaceholder(context)),
                ),
              ),
            ),
          );

          // 两栏按布局矩形约束摆放：
          // 左栏 Scaffold 在自身矩形内消费安全区，与右栏天然对齐。
          // 注意：窄/宽都是 Stack + 第 0 个孩子为 Positioned（首页），
          // 只是 rect 不同 —— 结构恒定时 Flutter 复用 element，首页不重建。
          return EasySplitWindowMetrics(
            mediaQuery: mq,
            child: Stack(
              children: [
                if (isWide)
                  Positioned.fromRect(
                    rect: layout.leftRect,
                    child: home,
                  )
                else
                  Positioned.fill(child: home),
                if (isWide) right,
              ],
            ),
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

/// 自定义 [EasySplitConfig.layoutBuilder] 时无法预知左右 widget 的实际尺寸，
/// 用布局约束反推"自己的尺寸"：子树里的 `MediaQuery.sizeOf` 就是它占用的区域，
/// 而不是整窗尺寸（按宽度百分比 / 栅格写的布局不会被放大）。
///
/// 无界约束（例如被放进 ListView）时退回整窗尺寸，并且**始终输出
/// MediaQuery**，折叠/展开结构不变、页面 State 不重建。
class _PaneViewport extends StatelessWidget {
  const _PaneViewport({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.hasBoundedWidth ? constraints.maxWidth : mq.size.width;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : mq.size.height;
        return EasySplitPaneMetrics(
          data: mq.copyWith(size: Size(width, height)),
          onData: EasySplit.config.onPaneMediaQuery,
          child: child,
        );
      },
    );
  }
}
