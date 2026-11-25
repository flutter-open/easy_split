import 'package:easy_split/easy_split.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 展开 / 折叠只换布局，不得重建页面
///
/// 背景：窄屏与宽屏的布局结构不同（窄屏全屏、宽屏左右分栏）。
/// 如果两个分支返回的 widget 树结构不同，Flutter 会把整棵子树销毁重建，
/// 首页（尤其是 TabBar 形式的首页）会被"还原成默认状态"：
/// TabController 回到第一页、滚动位置清零、输入内容丢失。
///
/// 这里锁住三条链路的结构稳定性：
/// 1. [EasySplitScope]（首页包 Scope）
/// 2. [EasySplitRoute] 的 `EasySplitPaneFrame` / `EasySplitPaneTeleport`（首页/详情是分栏路由）
/// 3. 自定义 `layoutBuilder`（结构无法固定，用稳定 GlobalKey 搬迁）
void main() {
  setUp(() {
    EasySplit.config = EasySplitConfig();
  });

  void setSize(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
  }

  tearDown(() {
    EasySplit.config = EasySplitConfig();
  });

  testWidgets('首页包 Scope：展开/折叠后 Tab 当前页与首页 State 保留', (tester) async {
    setSize(tester, const Size(400, 800));
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: EasySplitScope(child: _TabHome()),
      onGenerateRoute: EasySplit.routeAdapter({}),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(find.text('B-BODY'), findsOneWidget);

    // 展开：400 → 1200（宽屏分栏）
    setSize(tester, const Size(1200, 800));
    await tester.pumpAndSettle();
    expect(find.text('B-BODY'), findsOneWidget);
    expect(find.text('A-BODY'), findsNothing);

    // 再折叠：状态仍保留
    setSize(tester, const Size(400, 800));
    await tester.pumpAndSettle();
    expect(find.text('B-BODY'), findsOneWidget);
  });

  testWidgets('首页是分栏路由（EasySplitRoute）：展开后 State 保留', (tester) async {
    setSize(tester, const Size(400, 800));
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/home'),
              child: const Text('OPEN_HOME'),
            ),
          ),
        ),
      ),
      onGenerateRoute: EasySplit.routeAdapter({
        '/home': (_) => EasySplitScope(child: _TabHome()),
      }),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN_HOME'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();

    setSize(tester, const Size(1200, 800));
    await tester.pumpAndSettle();
    expect(find.text('B-BODY'), findsOneWidget);
  });

  testWidgets('右栏详情页在折叠/展开时 State 保留', (tester) async {
    setSize(tester, const Size(1200, 800));
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: EasySplitScope(
        child: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.pushNamed(context, '/detail'),
                child: const Text('GO_DETAIL'),
              ),
            ),
          ),
        ),
      ),
      onGenerateRoute: EasySplit.routeAdapter({
        '/detail': (_) => const _CounterDetail(),
      }),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GO_DETAIL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('INCREMENT'));
    await tester.pumpAndSettle();
    expect(find.text('COUNT=1'), findsOneWidget);

    // 折叠（详情全屏）
    setSize(tester, const Size(400, 800));
    await tester.pumpAndSettle();
    expect(find.text('COUNT=1'), findsOneWidget);

    // 再展开（详情回到右栏）
    setSize(tester, const Size(1200, 800));
    await tester.pumpAndSettle();
    expect(find.text('COUNT=1'), findsOneWidget);
    expect(tester.getRect(find.byType(Scaffold).last),
        const Rect.fromLTWH(600, 0, 600, 800));
  });

  testWidgets('首页滚动位置在展开后保留', (tester) async {
    setSize(tester, const Size(400, 800));
    addTearDown(tester.view.reset);

    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: EasySplitScope(
        child: Scaffold(
          body: ListView.builder(
            controller: controller,
            itemCount: 100,
            itemExtent: 50,
            itemBuilder: (_, i) => Text('ITEM_$i'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    final offsetBefore = controller.offset;
    expect(offsetBefore, greaterThan(0));

    setSize(tester, const Size(1200, 800));
    await tester.pumpAndSettle();
    expect(controller.offset, offsetBefore);
  });

  testWidgets('自定义 layoutBuilder：展开后首页 State 保留', (tester) async {
    EasySplit.config.layoutBuilder = (context, left, right) {
      return Row(
        children: [
          Expanded(child: left),
          SizedBox(width: 360, child: right),
        ],
      );
    };
    setSize(tester, const Size(400, 800));
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: EasySplitScope(child: _TabHome()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(find.text('B-BODY'), findsOneWidget);

    setSize(tester, const Size(1200, 800));
    await tester.pumpAndSettle();
    expect(find.text('B-BODY'), findsOneWidget);
  });
}

/// TabBar 形式的首页：窄 → 宽切换最容易暴露"还原默认状态"
class _TabHome extends StatefulWidget {
  @override
  State<_TabHome> createState() => _TabHomeState();
}

class _TabHomeState extends State<_TabHome>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        bottom: TabBar(
          controller: _controller,
          tabs: const [Tab(text: 'A'), Tab(text: 'B')],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: const [
          Center(child: Text('A-BODY')),
          Center(child: Text('B-BODY')),
        ],
      ),
    );
  }
}

/// 详情页：验证右栏路由在折叠/展开时不被重建
class _CounterDetail extends StatefulWidget {
  const _CounterDetail();

  @override
  State<_CounterDetail> createState() => _CounterDetailState();
}

class _CounterDetailState extends State<_CounterDetail> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('COUNT=$_count'),
            TextButton(
              onPressed: () => setState(() => _count++),
              child: const Text('INCREMENT'),
            ),
          ],
        ),
      ),
    );
  }
}
