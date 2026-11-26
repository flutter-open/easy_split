import 'package:easy_split/easy_split.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// 面板内浮层：EasySplit.showPaneOverlay / EasySplitPaneOverlay
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    EasySplit.config = EasySplitConfig();
  });

  testWidgets('浮层贴右栏矩形，折叠后自动恢复整屏，移除后消失', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late BuildContext hostContext;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        hostContext = context;
        return const Scaffold(body: SizedBox.expand());
      }),
    ));

    final OverlayEntry right = EasySplit.showPaneOverlay(
      hostContext,
      builder: (_) => const ColoredBox(
        key: Key('right'),
        color: Colors.black54,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('right'))),
      const Rect.fromLTWH(600, 0, 600, 800),
    );

    final OverlayEntry left = EasySplit.showPaneOverlay(
      hostContext,
      side: EasySplitPaneSide.left,
      builder: (_) => const ColoredBox(
        key: Key('left'),
        color: Colors.black54,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('left'))),
      const Rect.fromLTWH(0, 0, 600, 800),
    );

    // 折叠到窄屏：浮层恢复整屏（与 pane 路由行为一致）
    tester.view.physicalSize = const Size(500, 800);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('right'))),
      const Rect.fromLTWH(0, 0, 500, 800),
    );

    right.remove();
    left.remove();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('right')), findsNothing);
    expect(find.byKey(const Key('left')), findsNothing);
  });

  testWidgets('ignorePointer = true 时浮层不拦截点击', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var taps = 0;
    late BuildContext hostContext;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        hostContext = context;
        return Scaffold(
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox.expand(),
          ),
        );
      }),
    ));

    final OverlayEntry mask = EasySplit.showPaneOverlay(
      hostContext,
      ignorePointer: true,
      builder: (_) => const ColoredBox(color: Colors.black54),
    );
    await tester.pumpAndSettle();

    // 右栏内点击穿透到下层
    await tester.tapAt(const Offset(900, 400));
    await tester.pumpAndSettle();
    expect(taps, 1);

    mask.remove();
    await tester.pumpAndSettle();
  });
}
