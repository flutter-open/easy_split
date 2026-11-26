import 'package:easy_split/easy_split.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// 标准 MaterialApp + onGenerateRoute 方案：验证 EasySplit.dedupeObserver
// ---------------------------------------------------------------------------

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HOME')),
      body: Column(
        children: [
          TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, '/detail', arguments: 'a'),
            child: const Text('GO_A'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, '/detail', arguments: 'b'),
            child: const Text('GO_B'),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(
              context,
              '/web',
              arguments: {
                'url': 'https://example.com/item/1',
                'headerMap': {'token': 'abc'},
              },
            ),
            child: const Text('GO_WEB_SAME'),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(
              context,
              '/web',
              arguments: {
                'url': 'https://example.com/item/1',
                'headerMap': {'token': 'xyz'},
              },
            ),
            child: const Text('GO_WEB_OTHER'),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail();

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments;
    return Scaffold(
      appBar: AppBar(title: const Text('DETAIL')),
      body: Center(child: Text('ARGS:$args')),
    );
  }
}

class _Web extends StatelessWidget {
  const _Web();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('WEB_PAGE')),
    );
  }
}

class _App extends StatelessWidget {
  const _App({required this.observers});

  final List<NavigatorObserver> observers;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: observers,
      home: const EasySplitScope(child: _Home()),
      onGenerateRoute: EasySplit.routeAdapter({
        '/detail': (_) => const _Detail(),
        '/web': (_) => const _Web(),
      }),
    );
  }
}

/// 导航栈深度（每个页面一个 Scaffold）
int _stackDepth(WidgetTester tester) => find.byType(Scaffold).evaluate().length;

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(1200, 800),
  List<NavigatorObserver>? observers,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _App(observers: observers ?? [EasySplit.dedupeObserver]),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    EasySplit.config = EasySplitConfig();
  });

  group('onGenerateRoute 方案 + EasySplit.dedupeObserver', () {
    testWidgets('栈内已有同一路由：置顶而不是重复压栈', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('GO_A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GO_B'));
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 3); // home + A + B

      await tester.tap(find.text('GO_A'));
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 2); // home + A（B 已弹出）
      expect(find.text('ARGS:a'), findsOneWidget);
      expect(find.text('ARGS:b'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 1);
      expect(find.text('ARGS:a'), findsNothing);
    });

    testWidgets('观察者实例每次 build 重建也不丢栈', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('GO_A'));
      await tester.pumpAndSettle();

      // 重建整棵树，换一个全新的 observer 实例（共享 Expando 状态）
      await _pump(tester);
      expect(_stackDepth(tester), 2);

      await tester.tap(find.text('GO_B'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GO_A'));
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 2);
      expect(find.text('ARGS:b'), findsNothing);
    });

    testWidgets('关闭去重后恢复原生重复压栈', (tester) async {
      EasySplit.config.dedupeRepeatedRoutes = false;
      await _pump(tester);

      await tester.tap(find.text('GO_A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GO_B'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GO_A'));
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 4);
    });

    testWidgets('自定义 sameRoute：按业务规则判定是否同一页面', (tester) async {
      EasySplit.config.sameRoute =
          (a, b) => a.name == '/detail' && b.name == '/detail';
      await _pump(tester);

      await tester.tap(find.text('GO_A'));
      await tester.pumpAndSettle();
      // 任意 /detail 都视为同一页面：B 的压栈被摘掉
      await tester.tap(find.text('GO_B'));
      await tester.pumpAndSettle();

      expect(_stackDepth(tester), 2);
      expect(find.text('ARGS:a'), findsOneWidget);
      expect(find.text('ARGS:b'), findsNothing);
    });

    testWidgets('Map 参数内容相同（不同实例）也去重', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('GO_WEB_SAME'));
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 2);

      // 修复前 `arguments == arguments` 是引用比较，这里会压成 3 层
      await tester.tap(find.text('GO_WEB_SAME'));
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 2);
      expect(find.text('WEB_PAGE'), findsOneWidget);
    });

    testWidgets('Map 参数深层值不同：照常压栈', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('GO_WEB_SAME'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GO_WEB_OTHER'));
      await tester.pumpAndSettle();

      expect(_stackDepth(tester), 3);
    });

    testWidgets('未添加观察者时保持原生行为（不自动去重）', (tester) async {
      await _pump(tester, observers: <NavigatorObserver>[]);

      await tester.tap(find.text('GO_A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GO_B'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GO_A'));
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 4);
    });
  });
}
