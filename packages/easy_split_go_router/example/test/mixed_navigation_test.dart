import 'package:easy_split/easy_split.dart';
import 'package:easy_split_go_router_example/main_mixed.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    EasySplit.config = EasySplitConfig()
      ..fullscreenRoutes.addAll(<String>['/', '/home']);
    mixedRouter.go('/');
  });

  Rect webViewRect(WidgetTester tester) => tester.getRect(
    find.descendant(
      of: find.byType(WebViewPage),
      matching: find.byType(Scaffold),
    ),
  );

  Future<void> openHome(WidgetTester tester) async {
    await tester.pumpWidget(const MixedDemoApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('进入首页'));
    await tester.pumpAndSettle();
  }

  Future<void> disposeOverlay(WidgetTester tester) async {
    if (find.text('关闭浮层').evaluate().isNotEmpty) {
      await tester.tap(find.text('关闭浮层'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('同一 H5 与相同 header 连点两次只压一页，且落在右栏', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openHome(tester);

    await tester.tap(find.text('同一 H5 连点两次'));
    await tester.pumpAndSettle();

    expect(find.byType(WebViewPage), findsOneWidget);
    expect(webViewRect(tester), const Rect.fromLTWH(600, 0, 600, 800));
    expect(find.text('headers: {token: abc}'), findsOneWidget);
  });

  testWidgets('同 url 不同 header 正常叠页，整窗 H5 铺满全屏', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openHome(tester);

    await tester.tap(find.text('同一 H5、不同 header'));
    await tester.pumpAndSettle();
    expect(find.byType(WebViewPage), findsOneWidget);
    expect(find.text('headers: {token: xyz}'), findsOneWidget);

    await tester.tap(find.text('再打开一个 H5'));
    await tester.pumpAndSettle();
    expect(find.byType(WebViewPage), findsNWidgets(2));

    // 两层 WebView 各有返回按钮，只点最上层那一个
    await tester.tap(
      find.descendant(
        of: find.byType(WebViewPage).last,
        matching: find.byIcon(Icons.arrow_back),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(WebViewPage).last,
        matching: find.byIcon(Icons.arrow_back),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('整窗 H5（支付/风控）'));
    await tester.pumpAndSettle();
    expect(webViewRect(tester), const Rect.fromLTWH(0, 0, 1200, 800));
    expect(find.text('当前整窗显示'), findsOneWidget);

    await disposeOverlay(tester);
  });

  testWidgets('面板浮层按栏约束，关闭后消失', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openHome(tester);

    await tester.tap(find.text('右栏浮层'));
    await tester.pumpAndSettle();
    final Rect rightText = tester.getRect(find.text('右侧浮层已打开'));
    expect(rightText.center.dx, greaterThan(600));

    await tester.tap(find.text('关闭浮层'));
    await tester.pumpAndSettle();
    expect(find.text('右侧浮层已打开'), findsNothing);
    expect(find.text('关闭浮层'), findsNothing);

    await tester.tap(find.text('左栏浮层'));
    await tester.pumpAndSettle();
    final Rect leftText = tester.getRect(find.text('左侧浮层已打开'));
    expect(leftText.center.dx, lessThan(600));

    // 窄窗折叠后浮层随内容区铺满整窗
    tester.view.physicalSize = const Size(500, 800);
    await tester.pumpAndSettle();
    final Rect folded = tester.getRect(find.text('左侧浮层已打开'));
    expect(folded.center.dx, closeTo(250, 1));

    await tester.tap(find.text('关闭浮层'));
    await tester.pumpAndSettle();
    expect(find.text('左侧浮层已打开'), findsNothing);
  });
}
