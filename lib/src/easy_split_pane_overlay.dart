import 'dart:math' as math;

// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../easy_split.dart';

/// 浮层要占用哪一栏：`left` = 左栏（首页/列表），`right` = 右栏（分栏内容区）
enum EasySplitPaneSide {
  /// 左栏（主页面，通常包着 [EasySplitScope]）
  left,

  /// 右栏（分栏内容区，默认）
  right,
}

/// 把任意浮层约束到某一栏的矩形内（配合 root Overlay 使用）。
///
/// 直接 `Overlay.of(context).insert(OverlayEntry(...))` 的浮层按**整窗**布局：
/// 宽屏分栏时会盖住左栏，或被系统按整窗居中/贴边，与右栏对不齐。
/// 用本 widget 包一层即可获得：
/// - 定位到 [side] 对应的矩形（折叠态自动恢复整屏）
/// - 窗口缩放 / 展开折叠 / 修改 `paneRatio` 后自动重排
///   （内部监听 `layoutVersion`，与 [EasySplitPaneFrame] 一致）
/// - 矩形外的点击穿透（仅命中矩形内的浮层内容）
///
/// ```dart
/// Overlay.of(context, rootOverlay: true).insert(
///   OverlayEntry(
///     builder: (_) => EasySplitPaneOverlay(
///       side: EasySplitPaneSide.right,
///       ignorePointer: true, // 纯遮罩不吃点击
///       child: ColoredBox(color: Colors.black54),
///     ),
///   ),
/// );
/// ```
///
/// 注意：插入 root Overlay 的浮层永远在**所有路由之上**。若浮层需要夹在
/// 两个页面之间（如「二楼」页面下的底导遮罩），请把它挂到对应页面自己的
/// Stack 里，而不是用 Overlay。
///
/// 一般直接用 [EasySplit.showPaneOverlay] / [EasySplit.paneOverlayEntry]，
/// 不必手动包本 widget。
class EasySplitPaneOverlay extends StatelessWidget {
  const EasySplitPaneOverlay({
    super.key,
    required this.child,
    this.side = EasySplitPaneSide.right,
    this.ignorePointer = false,
  });

  /// 浮层内容
  final Widget child;

  /// 浮层贴哪一栏
  final EasySplitPaneSide side;

  /// true = 浮层不接收任何点击（纯遮罩/纯展示）；false = 浮层内容正常命中
  final bool ignorePointer;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        EasySplit.config.enabled,
        EasySplit.config.layoutVersion,
      ]),
      builder: (BuildContext context, Widget? _) {
        final MediaQueryData mq = MediaQuery.of(context);
        final Size size = mq.size;
        final bool wide =
            EasySplit.config.enabled.value && EasySplit.isWide(context);
        final EasySplitLayout layout = EasySplit.layoutOf(context);
        final Rect rect = !wide
            ? (Offset.zero & size)
            : side == EasySplitPaneSide.left
                ? layout.leftRect
                : layout.paneRect;

        // 整窗尺寸 + 内边距：矩形外的区域不拦截点击（Padding/ClipRect
        // 只在 child 内命中），左栏交互不受浮层影响
        final Widget positioned = Padding(
          padding: EdgeInsets.only(
            left: rect.left,
            top: rect.top,
            right: math.max(0.0, size.width - rect.right),
            bottom: math.max(0.0, size.height - rect.bottom),
          ),
          child: ClipRect(
            child: SizedBox(
              width: rect.width,
              height: rect.height,
              child: child,
            ),
          ),
        );

        // OverlayEntry 拿到的约束是整窗，显式撑满以免浮层内容收缩成 0 尺寸
        final Widget expanded = SizedBox.expand(child: positioned);
        return ignorePointer ? IgnorePointer(child: expanded) : expanded;
      },
    );
  }
}
