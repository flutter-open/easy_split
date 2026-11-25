// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:easy_split/easy_split.dart';
import 'package:easy_split_getx/easy_split_getx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

GetPage _page(String name, {bool fullscreen = false}) {
  return EasySplitGetPage(
    name: name,
    fullscreen: fullscreen,
    page: () => const Text('page'),
  );
}

void main() {
  setUp(() {
    Get.clearRouteTree();
    EasySplit.config.fullscreenRoutes.clear();
  });

  testWidgets('EasySplitGetPage creates a pane route', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));
    final page = _page('/detail/:id');
    Get.addPage(page);

    final route = page.createRoute(context);
    expect(route, isA<EasySplitGetPageRoute<dynamic>>());
    expect((route as ModalRoute<dynamic>).opaque, isFalse);
  });

  testWidgets('EasySplitGetPage keeps fullscreen pages fullscreen',
      (tester) async {
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));
    final page = _page('/full', fullscreen: true);
    Get.addPage(page);

    final route = page.createRoute(context);
    expect(route, isA<GetPageRoute<dynamic>>());
    expect(route, isNot(isA<EasySplitGetPageRoute<dynamic>>()));
    expect((route as ModalRoute<dynamic>).opaque, isTrue);
  });

  test('copy keeps the subtype and the fullscreen flag', () {
    final page = _page('/detail/:id', fullscreen: true).copy(name: '/detail/1');
    expect(page, isA<EasySplitGetPage<dynamic>>());
    expect((page as EasySplitGetPage<dynamic>).fullscreen, isTrue);
  });

  test('onGenerateRoute adapter wraps pane pages only', () {
    final factory = easySplitGetRouteAdapter(pages: [
      GetPage(name: '/', page: () => const Text('home')),
      _page('/detail/:id'),
      _page('/full', fullscreen: true),
    ]);

    final home = factory(const RouteSettings(name: '/'))!;
    expect(home, isNot(isA<EasySplitGetPageRoute<dynamic>>()));
    expect((home as ModalRoute<dynamic>).opaque, isTrue);

    final detail = factory(const RouteSettings(name: '/detail/1'))!;
    expect(detail, isA<EasySplitGetPageRoute<dynamic>>());
    final detailRoute = detail as ModalRoute<dynamic>;
    expect(detailRoute.opaque, isFalse);
    expect(detailRoute.barrierColor, Colors.transparent);

    final full = factory(const RouteSettings(name: '/full'))!;
    expect(full, isNot(isA<EasySplitGetPageRoute<dynamic>>()));
    expect((full as ModalRoute<dynamic>).opaque, isTrue);
  });

  test('onGenerateRoute adapter respects EasySplit.fullscreenRoutes', () {
    EasySplit.config.fullscreenRoutes.add('/secondary');
    final factory = easySplitGetRouteAdapter(pages: [
      _page('/secondary'),
    ]);
    final route = factory(const RouteSettings(name: '/secondary'))!;
    expect(route, isNot(isA<EasySplitGetPageRoute<dynamic>>()));
  });

  testWidgets('pane route builds and keeps GetX transitions', (tester) async {
    final factory = easySplitGetRouteAdapter(pages: [_page('/detail/1')]);
    final route = factory(const RouteSettings(name: '/detail/1'))!;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => Navigator.of(context).push(route),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('page'), findsOneWidget);
    expect(find.byType(EasySplitPaneFrame), findsWidgets);
    expect(find.byType(EasySplitPaneHitTest), findsWidgets);
    expect(find.byType(EasySplitPaneTeleport), findsWidgets);
  });
}
