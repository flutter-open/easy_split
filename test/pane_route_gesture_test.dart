import 'dart:async';

import 'package:easy_split/easy_split.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 右栏：pane 路由的手势与命中边界
///
/// 背景：宽屏分栏时，二级页是一条 `opaque=false` 的真实 PageRoute，
/// 它必须满足两条约束：
/// 1. 指针从**左栏**按下时完全不参与命中（点击/滚动/拖拽都归左栏）；
/// 2. 路由自身的手势层（iOS 侧滑返回）也要锚定在**右栏左缘**，
///    不能像全屏路由那样贴着屏幕左缘。
///
/// 第 2 条是重点：`buildTransitions` 的产物拿到的始终是全屏约束，
/// 框架会在这一层插入 20px 的侧滑热区。若只在 `buildContent` 里做
/// hitTest 裁剪，热区仍会落在左栏上 —— 表现为「左栏边缘右滑把详情 pop 了，
/// 而右栏左缘右滑反而没反应」。
void main() {
  setUp(() {
    EasySplit.config = EasySplitConfig();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    required Size size,
    TargetPlatform platform = TargetPlatform.android,
    void Function()? onLeftTap,
    ValueChanged<String>? onRoute,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: platform),
      home: EasySplitScope(
        child: Scaffold(
          body: ListView.builder(
            key: const ValueKey('left-list'),
            itemCount: 100,
            itemExtent: 50,
            itemBuilder: (_, i) => ListTile(
              title: Text('L$i'),
              onTap: onLeftTap,
            ),
          ),
        ),
      ),
      onGenerateRoute: EasySplit.routeAdapter({
        '/detail': (context) {
          onRoute?.call(ModalRoute.of(context)!.settings.name!);
          return Scaffold(
            appBar: AppBar(title: const Text('detail')),
            body: ListView.builder(
              key: const ValueKey('right-list'),
              itemCount: 100,
              itemExtent: 50,
              itemBuilder: (_, i) => ListTile(title: Text('R$i')),
            ),
          );
        },
      }),
    ));
  }

  NavigatorState navOf(WidgetTester tester) =>
      tester.state<NavigatorState>(find.byType(Navigator).first);

  double scrollOffset(WidgetTester tester, String key) {
    final scrollable = tester.state<ScrollableState>(find
        .descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(Scrollable))
        .first);
    return scrollable.position.pixels;
  }

  /// 从 [from] 向右拖动 [dx]，模拟 iOS 侧滑返回。
  Future<void> backSwipe(WidgetTester tester, Offset from,
      {double dx = 700}) async {
    final gesture = await tester.startGesture(from);
    await tester.pump();
    for (var i = 0; i < 14; i++) {
      await gesture.moveBy(Offset(dx / 14, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('左栏点击与滚动穿透到下层路由，右栏不受影响', (tester) async {
    var taps = 0;
    await pumpApp(tester,
        size: const Size(1200, 800), onLeftTap: () => taps++);

    unawaited(navOf(tester).pushNamed('/detail'));
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);

    await tester.tap(find.text('L0'));
    await tester.pumpAndSettle();
    expect(taps, 1, reason: '左栏 tap 应穿透到首页路由');

    await tester.drag(find.text('L3'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(scrollOffset(tester, 'left-list'), greaterThan(0),
        reason: '左栏滚动应穿透');
    expect(scrollOffset(tester, 'right-list'), 0, reason: '右栏不应跟着滚');

    await tester.drag(find.text('R2'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(scrollOffset(tester, 'right-list'), greaterThan(0),
        reason: '右栏自身可滚动');
  });

  testWidgets('右栏内容盒正好落在 paneRect 内', (tester) async {
    await pumpApp(tester, size: const Size(1200, 800));
    unawaited(navOf(tester).pushNamed('/detail'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(Scaffold).last);
    expect(rect, const Rect.fromLTRB(600, 0, 1200, 800),
        reason: '路由内容必须占满右栏，不能全屏也不能二次偏移');
  });

  testWidgets('iOS 侧滑返回锚定在右栏左缘，而不是屏幕左缘', (tester) async {
    await pumpApp(tester,
        size: const Size(1200, 800), platform: TargetPlatform.iOS);

    unawaited(navOf(tester).pushNamed('/detail'));
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);

    // 1) 屏幕最左缘 = 左栏内：不允许 pop 右栏详情
    await backSwipe(tester, const Offset(5, 300));
    expect(find.text('detail'), findsOneWidget,
        reason: '左栏边缘的手势不能被右栏路由的返回热区劫持');

    // 2) 右栏左缘：应当原生 pop
    await backSwipe(tester, const Offset(605, 300));
    expect(find.text('detail'), findsNothing,
        reason: '右栏左缘应触发原生侧滑返回');
  });

  testWidgets('窄屏（非分栏态）保持全屏路由与原生侧滑返回', (tester) async {
    await pumpApp(tester,
        size: const Size(500, 800), platform: TargetPlatform.iOS);

    unawaited(navOf(tester).pushNamed('/detail'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(Scaffold).last);
    expect(rect, const Rect.fromLTRB(0, 0, 500, 800),
        reason: '折叠/竖屏态应是全屏路由');

    await backSwipe(tester, const Offset(5, 300));
    expect(find.text('detail'), findsNothing,
        reason: '窄屏应由屏幕左缘触发原生侧滑返回');
  });

  testWidgets('转场进行中左栏依旧可交互', (tester) async {
    var taps = 0;
    await pumpApp(tester,
        size: const Size(1200, 800), onLeftTap: () => taps++);

    unawaited(navOf(tester).pushNamed('/detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    // 转场只允许在右栏内播放：滑入过程中内容盒不得越过 pane 左缘（600）
    final mid = tester.getRect(find.byType(Scaffold).last);
    expect(mid.left, greaterThanOrEqualTo(600),
        reason: '转场动画不能横扫左栏，实际 left=${mid.left}');

    await tester.tap(find.text('L0'));
    await tester.pumpAndSettle();
    expect(taps, 1, reason: '路由转场不应挡住左栏');
    expect(find.text('detail'), findsOneWidget);
  });

  testWidgets('pop 之后左栏恢复原状，可再次 push', (tester) async {
    await pumpApp(tester, size: const Size(1200, 800));
    final nav = navOf(tester);

    unawaited(nav.pushNamed('/detail'));
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);

    nav.pop();
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsNothing);

    unawaited(nav.pushNamed('/detail'));
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
    expect(tester.getRect(find.byType(Scaffold).last),
        const Rect.fromLTRB(600, 0, 1200, 800));
  });
}
