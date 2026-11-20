import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class HalfScreenRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  HalfScreenRoute({required WidgetBuilder builder, super.settings})
      : _builder = builder;
  final WidgetBuilder _builder;
  @override
  bool get maintainState => true;
  @override
  bool get opaque => false;
  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => false;
  @override
  Widget buildModalBarrier() => const SizedBox.shrink();
  @override
  Widget buildContent(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: MediaQuery.sizeOf(context).width / 2),
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width / 2,
        height: MediaQuery.sizeOf(context).height,
        child: Material(child: _builder(context)),
      ),
    );
  }
}

void main() {
  testWidgets('覆盖层打开后左栏仍可点击（HalfScreenRoute）', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var listTaps = 0;
    var navTaps = 0;
    await tester.pumpWidget(MaterialApp(
      onGenerateRoute: (settings) => settings.name == '/overlay'
          ? HalfScreenRoute(
              settings: settings,
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('右半屏')),
              ),
            )
          : null,
      home: Scaffold(
        body: ListView(
          children: [
            ListTile(
              key: const Key('tile'),
              title: const Text('ITEM'),
              onTap: () => listTaps++,
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          onDestinationSelected: (_) => navTaps++,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: '首页'),
            NavigationDestination(icon: Icon(Icons.grid_view), label: '网格'),
          ],
        ),
      ),
    ));

    tester.state<NavigatorState>(find.byType(Navigator).first).push(
          HalfScreenRoute(
            settings: const RouteSettings(name: '/overlay'),
            builder: (_) =>
                Scaffold(appBar: AppBar(title: const Text('覆盖层'))),
          ),
        );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tile')), warnIfMissed: false);
    await tester.pumpAndSettle();
    print('listTaps=$listTaps');
    await tester.tap(find.text('首页'), warnIfMissed: false);
    await tester.pumpAndSettle();
    print('navTaps=$navTaps');
    expect(listTaps, 1);
    expect(navTaps, 1);
  });
}
