// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:easy_split/easy_split.dart';
import 'package:easy_split_getx_example/pages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.reset();
    Get.clearRouteTree();
    EasySplit.config.fullscreenRoutes
      ..clear()
      ..add('/fullscreen');
    EasySplit.config.enabled.value = true;
  });

  testWidgets('classic GetMaterialApp + onGenerateRoute', (tester) async {
    DemoNav.routerMode = false;
    await tester.pumpWidget(const GetxDemoApp(routerMode: false));
    expect(find.text('EasySplit + GetX'), findsOneWidget);

    await tester.tap(find.text('进入首页'));
    await tester.pumpAndSettle();
    expect(find.text('点击列表项打开右栏页面'), findsOneWidget);

    await tester.tap(find.text('订单详情'));
    await tester.pumpAndSettle();
    expect(find.text('路由参数 index = 0'), findsOneWidget);
    // 左栏首页仍然在树上（pane 路由 opaque=false），且确实位于左半屏。
    expect(find.text('点击列表项打开右栏页面'), findsOneWidget);
    expect(tester.getCenter(find.text('订单详情')).dx, lessThan(400));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // 左栏仍然可点：从详情再开二级页，然后点回同一个列表项。
    await tester.tap(find.text('再开一个二级页'));
    await tester.pumpAndSettle();
    expect(find.text('二级页'), findsOneWidget);

    await tester.tap(find.text('订单详情'));
    await tester.pumpAndSettle();
    // dedupeObserver 收敛到已有的 /detail/0，二级页被摘掉，计数状态保留。
    expect(find.text('二级页'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('GetMaterialApp.router + getPages', (tester) async {
    DemoNav.routerMode = true;
    await tester.pumpWidget(const GetxDemoApp(routerMode: true));
    await tester.pumpAndSettle();
    expect(find.text('EasySplit + GetX'), findsOneWidget);

    await tester.tap(find.text('进入首页'));
    await tester.pumpAndSettle();
    expect(find.text('点击列表项打开右栏页面'), findsOneWidget);

    await tester.tap(find.text('订单详情'));
    await tester.pumpAndSettle();
    expect(find.text('路由参数 index = 0'), findsOneWidget);
    expect(find.text('点击列表项打开右栏页面'), findsOneWidget);
  });

  testWidgets('fullscreen page stays fullscreen on wide window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    DemoNav.routerMode = false;
    await tester.pumpWidget(const GetxDemoApp(routerMode: false));
    await tester.tap(find.text('进入首页'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全屏页'));
    await tester.pumpAndSettle();

    expect(find.text('EasySplitGetPage(fullscreen: true)'), findsOneWidget);
    // 宽屏 + 关闭分栏后仍显示全屏页，说明它没有走 pane 路由。
    expect(find.byType(EasySplitPaneFrame), findsNothing);
  });
}
