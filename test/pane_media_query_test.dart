import 'package:easy_split/easy_split.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 面板内页面必须把"自己占用的区域"当成屏幕
///
/// 背景：分栏后左栏/右栏只占屏幕的一部分，但页面里
/// `MediaQuery.sizeOf(context)` 若仍是整窗尺寸，按整体宽度算的布局
/// （百分比宽度、栅格、等比缩放、间距系数）会被放大，内容溢出/错位。
///
/// 这里锁住：
/// 1. 左栏（Scope 首页）与右栏（分栏路由内容）拿到的 `MediaQuery.size`
///    是该面板的尺寸；
/// 2. `EasySplit.isWide` / `layoutOf` / `paneWidth` / `paneContentInsets`
///    仍按**整窗**几何计算（面板尺寸不能把断点判定带偏）；
/// 3. 自定义 `layoutBuilder` 下按实际约束反推面板尺寸；
/// 4. ScreenUtil 这类直接读 FlutterView 的方案，通过
///    `EasySplit.config.onPaneMediaQuery` 拿到面板数据。
void main() {
  setUp(() {
    EasySplit.config = EasySplitConfig();
  });

  tearDown(() {
    EasySplit.config = EasySplitConfig();
  });

  void setSize(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
  }

  MediaQueryData mqOf(WidgetTester tester, Finder finder) =>
      MediaQuery.of(tester.element(finder));

  testWidgets('宽屏左栏：MediaQuery.size 是左栏尺寸，断点仍按整窗判定', (tester) async {
    setSize(tester, const Size(1200, 800));
    addTearDown(tester.view.reset);
    final homeKey = GlobalKey();

    await tester.pumpWidget(MaterialApp(
      home: EasySplitScope(
        child: Scaffold(key: homeKey, body: const Text('HOME')),
      ),
      onGenerateRoute: EasySplit.routeAdapter({}),
    ));
    await tester.pumpAndSettle();

    final data = mqOf(tester, find.byKey(homeKey));
    // 左栏 600×800，而不是整窗 1200×800
    expect(data.size, const Size(600, 800));
    expect(data.orientation, Orientation.portrait);

    final context = tester.element(find.byKey(homeKey));
    // 断点 / 左右矩形 / 右栏宽度仍按整窗几何
    expect(EasySplit.isWide(context), isTrue);
    expect(EasySplit.layoutOf(context).leftRect,
        const Rect.fromLTWH(0, 0, 600, 800));
    expect(EasySplit.layoutOf(context).paneRect,
        const Rect.fromLTWH(600, 0, 600, 800));
    expect(EasySplit.paneWidth(context), 600);
    expect(EasySplit.paneContentInsets(context), EdgeInsets.zero);
  });

  testWidgets('断点小于左栏宽度时，左栏页面也被判为宽屏（按整窗判定）', (tester) async {
    EasySplit.config.breakpoint = 900;
    setSize(tester, const Size(1200, 800));
    addTearDown(tester.view.reset);
    final homeKey = GlobalKey();

    await tester.pumpWidget(MaterialApp(
      home: EasySplitScope(
        child: Scaffold(key: homeKey, body: const Text('HOME')),
      ),
      onGenerateRoute: EasySplit.routeAdapter({}),
    ));
    await tester.pumpAndSettle();

    // 页面自己只有 600 宽（< 断点 900），但窗口 1200 宽 → 仍是分栏态
    expect(mqOf(tester, find.byKey(homeKey)).size, const Size(600, 800));
    expect(EasySplit.isWide(tester.element(find.byKey(homeKey))), isTrue);
  });

  testWidgets('宽屏右栏：路由内容拿到的 MediaQuery.size 是面板尺寸', (tester) async {
    setSize(tester, const Size(1200, 800));
    addTearDown(tester.view.reset);
    final detailKey = GlobalKey();

    await tester.pumpWidget(MaterialApp(
      home: EasySplitScope(
        child: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => Navigator.pushNamed(context, '/detail'),
                child: const Text('GO'),
              ),
            ),
          ),
        ),
      ),
      onGenerateRoute: EasySplit.routeAdapter({
        '/detail': (_) => Scaffold(key: detailKey, body: const Text('DETAIL')),
      }),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();

    final data = mqOf(tester, find.byKey(detailKey));
    expect(data.size, const Size(600, 800));
    // 安全区已由分栏扣除，面板内不再重复避让
    expect(data.padding, EdgeInsets.zero);

    final context = tester.element(find.byKey(detailKey));
    expect(EasySplit.isWide(context), isTrue);
    expect(EasySplit.paneWidth(context), 600);
    // 详情页仍落在右栏矩形内
    expect(tester.getRect(find.byKey(detailKey)),
        const Rect.fromLTWH(600, 0, 600, 800));
  });

  testWidgets('窄屏：折叠态页面仍拿到整窗尺寸', (tester) async {
    setSize(tester, const Size(400, 800));
    addTearDown(tester.view.reset);
    final homeKey = GlobalKey();
    final detailKey = GlobalKey();

    await tester.pumpWidget(MaterialApp(
      home: EasySplitScope(
        child: Scaffold(
          key: homeKey,
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => Navigator.pushNamed(context, '/detail'),
                child: const Text('GO'),
              ),
            ),
          ),
        ),
      ),
      onGenerateRoute: EasySplit.routeAdapter({
        '/detail': (_) => Scaffold(key: detailKey, body: const Text('DETAIL')),
      }),
    ));
    await tester.pumpAndSettle();

    expect(mqOf(tester, find.byKey(homeKey)).size, const Size(400, 800));
    expect(EasySplit.isWide(tester.element(find.byKey(homeKey))), isFalse);

    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();

    expect(mqOf(tester, find.byKey(detailKey)).size, const Size(400, 800));
    expect(tester.getRect(find.byKey(detailKey)),
        const Rect.fromLTWH(0, 0, 400, 800));
  });

  testWidgets('自定义 layoutBuilder：按自身实际宽度取 MediaQuery.size', (tester) async {
    setSize(tester, const Size(1200, 800));
    addTearDown(tester.view.reset);
    EasySplit.config.layoutBuilder = (context, left, right) {
      return Row(
        children: [
          Expanded(flex: 3, child: left),
          Expanded(flex: 2, child: right),
        ],
      );
    };
    final homeKey = GlobalKey();

    await tester.pumpWidget(MaterialApp(
      home: EasySplitScope(
        child: Scaffold(key: homeKey, body: const Text('HOME')),
      ),
      onGenerateRoute: EasySplit.routeAdapter({}),
    ));
    await tester.pumpAndSettle();

    // 3:2 分 → 左栏 720 宽
    expect(mqOf(tester, find.byKey(homeKey)).size, const Size(720, 800));
    expect(EasySplit.isWide(tester.element(find.byKey(homeKey))), isTrue);
  });

  testWidgets('onPaneMediaQuery：把面板 MediaQuery 交给外部方案（ScreenUtil）',
      (tester) async {
    final reported = <Size>[];
    EasySplit.config.onPaneMediaQuery = (data) => reported.add(data.size);
    setSize(tester, const Size(1200, 800));
    addTearDown(tester.view.reset);
    final homeKey = GlobalKey();

    await tester.pumpWidget(MaterialApp(
      home: EasySplitScope(
        child: Scaffold(key: homeKey, body: const Text('HOME')),
      ),
      onGenerateRoute: EasySplit.routeAdapter({}),
    ));
    await tester.pumpAndSettle();

    // 宽屏：上报的是面板尺寸（左栏 600 + 右栏占位 600）
    expect(reported, isNotEmpty);
    expect(reported, everyElement(const Size(600, 800)));
    // 与页面里读到的 MediaQuery 一致
    expect(reported.last, mqOf(tester, find.byKey(homeKey)).size);

    // 折叠：上报整窗尺寸
    reported.clear();
    setSize(tester, const Size(400, 800));
    await tester.pumpAndSettle();
    expect(reported, isNotEmpty);
    expect(reported.last, const Size(400, 800));
  });

  testWidgets('paneMediaQuery：size 扣掉 insets，padding 同步扣除', (tester) async {
    const parent = MediaQueryData(
      size: Size(1200, 800),
      padding: EdgeInsets.fromLTRB(0, 24, 0, 12),
      viewPadding: EdgeInsets.fromLTRB(0, 24, 0, 12),
    );
    final data = EasySplit.paneMediaQuery(
      parent,
      const Rect.fromLTWH(600, 0, 600, 800),
      insets: const EdgeInsets.fromLTRB(0, 24, 0, 12),
    );
    expect(data.size, const Size(600, 764));
    expect(data.padding, EdgeInsets.zero);
    expect(data.viewPadding, EdgeInsets.zero);
    // 其余沿用整窗
    expect(data.devicePixelRatio, parent.devicePixelRatio);
  });
}
