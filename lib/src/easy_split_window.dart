import 'package:flutter/widgets.dart';

/// 内部实现：把**整窗**的 [MediaQueryData] 固定在子树里（不对外导出）
///
/// 面板内会把 `MediaQuery.size` 换成"面板自身尺寸"，让页面按自己的宽度适配；
/// 但 [EasySplit.isWide] / [EasySplit.layoutOf] / [EasySplit.paneWidth] 这些
/// API 描述的是**整窗几何**（断点、左右矩形、铰链位置都按整窗算），不能
/// 被面板尺寸带偏 —— 通过这里取回窗口那一层的 MediaQueryData。
class EasySplitWindowMetrics extends InheritedWidget {
  const EasySplitWindowMetrics({
    super.key,
    required this.mediaQuery,
    required super.child,
  });

  /// 整窗 MediaQuery（面板外那一层）
  final MediaQueryData mediaQuery;

  /// 取整窗 MediaQuery；调用点不在 [EasySplitWindowMetrics] 子树内时
  /// 退回当前 MediaQuery（此时本身就等于整窗）
  static MediaQueryData of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<EasySplitWindowMetrics>()
            ?.mediaQuery ??
        MediaQuery.of(context);
  }

  @override
  bool updateShouldNotify(EasySplitWindowMetrics oldWidget) =>
      mediaQuery != oldWidget.mediaQuery;
}

/// 内部实现：面板内容区的 MediaQuery（注入 + 广播），不对外导出
///
/// - **注入**：页面拿到的 `MediaQuery.size` 是它自己占用的区域（左栏 /
///   右栏面板），于是 `MediaQuery.sizeOf(context).width`、百分比宽度、
///   栅格、按宽度算的间距都按面板宽度适配，而不是按整窗宽度放大。
/// - **广播**：[onData] 把同一份数据同步给不跟随 MediaQuery 的方案
///   （典型：ScreenUtil 直接读原始 FlutterView），见
///   `EasySplitConfig.onPaneMediaQuery`，页面代码不用改。
///
/// 任何模式下都固定输出 `MediaQuery`，折叠/展开不改变结构，页面 State 不重建。
class EasySplitPaneMetrics extends StatelessWidget {
  const EasySplitPaneMetrics({
    super.key,
    required this.data,
    required this.child,
    this.onData,
  });

  /// 面板内容区实际生效的 MediaQuery
  final MediaQueryData data;

  /// 面板 MediaQuery 变更回调（可为 null）
  final void Function(MediaQueryData data)? onData;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 与 ScreenUtilInit 一样的做法：在 build 期间同步配置外部方案，
    // 保证本帧子树内读取到的就是这份数据
    onData?.call(data);
    return MediaQuery(data: data, child: child);
  }
}
