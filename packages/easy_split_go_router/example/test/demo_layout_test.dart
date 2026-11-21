import 'package:easy_split/easy_split.dart';
import 'package:easy_split_go_router_example/pages.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    EasySplit.config = EasySplitConfig()..fullscreenRoutes.add('/home');
    DemoSplitLayout.reset();
  });

  testWidgets('分栏设置弹窗可切换自定义布局与比例', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: EasySplitScope(child: HomePage()),
    ));
    await tester.pumpAndSettle();

    Rect listRect() => tester.getRect(find.byType(Scaffold).first);
    expect(listRect(), const Rect.fromLTWH(0, 0, 600, 800));

    await tester.tap(find.text('分栏设置'));
    await tester.pumpAndSettle();
    expect(find.text('分栏布局设置'), findsOneWidget);

    await tester.tap(find.text('内容在左'));
    await tester.pumpAndSettle();
    expect(listRect(), const Rect.fromLTWH(600, 0, 600, 800));

    await tester.tap(find.text('上下分栏'));
    await tester.pumpAndSettle();
    expect(listRect(), const Rect.fromLTWH(0, 0, 1200, 400));

    await tester.tap(find.text('悬浮内容栏'));
    await tester.pumpAndSettle();
    expect(listRect(), const Rect.fromLTWH(0, 0, 600, 800));

    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();
    expect(DemoSplitLayout.isDefault, isTrue);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('分栏布局设置'), findsNothing);
  });
}
