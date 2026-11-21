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
    EasySplit.config = EasySplitConfig()..fullscreenRoutes.add('/home');
  });

  testWidgets('宽屏：栈内已有同一页时 push 会置顶而不是重复压栈', (tester) async {
    await _pump(tester);
    _goHome(tester);

    router.push('/detail', extra: 'a');
    await tester.pumpAndSettle();
    expect(_depth, 2);

    router.push('/detail', extra: 'b');
    await tester.pumpAndSettle();
    expect(_depth, 3);
    expect(find.text('DETAIL:b'), findsOneWidget);

    router.push('/detail', extra: 'a');
    await tester.pumpAndSettle();
    // 新页被弹掉，中间的 b 也一并弹掉，a 成为栈顶。
    expect(_depth, 2);
    expect(find.text('DETAIL:a'), findsOneWidget);
    expect(find.text('DETAIL:b'), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(_depth, 1);
    expect(find.text('DETAIL:a'), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('连续 push 同一页（相同 extra）只保留一页', (tester) async {
    await _pump(tester);
    _goHome(tester);

    router.push('/detail', extra: 'a');
    router.push('/detail', extra: 'a');
    await tester.pumpAndSettle();

    expect(_depth, 2);
    expect(find.text('DETAIL:a'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(_depth, 1);
    expect(find.text('DETAIL:a'), findsNothing);
  });

  testWidgets('关闭 EasySplit.config.dedupeRepeatedRoutes 后恢复原生行为', (tester) async {
    EasySplit.config.dedupeRepeatedRoutes = false;
    await _pump(tester);
    _goHome(tester);

    router.push('/detail', extra: 'a');
    await tester.pumpAndSettle();
    router.push('/detail', extra: 'b');
    await tester.pumpAndSettle();
    router.push('/detail', extra: 'a');
    await tester.pumpAndSettle();

    expect(_depth, 4);
    // 分栏路由是非不透明（non-opaque）的，两页都在树上，所以能看到两份 a。
    expect(find.text('DETAIL:a'), findsNWidgets(2));
  });

  testWidgets('自定义 sameRoute：忽略 extra，同一路径视为同一页', (tester) async {
    EasySplit.config.sameRoute =
        (a, b) => a.name == '/detail' && b.name == '/detail';
    await _pump(tester);
    _goHome(tester);

    router.push('/detail', extra: 'a');
    await tester.pumpAndSettle();
    router.push('/detail', extra: 'b');
    await tester.pumpAndSettle();

    expect(_depth, 2);
    expect(find.text('DETAIL:a'), findsOneWidget);
    expect(find.text('DETAIL:b'), findsNothing);
  });

  testWidgets('路由级 dedupe: false：该路由保持原生行为', (tester) async {
    await _pump(tester, extraRoutes: [
      EasySplitGoRoute(
        path: '/plain',
        dedupe: false,
        builder: (_, state) => Scaffold(body: Text('PLAIN:${state.extra}')),
      ),
    ]);
    _goHome(tester);

    router.push('/plain', extra: 'x');
    await tester.pumpAndSettle();
    router.push('/plain', extra: 'x');
    await tester.pumpAndSettle();

    expect(_depth, 3);
  });

  testWidgets('窄屏 400x800：去重同样生效', (tester) async {
    await _pump(tester, size: const Size(400, 800));
    _goHome(tester);

    router.push('/detail', extra: 'a');
    await tester.pumpAndSettle();
    router.push('/detail', extra: 'a');
    await tester.pumpAndSettle();

    expect(_depth, 2);
    expect(find.text('DETAIL:a'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(_depth, 1);
  });
}

int get _depth => router.routerDelegate.currentConfiguration.matches.length;

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
        builder: (_, __) => const Scaffold(body: Center(child: Text('AD'))),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => EasySplitScope(
          child: Scaffold(
            appBar: AppBar(title: const Text('HOME')),
            body: const Center(child: Text('HOME_BODY')),
          ),
        ),
      ),
      EasySplitGoRoute(
        path: '/detail',
        builder: (_, state) =>
            Scaffold(body: Center(child: Text('DETAIL:${state.extra}'))),
      ),
      ...extraRoutes,
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

void _goHome(WidgetTester tester) {
  router.go('/home');
}
