import 'package:easy_split/easy_split.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// 测试页面：全部使用原生 Navigator API 跳转（与 example/lib/main.dart 一致）
// ---------------------------------------------------------------------------

class _AdPage extends StatelessWidget {
  const _AdPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
          child: const Text('GO_HOME'),
        ),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return EasySplitScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('HOME')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/detail',
                  arguments: 'arg-42',
                ),
                child: const Text('GO_DETAIL'),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/detail',
                  arguments: 'detail-a',
                ),
                child: const Text('GO_DETAIL_A'),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/detail',
                  arguments: 'detail-b',
                ),
                child: const Text('GO_DETAIL_B'),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/secondary',
                  (route) => route.isFirst,
                ),
                child: const Text('GO_SECONDARY'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPage extends StatelessWidget {
  const _DetailPage();

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments;
    return Scaffold(
      appBar: AppBar(title: const Text('DETAIL')),
      body: Center(child: Text('DETAIL_ARGS:$args')),
    );
  }
}

class _SecondaryPage extends StatelessWidget {
  const _SecondaryPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SECONDARY')),
      body: const Center(child: Text('SECONDARY_BODY')),
    );
  }
}

// ---------------------------------------------------------------------------
// 测试宿主：routerConfig 只创建一次（与文档要求一致）
// ---------------------------------------------------------------------------

const _home = 'HOME';
const _placeholder = '从左侧选择内容查看详情';

final Map<String, WidgetBuilder> _pageBuilders = <String, WidgetBuilder>{
  '/home': (_) => const _HomePage(),
  '/detail': (_) => const _DetailPage(),
  '/secondary': (_) => const _SecondaryPage(),
};

/// 使用 `EasySplit.nativeRouterConfig(delegate:)`（需要持有 delegate）
class _DelegateApp extends StatefulWidget {
  const _DelegateApp({this.onDelegate, this.observers = const []});

  final void Function(EasySplitRouterDelegate delegate)? onDelegate;
  final List<NavigatorObserver> observers;

  @override
  State<_DelegateApp> createState() => _DelegateAppState();
}

class _DelegateAppState extends State<_DelegateApp> {
  late final EasySplitRouterDelegate delegate = EasySplitRouterDelegate(
    home: const _AdPage(),
    pageBuilders: _pageBuilders,
    observers: widget.observers,
  );
  late final RouterConfig<String> config =
      EasySplit.nativeRouterConfig(delegate: delegate);

  @override
  void initState() {
    super.initState();
    widget.onDelegate?.call(delegate);
  }

  @override
  Widget build(BuildContext context) =>
      MaterialApp.router(routerConfig: config);
}

/// 使用一行的 `easySplitNativeRouterConfig(home:, pageBuilders:)`
class _HelperApp extends StatefulWidget {
  const _HelperApp();

  @override
  State<_HelperApp> createState() => _HelperAppState();
}

class _HelperAppState extends State<_HelperApp> {
  late final RouterConfig<String> config = easySplitNativeRouterConfig(
    home: const _AdPage(),
    pageBuilders: _pageBuilders,
  );

  @override
  Widget build(BuildContext context) =>
      MaterialApp.router(routerConfig: config);
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(1200, 800),
  Widget widget = const _DelegateApp(),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

Future<void> _goHome(WidgetTester tester) async {
  await tester.tap(find.text('GO_HOME'));
  await tester.pumpAndSettle();
}

Future<void> _goDetail(WidgetTester tester) async {
  await tester.tap(find.text('GO_DETAIL'));
  await tester.pumpAndSettle();
}

/// 导航栈深度（每个页面一个 Scaffold）
int _stackDepth(WidgetTester tester) => find.byType(Scaffold).evaluate().length;

void main() {
  setUp(() {
    // 与 main.dart 相同的配置：'/home' 全屏，内部自己分栏
    EasySplit.config = EasySplitConfig()..fullscreenRoutes.add('/home');
  });

  group('MaterialApp.router + EasySplitRouterDelegate（宽屏分栏）', () {
    testWidgets('启动路由 / 是全屏 AdPage，不自动包 EasySplitScope', (tester) async {
      await _pump(tester);

      expect(find.text('GO_HOME'), findsOneWidget);
      // 与 main.dart 的 home: AdPage() 一致：首路由不被分栏
      expect(find.byType(EasySplitScope), findsNothing);
      expect(tester.getRect(find.byType(Scaffold)).width, 1200);
    });

    testWidgets('pushReplacementNamed(/home) 后左栏 600 + 右栏占位', (tester) async {
      await _pump(tester);
      await _goHome(tester);

      expect(find.text('GO_HOME'), findsNothing);
      expect(find.byType(EasySplitScope), findsOneWidget);
      expect(find.text(_home), findsOneWidget);
      expect(find.text(_placeholder), findsOneWidget);

      final left = tester.getRect(find.byType(AppBar));
      expect(left.left, 0);
      expect(left.width, 600);
    });

    testWidgets('pushNamed(/detail) 落在右栏，arguments 原样保留', (tester) async {
      await _pump(tester);
      await _goHome(tester);
      await _goDetail(tester);

      expect(find.text('DETAIL_ARGS:arg-42'), findsOneWidget);
      // 右栏从 x=600 开始，铺满右栏矩形
      final pane = tester.getRect(find.byType(Scaffold).last);
      expect(pane.left, 600);
      expect(pane.top, 0);
      expect(pane.width, 600);
      expect(pane.height, 800);
      // 左栏首页仍可见（pane 路由 non-opaque）
      expect(find.text(_home), findsOneWidget);
    });

    testWidgets('右栏返回按钮 pop 后恢复占位', (tester) async {
      await _pump(tester);
      await _goHome(tester);
      await _goDetail(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('DETAIL_ARGS:arg-42'), findsNothing);
      expect(find.text(_placeholder), findsOneWidget);
      expect(find.text(_home), findsOneWidget);
    });

    testWidgets('pushNamedAndRemoveUntil 与原生一致', (tester) async {
      await _pump(tester);
      await _goHome(tester);

      await tester.tap(find.text('GO_SECONDARY'));
      await tester.pumpAndSettle();

      expect(find.text('SECONDARY_BODY'), findsOneWidget);
      // AdPage 已被 pushReplacementNamed 替换，'/home' 即栈底：
      // 保留 '/home' 并压入 '/secondary'，返回后回到首页
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('SECONDARY_BODY'), findsNothing);
      expect(find.text(_home), findsOneWidget);
    });

    testWidgets('系统返回：delegate.popRoute 弹出右栏路由', (tester) async {
      late EasySplitRouterDelegate delegate;
      await _pump(
        tester,
        widget: _DelegateApp(onDelegate: (d) => delegate = d),
      );
      await _goHome(tester);
      await _goDetail(tester);

      final handled = await delegate.popRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.text('DETAIL_ARGS:arg-42'), findsNothing);
      expect(find.text(_placeholder), findsOneWidget);
    });

    testWidgets('delegate.push / pop 等值于 Navigator.pushNamed / pop',
        (tester) async {
      late EasySplitRouterDelegate delegate;
      await _pump(
        tester,
        widget: _DelegateApp(onDelegate: (d) => delegate = d),
      );
      await _goHome(tester);

      delegate.push('/detail', arguments: 'via-delegate');
      await tester.pumpAndSettle();
      expect(find.text('DETAIL_ARGS:via-delegate'), findsOneWidget);
      expect(tester.getRect(find.byType(Scaffold).last).left, 600);

      expect(await delegate.pop(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('DETAIL_ARGS:via-delegate'), findsNothing);
      expect(find.text(_home), findsOneWidget);
    });

    testWidgets('深链同步：setNewRoutePath 推入 / 收起路由', (tester) async {
      late EasySplitRouterDelegate delegate;
      await _pump(
        tester,
        widget: _DelegateApp(onDelegate: (d) => delegate = d),
      );
      await _goHome(tester);

      // 深链 '/detail' → 压入右栏
      await delegate.setNewRoutePath('/detail');
      await tester.pumpAndSettle();
      expect(find.text('DETAIL'), findsOneWidget);
      expect(tester.getRect(find.byType(Scaffold).last).left, 600);

      // 回到根：popUntil(isFirst)，首页恢复
      await delegate.setNewRoutePath('/');
      await tester.pumpAndSettle();
      expect(find.text('DETAIL'), findsNothing);
      expect(find.text(_home), findsOneWidget);
    });
  });

  group('MaterialApp.router（窄屏全屏）', () {
    testWidgets('窄屏：detail 全屏盖住 home，返回可恢复', (tester) async {
      await _pump(tester, size: const Size(400, 800));

      await _goHome(tester);
      expect(tester.getRect(find.byType(AppBar)).width, 400);

      await _goDetail(tester);
      expect(find.text('DETAIL_ARGS:arg-42'), findsOneWidget);
      final pane = tester.getRect(find.byType(Scaffold).last);
      expect(pane.left, 0);
      expect(pane.top, 0);
      expect(pane.width, 400);
      expect(pane.height, 800);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(_home), findsOneWidget);
    });
  });

  group('一行接入', () {
    testWidgets('easySplitNativeRouterConfig 可用且导航正常', (tester) async {
      await _pump(tester, widget: const _HelperApp());

      expect(find.text('GO_HOME'), findsOneWidget);
      await _goHome(tester);
      await _goDetail(tester);

      expect(find.text('DETAIL_ARGS:arg-42'), findsOneWidget);
      expect(tester.getRect(find.byType(Scaffold).last).left, 600);
    });
  });

  group('重复路由去重（默认开启）', () {
    testWidgets('栈内已有同一路由：置顶而不是重复压栈', (tester) async {
      await _pump(tester);
      await _goHome(tester);

      // A → B → A：第三次命中的是栈内已有的 A，B 被弹出
      await tester.tap(find.text('GO_DETAIL_A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GO_DETAIL_B'));
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 3); // home + A + B

      await tester.tap(find.text('GO_DETAIL_A'));
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 2); // home + A（B 已弹出）
      expect(find.text('DETAIL_ARGS:detail-a'), findsOneWidget);
      expect(find.text('DETAIL_ARGS:detail-b'), findsNothing);

      // 返回一次即可回到占位
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.textContaining('DETAIL_ARGS:'), findsNothing);
      expect(_stackDepth(tester), 1);
    });

    testWidgets('连续点击同一页面不重复压栈', (tester) async {
      await _pump(tester);
      await _goHome(tester);

      await tester.tap(find.text('GO_DETAIL_A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GO_DETAIL_A'));
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 2); // home + 一条 detail

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.textContaining('DETAIL_ARGS:'), findsNothing);
      expect(_stackDepth(tester), 1);
    });

    testWidgets('Map 参数结构相等（键顺序不同）也视为同一页', (tester) async {
      late EasySplitRouterDelegate delegate;
      await _pump(tester,
          widget: _DelegateApp(onDelegate: (d) => delegate = d));
      await _goHome(tester);

      delegate.push('/detail', arguments: {
        'id': 1,
        'meta': {'tab': 'a'},
      });
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 2);

      delegate.push('/detail', arguments: {
        'meta': {'tab': 'a'},
        'id': 1,
      });
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 2);
    });

    testWidgets('Map 参数深层值不同：照常压栈', (tester) async {
      late EasySplitRouterDelegate delegate;
      await _pump(tester,
          widget: _DelegateApp(onDelegate: (d) => delegate = d));
      await _goHome(tester);

      delegate.push('/detail', arguments: {
        'id': 1,
        'meta': {'tab': 'a'},
      });
      await tester.pumpAndSettle();
      delegate.push('/detail', arguments: {
        'id': 1,
        'meta': {'tab': 'b'},
      });
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 3);
    });

    testWidgets('自定义 sameRoute：按业务规则判定是否同一页面', (tester) async {
      EasySplit.config.sameRoute =
          (a, b) => a.name == '/detail' && b.name == '/detail';
      await _pump(tester);
      await _goHome(tester);

      await tester.tap(find.text('GO_DETAIL_A'));
      await tester.pumpAndSettle();
      // 任意 /detail 都视为同一页面：B 不再压栈
      await tester.tap(find.text('GO_DETAIL_B'));
      await tester.pumpAndSettle();

      expect(_stackDepth(tester), 2);
      expect(find.text('DETAIL_ARGS:detail-a'), findsOneWidget);
      expect(find.text('DETAIL_ARGS:detail-b'), findsNothing);
    });

    testWidgets('关闭去重后恢复原生重复压栈', (tester) async {
      EasySplit.config.dedupeRepeatedRoutes = false;
      late EasySplitRouterDelegate delegate;
      await _pump(tester,
          widget: _DelegateApp(onDelegate: (d) => delegate = d));
      await _goHome(tester);

      await tester.tap(find.text('GO_DETAIL_A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GO_DETAIL_B'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GO_DETAIL_A'));
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 4); // home + A + B + A

      await delegate.popRoute();
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 3);

      await delegate.popRoute();
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 2);

      await delegate.popRoute();
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 1);
    });
  });

  group('重复路由去重（窄屏）', () {
    testWidgets('窄屏同样去重', (tester) async {
      late EasySplitRouterDelegate delegate;
      await _pump(
        tester,
        size: const Size(400, 800),
        widget: _DelegateApp(onDelegate: (d) => delegate = d),
      );
      await _goHome(tester);

      delegate.push('/detail', arguments: 'detail-a');
      await tester.pumpAndSettle();
      delegate.push('/detail', arguments: 'detail-a');
      await tester.pumpAndSettle();
      expect(_stackDepth(tester), 2);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.textContaining('DETAIL_ARGS:'), findsNothing);
      expect(_stackDepth(tester), 1);
    });
  });

  group('参数透传', () {
    test(
        'EasySplitRoute 透传 maintainState / fullscreenDialog / allowSnapshotting',
        () {
      final route = EasySplitRoute<bool>(
        builder: (_) => const SizedBox(),
        maintainState: false,
        fullscreenDialog: true,
        allowSnapshotting: false,
      );
      expect(route.maintainState, isFalse);
      expect(route.fullscreenDialog, isTrue);
      expect(route.allowSnapshotting, isFalse);
      expect(route.opaque, isFalse);
    });

    testWidgets('EasySplitPage.createRoute 透传参数', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));

      final panePage = EasySplitPage<void>(
        child: (_) => const SizedBox(),
        name: '/pane-param',
        maintainState: false,
        fullscreenDialog: true,
        allowSnapshotting: false,
      );
      final paneRoute = panePage.createRoute(context);
      expect(paneRoute, isA<EasySplitRoute<void>>());
      final route = paneRoute as EasySplitRoute<void>;
      expect(route.maintainState, isFalse);
      expect(route.fullscreenDialog, isTrue);
      expect(route.allowSnapshotting, isFalse);

      final fullPage = EasySplitPage<void>(
        child: (_) => const SizedBox(),
        name: '/fullscreen-param',
        fullscreen: true,
        maintainState: false,
        fullscreenDialog: true,
      );
      final fullRoute = fullPage.createRoute(context);
      expect(fullRoute, isA<MaterialPageRoute<void>>());
      final materialRoute = fullRoute as MaterialPageRoute<void>;
      expect(materialRoute.maintainState, isFalse);
      expect(materialRoute.fullscreenDialog, isTrue);
    });

    testWidgets('EasySplitScope.placeholderBuilder 覆盖默认占位', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: EasySplitScope(
            placeholderBuilder: (_) => const Text('CUSTOM_EMPTY'),
            child: const Scaffold(body: Center(child: Text('LEFT'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LEFT'), findsOneWidget);
      expect(find.text('CUSTOM_EMPTY'), findsOneWidget);
      expect(find.text(_placeholder), findsNothing);
    });

    testWidgets('observers 透传给内部 Navigator', (tester) async {
      final observer = _RecordingObserver();
      await _pump(tester, widget: _DelegateApp(observers: [observer]));
      await _goHome(tester);
      expect(observer.pushed, contains('/home'));
    });
  });
}

class _RecordingObserver extends NavigatorObserver {
  final List<String?> pushed = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route.settings.name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) pushed.add(newRoute.settings.name);
  }
}
