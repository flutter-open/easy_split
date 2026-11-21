import 'package:easy_split/easy_split.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    EasySplit.config = EasySplitConfig()..fullscreenRoutes.add('/home');
  });

  Future<void> pumpApp(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: EasySplitScope(
        child: Scaffold(
          appBar: AppBar(title: const Text('HOME')),
          body: Center(
            child: Builder(
              builder: (context) => FilledButton(
                onPressed: () => Navigator.pushNamed(context, '/detail'),
                child: const Text('GO_DETAIL'),
              ),
            ),
          ),
        ),
      ),
      onGenerateRoute: EasySplit.routeAdapter({
        '/detail': (_) => const Scaffold(body: Center(child: Text('DETAIL'))),
      }),
    ));
    await tester.pumpAndSettle();
  }

  Rect leftRect(WidgetTester tester) =>
      tester.getRect(find.byType(Scaffold).first);

  testWidgets('updateLayout 后左栏宽度立即跟随 paneRatio', (tester) async {
    await pumpApp(tester, const Size(1200, 800));
    expect(leftRect(tester), const Rect.fromLTWH(0, 0, 600, 800));

    EasySplit.paneRatio = 0.35;
    EasySplit.updateLayout();
    await tester.pump();

    expect(leftRect(tester), const Rect.fromLTWH(0, 0, 780, 800));
  });

  testWidgets('updateLayout 后已打开的分栏路由立即重排', (tester) async {
    await pumpApp(tester, const Size(1200, 800));
    await tester.tap(find.text('GO_DETAIL'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(Scaffold).last),
        const Rect.fromLTWH(600, 0, 600, 800));

    EasySplit.paneRatio = 0.4;
    EasySplit.updateLayout();
    await tester.pump();

    expect(tester.getRect(find.byType(Scaffold).last),
        const Rect.fromLTWH(720, 0, 480, 800));
  });

  testWidgets('layoutDelegate 交换左右栏后，列表与分栏路由一起换边', (tester) async {
    EasySplit.config.layoutDelegate = (context) {
      final layout = EasySplit.defaultLayout(context);
      return EasySplitLayout(
        leftRect: layout.paneRect,
        paneRect: layout.leftRect,
      );
    };
    await pumpApp(tester, const Size(1200, 800));
    expect(leftRect(tester), const Rect.fromLTWH(600, 0, 600, 800));

    await tester.tap(find.text('GO_DETAIL'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(Scaffold).last),
        const Rect.fromLTWH(0, 0, 600, 800));
  });

  testWidgets('自定义上下分栏后，分栏路由落在下方的 paneRect', (tester) async {
    EasySplit.config.layoutDelegate = (context) {
      final layout = EasySplit.defaultLayout(context);
      final width = layout.leftRect.width + layout.paneRect.width;
      final height = layout.leftRect.height;
      final paneHeight = height * EasySplit.paneRatio;
      return EasySplitLayout(
        leftRect: Rect.fromLTWH(0, 0, width, height - paneHeight),
        paneRect: Rect.fromLTWH(0, height - paneHeight, width, paneHeight),
      );
    };
    await pumpApp(tester, const Size(1200, 800));
    expect(leftRect(tester), const Rect.fromLTWH(0, 0, 1200, 400));

    await tester.tap(find.text('GO_DETAIL'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(Scaffold).last),
        const Rect.fromLTWH(0, 400, 1200, 400));
  });
}
