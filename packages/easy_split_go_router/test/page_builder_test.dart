import 'package:easy_split/easy_split.dart';
import 'package:easy_split_go_router/easy_split_go_router.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

late GoRouter router;

void main() {
  setUp(() {
    EasySplit.config = EasySplitConfig();
  });

  testWidgets('宽屏：pageBuilder 返回 MaterialPage 也会走分栏路由', (tester) async {
    await _pump(tester, extraRoutes: [_materialPageRoute()]);

    router.push('/pb', extra: <String, dynamic>{'id': 1});
    await tester.pumpAndSettle();

    expect(find.text('PB'), findsOneWidget);
    expect(find.byType(EasySplitPaneHitTest), findsOneWidget);
    // 页面落在右栏（600..1200）而不是整屏。
    expect(tester.getRect(find.text('PB')).center.dx, closeTo(900, 1));

    final ModalRoute<dynamic>? route =
        ModalRoute.of(tester.element(find.text('PB')));
    expect(route, isA<EasySplitRoute<dynamic>>());

    final EasySplitPage<dynamic> page = _topPage(tester);
    expect(page.name, '/pb');
    expect(page.arguments, <String, dynamic>{'id': 1});
  });

  testWidgets('窄屏：pageBuilder 返回 MaterialPage 时整屏显示', (tester) async {
    await _pump(
      tester,
      size: const Size(400, 800),
      extraRoutes: [_materialPageRoute()],
    );

    router.push('/pb');
    await tester.pumpAndSettle();

    expect(find.text('PB'), findsOneWidget);
    // 窄屏也走 EasySplitRoute（非全屏默认），但内容占满整屏。
    expect(tester.getRect(find.text('PB')).center.dx, closeTo(200, 1));

    final ModalRoute<dynamic>? route =
        ModalRoute.of(tester.element(find.text('PB')));
    expect(route, isA<EasySplitRoute<dynamic>>());
  });

  testWidgets('fullscreen: true 时 pageBuilder 页面走原生全屏路由', (tester) async {
    await _pump(tester, extraRoutes: [
      EasySplitGoRoute(
        path: '/pb',
        fullscreen: true,
        pageBuilder: (_, __) => const MaterialPage<void>(
          child: Scaffold(body: Center(child: Text('PB'))),
        ),
      ),
    ]);

    router.push('/pb');
    await tester.pumpAndSettle();

    expect(find.text('PB'), findsOneWidget);
    expect(find.byType(EasySplitPaneHitTest), findsNothing);
    final ModalRoute<dynamic>? route =
        ModalRoute.of(tester.element(find.text('PB')));
    expect(route, isA<MaterialPageRoute<dynamic>>());
    expect(route, isNot(isA<EasySplitRoute<dynamic>>()));
  });

  testWidgets('fullscreenRoutes 命中的 pageBuilder 页面仍按路径保持全屏', (tester) async {
    EasySplit.config.fullscreenRoutes.add('/pb');
    await _pump(tester, extraRoutes: [
      EasySplitGoRoute(
        path: '/pb',
        pageBuilder: (_, __) => const MaterialPage<void>(
          name: '/pb-custom',
          child: Scaffold(body: Center(child: Text('PB'))),
        ),
      ),
    ]);

    router.push('/pb');
    await tester.pumpAndSettle();

    final ModalRoute<dynamic>? route =
        ModalRoute.of(tester.element(find.text('PB')));
    expect(route, isA<MaterialPageRoute<dynamic>>());
  });

  testWidgets('MaterialPage 的 key/name/arguments/restorationId 原样保留', (tester) async {
    await _pump(tester, extraRoutes: [
      EasySplitGoRoute(
        path: '/pb',
        pageBuilder: (_, __) => const MaterialPage<void>(
          key: ValueKey<String>('pb-key'),
          name: '/pb-custom',
          arguments: 'from-page',
          restorationId: 'pb-restoration',
          child: Scaffold(body: Center(child: Text('PB'))),
        ),
      ),
    ]);

    router.push('/pb', extra: 'from-extra');
    await tester.pumpAndSettle();

    final EasySplitPage<dynamic> page = _topPage(tester);
    expect(page.key, const ValueKey<String>('pb-key'));
    expect(page.name, '/pb-custom');
    expect(page.arguments, 'from-page');
    expect(page.restorationId, 'pb-restoration');
  });

  testWidgets('CustomTransitionPage 的自定义转场会被保留', (tester) async {
    final Duration transitionDuration = const Duration(milliseconds: 450);
    final Duration reverseTransitionDuration = const Duration(milliseconds: 200);
    await _pump(tester, extraRoutes: [
      EasySplitGoRoute(
        path: '/pb',
        pageBuilder: (_, __) => CustomTransitionPage<void>(
          transitionDuration: transitionDuration,
          reverseTransitionDuration: reverseTransitionDuration,
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          child: const Scaffold(body: Center(child: Text('PB'))),
        ),
      ),
    ]);

    router.push('/pb');
    await tester.pumpAndSettle();

    final EasySplitPage<dynamic> page = _topPage(tester);
    expect(page.transitionsBuilder, isNotNull);
    expect(page.transitionDuration, transitionDuration);
    expect(page.reverseTransitionDuration, reverseTransitionDuration);

    final ModalRoute<dynamic>? route =
        ModalRoute.of(tester.element(find.text('PB')));
    expect(route, isA<EasySplitRoute<dynamic>>());
    expect(route!.transitionDuration, transitionDuration);
    expect(route.reverseTransitionDuration, reverseTransitionDuration);
  });

  testWidgets('pageBuilder 路由同样参与去重', (tester) async {
    await _pump(tester, extraRoutes: [_materialPageRoute()]);

    router.push('/pb', extra: 'a');
    await tester.pumpAndSettle();
    router.push('/pb', extra: 'a');
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.matches.length, 2);
    expect(find.text('PB'), findsOneWidget);
  });

  test('builder 与 pageBuilder 必须且只能传一个', () {
    expect(
      () => EasySplitGoRoute(path: '/x'),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => EasySplitGoRoute(
        path: '/x',
        builder: (_, __) => const SizedBox(),
        pageBuilder: (_, __) => const MaterialPage<void>(child: SizedBox()),
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}

EasySplitGoRoute _materialPageRoute() {
  return EasySplitGoRoute(
    path: '/pb',
    pageBuilder: (_, __) => const MaterialPage<void>(
      child: Scaffold(body: Center(child: Text('PB'))),
    ),
  );
}

EasySplitPage<dynamic> _topPage(WidgetTester tester) {
  final Navigator navigator = tester.widget<Navigator>(find.byType(Navigator));
  final List<EasySplitPage<dynamic>> pages =
      navigator.pages.whereType<EasySplitPage<dynamic>>().toList();
  expect(pages, isNotEmpty);
  return pages.last;
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(1200, 800),
  List<GoRoute> extraRoutes = const <GoRoute>[],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Center(child: Text('ROOT'))),
      ),
      ...extraRoutes,
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}
