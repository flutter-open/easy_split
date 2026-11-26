import 'package:easy_split/easy_split.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// 裸路由审计：EasySplit.auditObserver
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    EasySplit.config = EasySplitConfig();
  });

  testWidgets('裸 MaterialPageRoute 入栈会告警', (tester) async {
    final warnings = <String>[];
    // 首路由本来就是整窗（启动页/广告页），登记为全屏，避免自身告警
    EasySplit.config.fullscreenRoutes.add('/');
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: const Scaffold(body: Text('HOME')),
      navigatorObservers: [
        EasySplitAuditObserver(onWarn: warnings.add),
      ],
    ));
    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);

    navigator.push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/bare'),
      builder: (_) => const Scaffold(body: Text('BARE')),
    ));
    await tester.pumpAndSettle();

    expect(warnings, hasLength(1));
    expect(warnings.single, contains('name=/bare'));
    expect(warnings.single, contains('MaterialPageRoute'));
    expect(warnings.single, contains('EasySplitGoRoute'));
  });

  testWidgets('pane 路由、EasySplitPage、全屏名单、对话框都不告警', (tester) async {
    final warnings = <String>[];
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 首路由与显式全屏页都登记，只留真正的漏网点告警
    EasySplit.config.fullscreenRoutes.addAll(<String>['/', '/fullscreen']);

    await tester.pumpWidget(MaterialApp(
      home: const Scaffold(body: Text('HOME')),
      navigatorObservers: [
        EasySplitAuditObserver(onWarn: warnings.add),
      ],
    ));
    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    final BuildContext context = tester.element(find.text('HOME'));

    // easy_split 自己的 pane 路由：接管成功，无需告警
    navigator.push(EasySplitRoute<void>(
      settings: const RouteSettings(name: '/pane'),
      builder: (_) => const Scaffold(body: Text('PANE')),
    ));
    await tester.pumpAndSettle();

    // EasySplitPage 创建的页面（含 fullscreen 分支）
    navigator.push(EasySplitPage<void>(
      name: '/page',
      child: (_) => const Scaffold(body: Text('PAGE')),
    ).createRoute(context));
    await tester.pumpAndSettle();

    // 显式声明为全屏的原生路由
    navigator.push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/fullscreen'),
      builder: (_) => const Scaffold(body: Text('FULLSCREEN')),
    ));
    await tester.pumpAndSettle();

    // 对话框不是 PageRoute，整窗是预期行为
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(title: Text('DIALOG')),
    );
    await tester.pumpAndSettle();

    expect(warnings, isEmpty);
  });

  testWidgets('关闭 EasySplit 后不告警', (tester) async {
    final warnings = <String>[];
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    EasySplit.enabled = false;

    await tester.pumpWidget(MaterialApp(
      home: const Scaffold(body: Text('HOME')),
      navigatorObservers: [
        EasySplitAuditObserver(onWarn: warnings.add),
      ],
    ));
    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);

    navigator.push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/bare'),
      builder: (_) => const Scaffold(body: Text('BARE')),
    ));
    await tester.pumpAndSettle();

    expect(warnings, isEmpty);
  });
}
