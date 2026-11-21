import 'package:easy_split/easy_split.dart';
import 'package:easy_split_go_router_example/main_on_enter.dart';
import 'package:easy_split_go_router_example/pages.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  setUp(() {
    EasySplit.config = EasySplitConfig()
      ..fullscreenRoutes.addAll({'/home', '/login'});
    DemoSplitLayout.reset();
    DemoAuth.logout();
  });

  testWidgets('onEnter 去重：重复 push 同一页不压栈，已有页置顶', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final GoRouter router = createDemoRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    int depth() => router.routerDelegate.currentConfiguration.matches.length;

    // 广告页 → 首页（pushReplacement），栈里只有 /home
    await tester.tap(find.text('立即进入首页'));
    await tester.pumpAndSettle();
    expect(depth(), 1);

    // 未登录点列表项 → 登录页 → 模拟登录 → 回到详情页
    await tester.tap(find.text(kDemoItems.first.title));
    await tester.pumpAndSettle();
    expect(find.text('登录后继续'), findsOneWidget);
    await tester.tap(find.text('模拟登录'));
    await tester.pumpAndSettle();
    expect(depth(), 2);
    expect(find.text('当前登录：演示用户'), findsOneWidget);

    // 再 push 同一页：onEnter 直接拦掉导航，栈深不变
    router.push('/detail/0');
    await tester.pumpAndSettle();
    expect(depth(), 2);

    // 不同页面正常压栈
    router.push('/detail/1');
    await tester.pumpAndSettle();
    expect(depth(), 3);

    // 已在栈内（不在栈顶）的页面再次 push：先入栈，再收敛成置顶
    router.push('/detail/0');
    await tester.pumpAndSettle();
    expect(depth(), 2);
    expect(
      router.routerDelegate.currentConfiguration.matches.last.matchedLocation,
      '/detail/0',
    );
  });
}
