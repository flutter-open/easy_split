import 'package:easy_split/easy_split.dart';
import 'package:easy_split_demo/easy_split_demo.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// TabBar 首页示例的回归测试：
/// 1. 折叠 ⇄ 展开后 tab / 计数 / 滚动位置 / 输入内容都保留；
/// 2. 第 4 个 tab（宽度）：面板里读到的就是面板宽度（含 ScreenUtil 换算）。
void main() {
  setUpAll(() {
    ScreenUtil.configure(
      data: const MediaQueryData(size: Size(375, 812)),
      designSize: kDesignSize,
      splitScreenMode: false,
      minTextAdapt: false,
    );
  });

  setUp(() {
    // 与 example/lib/main.dart 一致：把面板 MediaQuery 转发给 ScreenUtil
    EasySplit.config = EasySplitConfig()
      ..onPaneMediaQuery = (data) => ScreenUtil.configure(
        data: data,
        designSize: kDesignSize,
        splitScreenMode: false,
        minTextAdapt: false,
      );
    DemoViewport.forceWide = null;
  });

  /// 头部读数里"滚动位置"那一行的值（形如 `123 px`）
  String? offsetReadout(WidgetTester tester) {
    final texts = tester.widgetList<Text>(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data?.endsWith(' px') ?? false),
      ),
    );
    return texts.isEmpty ? null : texts.first.data;
  }

  testWidgets('TabBar 首页：折叠 ⇄ 展开后四份状态全部保留', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: EasySplitScope(child: TabsHomePage(title: 'TEST')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      EasySplit.isWide(tester.element(find.byType(TabsHomePage))),
      isFalse,
    );

    // 1) 计数 +2
    await tester.tap(find.text('加一下'));
    await tester.tap(find.text('加一下'));
    await tester.pump();
    expect(find.text('2'), findsWidgets);

    // 2) 切到「滚动」并滚一段
    await tester.tap(find.text('滚动'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -420));
    await tester.pumpAndSettle();
    final offsetBefore = offsetReadout(tester) ?? '';
    expect(offsetBefore, isNotEmpty);
    expect(offsetBefore, isNot('滚动：0 px'));

    // 3) 切到「输入」并输入
    await tester.tap(find.text('输入'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    expect(find.text('重建后仍然在：hello'), findsOneWidget);

    // 4) 强制展开：结构从"窄屏直出"切到"分栏"（修复前这里会重建整棵子树）
    DemoViewport.forceWide = true;
    DemoViewport.apply();
    await tester.pumpAndSettle();

    expect(EasySplit.isWide(tester.element(find.byType(TabsHomePage))), isTrue);

    // 四份状态都还在（底部状态条始终可见）
    expect(find.text('已展开'), findsOneWidget);
    expect(find.text('tab：输入'), findsOneWidget);
    expect(find.text('计数：2'), findsOneWidget);
    expect(find.text(offsetBefore), findsOneWidget);
    expect(find.text('输入："hello"'), findsOneWidget);

    // 5) 再折叠回来，同样保留
    DemoViewport.forceWide = false;
    DemoViewport.apply();
    await tester.pumpAndSettle();
    expect(
      EasySplit.isWide(tester.element(find.byType(TabsHomePage))),
      isFalse,
    );
    expect(find.text('折叠态'), findsOneWidget);
    expect(find.text('tab：输入'), findsOneWidget);
    expect(find.text('计数：2'), findsOneWidget);
    expect(find.text(offsetBefore), findsOneWidget);
    expect(find.text('输入："hello"'), findsOneWidget);
  });

  testWidgets('宽度 tab：面板里读到的是面板尺寸，ScreenUtil 跟着面板换算', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: EasySplitScope(
          child: TabsHomePage(title: 'TEST', initialIndex: 3),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 左栏 = 整窗的一半
    expect(find.text('600 × 800'), findsOneWidget);
    expect(find.text('1200 × 800'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);

    // ScreenUtil：240.w = 600 * 240 / 375 = 384
    expect(find.text('384.0'), findsOneWidget);

    // 百分比块按面板宽度计算（在列表下方，滚动过去再断言）
    await tester.scrollUntilVisible(
      find.text('25% = 150'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('50% = 300'), findsOneWidget);
    expect(find.text('25% = 150'), findsOneWidget);
  });
}
