import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_split/easy_split.dart';

/// 仅改变表面尺寸，触发 MediaQuery/LayoutBuilder 重建（不重建页面树）
Future<void> setSurface(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpAndSettle();
}

Widget host() => MaterialApp(
      home: EasySplitScope(
        child: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/detail', arguments: 1),
                  child: const Text('OPEN'),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/filter'),
                  child: const Text('FILTER_BTN'),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('LOGIN_BTN'),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/cupertino'),
                  child: const Text('CUPERTINO_BTN'),
                ),
              ],
            ),
          ),
        ),
      ),
      onGenerateRoute: (settings) {
        // 接入点 2：适配器 + 用户自定义路由工厂组合
        final adapted = EasySplit.routeAdapter({
          '/detail': (_) => const Text('DETAIL'),
          '/filter': (_) => const Text('FILTER'),
          '/login': (_) => const Text('LOGIN'),
        })(settings);
        if (adapted != null) return adapted;
        // 用户自定义路由工厂：返回 CupertinoPageRoute 也会被拦截转换
        if (settings.name == '/cupertino') {
          return EasySplit.adaptRoute(
            settings,
            (_) => const Text('CUPERTINO'),
          );
        }
        return null;
      },
    );

void main() {
  setUp(() {
    EasySplit.enabled = true;
    EasySplit.config.layoutBuilder = null;
    EasySplit.layoutDelegate = null;
    EasySplit.placeholderBuilder = null;
    EasySplit.paneRatio = 0.5;
    EasySplit.breakpoint = 600;
    EasySplit.config.fullscreenRoutes.clear();
  });

  void addReset(WidgetTester tester) {
    addTearDown(() {
      EasySplit.enabled = true;
      EasySplit.config.layoutBuilder = null;
      EasySplit.layoutDelegate = null;
      EasySplit.config.fullscreenRoutes.clear();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('窄屏：正常路由模式，栈顶全屏', (tester) async {
    addReset(tester);
    await setSurface(tester, 400);
    await tester.pumpWidget(host());
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL'), findsOneWidget);
    expect(tester.getRect(find.text('DETAIL')).width, 400, reason: '全屏');
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    expect(nav.canPop(), isTrue);
  });

  testWidgets('宽屏分栏：首页在左，栈顶在右，右空时占位页', (tester) async {
    addReset(tester);
    await setSurface(tester, 900);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.touch_app_outlined), findsOneWidget,
        reason: '默认占位页');

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.text('DETAIL'));
    expect(rect.right, closeTo(900, 1));
    expect(rect.width, closeTo(450, 1), reason: 'paneRatio=0.5');
    // 左栏首页仍然可点击
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL'), findsNWidgets(2));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pop();
    await tester.pumpAndSettle();
    expect(find.text('DETAIL'), findsOneWidget);
  });

  testWidgets('多级路由：右侧显示栈顶，pop 逐级回退', (tester) async {
    addReset(tester);
    await setSurface(tester, 900);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FILTER_BTN'));
    await tester.pumpAndSettle();
    expect(find.text('FILTER'), findsOneWidget);
    // translucent 栈：下层 DETAIL 仍在树中（状态保留）

    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pop();
    await tester.pumpAndSettle();
    expect(find.text('DETAIL'), findsOneWidget);
    nav.pop();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.touch_app_outlined), findsOneWidget);
  });

  testWidgets('折叠/展开：路由栈完全保留，仅表现层切换', (tester) async {
    addReset(tester);
    await setSurface(tester, 900);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FILTER_BTN'));
    await tester.pumpAndSettle();

    final nav = tester.state<NavigatorState>(find.byType(Navigator));

    // 折叠：栈顶 FILTER 自动变全屏（正常路由模式）
    await setSurface(tester, 400);
    expect(find.text('FILTER'), findsOneWidget);
    expect(tester.getRect(find.text('FILTER')).left, 0, reason: '全屏');

    // 展开：自动回到左右分栏（FILTER 回到右侧）
    await setSurface(tester, 900);
    expect(find.text('FILTER'), findsOneWidget);
    expect(tester.getRect(find.text('FILTER')).left, closeTo(450, 1));

    // 折叠态逐级返回回首页
    await setSurface(tester, 400);
    nav.pop();
    await tester.pumpAndSettle();
    expect(find.text('DETAIL'), findsOneWidget);
    expect(tester.getRect(find.text('DETAIL')).left, 0);
    nav.pop();
    await tester.pumpAndSettle();
    expect(nav.canPop(), isFalse, reason: '回到首页');
  });

  testWidgets('fullscreen 名单路由：任何宽度都全屏 push', (tester) async {
    addReset(tester);
    await setSurface(tester, 900);
    EasySplit.config.fullscreenRoutes.add('/login');
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    debugPrint('[DBG] tree texts: '
        '${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList()}');
    debugPrint('[DBG] scope exists: '
        '${find.byType(EasySplitScope).evaluate().length}');
    await tester.tap(find.text('LOGIN_BTN'));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN'), findsOneWidget);
    expect(tester.getRect(find.text('LOGIN')).width, 900, reason: '全屏覆盖');
  });

  testWidgets('CupertinoPageRoute 也会被拦截分栏', (tester) async {
    addReset(tester);
    await setSurface(tester, 900);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('CUPERTINO_BTN'));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.text('CUPERTINO'));
    expect(rect.right, closeTo(900, 1), reason: '同样进右侧分栏');
    expect(rect.width, closeTo(450, 1));
  });

  testWidgets('用户配置：占比与占位页', (tester) async {
    addReset(tester);
    await setSurface(tester, 1000);
    EasySplit.paneRatio = 0.7;
    EasySplit.placeholderBuilder = (context) => const Text('MY_PLACEHOLDER');
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('MY_PLACEHOLDER'), findsOneWidget);

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('DETAIL')).width, closeTo(700, 1));
  });

  testWidgets('开关关闭：宽屏退化为普通 MaterialPageRoute', (tester) async {
    addReset(tester);
    await setSurface(tester, 900);
    EasySplit.enabled = false;
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL'), findsOneWidget);
    expect(tester.getRect(find.text('DETAIL')).width, closeTo(900, 1),
        reason: '全屏显示');
  });
}
