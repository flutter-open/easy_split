import 'package:easy_split/easy_split.dart';
import 'package:easy_split_getx/easy_split_getx.dart';
import 'package:get/get.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// ============================================================================
/// EasySplit + GetX demo
///
/// 两种 GetX 导航模式共用这套页面：
/// - `main.dart`：经典命名路由（GetMaterialApp + onGenerateRoute 适配器）
/// - `main_router.dart`：Navigator 2.0（GetMaterialApp.router + getPages）
///
/// 页面里统一走 [DemoNav]，适配器负责把右侧页面变成 pane 路由。
/// 左侧首页始终包一层 EasySplitScope，窄屏时它就是一整屏。
/// ============================================================================

/// 导航适配：GetX 两种模式的路由 API 不同。
///
/// 经典模式读 `Get.parameters` / `Get.toNamed`；
/// Navigator 2.0 模式必须走 `Get.rootDelegate`，因为此时 Navigator 由
/// `pages` 驱动，`Get.toNamed` 的 `Navigator.pushNamed` 不可用。
class DemoNav {
  DemoNav._();

  static bool routerMode = false;

  static Map<String, String?> get parameters =>
      routerMode ? Get.rootDelegate.parameters : Get.parameters;

  static Future<dynamic>? toNamed(String page) {
    if (routerMode) return Get.rootDelegate.toNamed(page);
    return Get.toNamed(page);
  }

  static Future<dynamic>? offNamed(String page) {
    if (routerMode) return Get.rootDelegate.offNamed(page);
    return Get.offNamed(page);
  }

  static void back() {
    if (routerMode) {
      Get.rootDelegate.popRoute();
    } else {
      Get.back();
    }
  }
}

const List<DemoItem> _items = <DemoItem>[
  DemoItem('订单详情', '右栏打开，左栏保持可见', Icons.receipt_long),
  DemoItem('物流轨迹', '点击同一项不会重复入栈', Icons.local_shipping),
  DemoItem('商品评价', 'GetX Binding 正常注入', Icons.rate_review),
  DemoItem('售后记录', 'middleware 与参数解析保留', Icons.support_agent),
  DemoItem('发票信息', '折叠屏展开/折叠状态不丢', Icons.description),
];

class DemoItem {
  const DemoItem(this.title, this.subtitle, this.icon);

  final String title;
  final String subtitle;
  final IconData icon;
}

/// 共享路由表。`/home` 是左栏（普通 GetPage + EasySplitScope），
/// 其余页面用 [EasySplitGetPage] 声明"宽屏进右栏"。
final List<GetPage> demoPages = <GetPage>[
  GetPage<String>(name: '/', page: () => const AdPage()),
  GetPage<String>(
    name: '/home',
    page: () => const EasySplitScope(child: HomePage()),
  ),
  EasySplitGetPage<String>(
    name: '/detail/:index',
    page: () => const DetailPage(),
    binding: DetailBinding(),
  ),
  EasySplitGetPage<String>(
    name: '/secondary',
    page: () => const SecondaryPage(),
  ),
  EasySplitGetPage<String>(name: '/dialogs', page: () => const DialogsPage()),
  // fullscreen: true 与 EasySplit.config.fullscreenRoutes 等价，
  // 任何宽度都使用原生 GetPageRoute。
  EasySplitGetPage<String>(
    name: '/fullscreen',
    page: () => const FullscreenPage(),
    fullscreen: true,
  ),
];

final GetPage<String> unknownPage = GetPage<String>(
  name: '/not-found',
  page: () => const NotFoundPage(),
);

void runGetxDemo({required bool routerMode}) {
  DemoNav.routerMode = routerMode;
  EasySplit.config
    ..breakpoint = 600
    ..paneRatio = 0.5
    ..enabled.value = true;
  // 只有 EasySplitGetPage 会被适配器包成分栏路由；`/` 和 `/home` 是普通
  // GetPage，始终保持原生全屏路由。`/home` 再由 EasySplitScope 创建窗格。
  EasySplit.config.fullscreenRoutes
    ..clear()
    ..add('/fullscreen');
  EasySplit.updateLayout();
  runApp(GetxDemoApp(routerMode: routerMode));
}

ThemeData _theme() => ThemeData(
  colorSchemeSeed: Colors.teal,
  useMaterial3: true,
  brightness: Brightness.light,
);

class GetxDemoApp extends StatelessWidget {
  const GetxDemoApp({super.key, required this.routerMode});

  final bool routerMode;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = _theme();
    if (routerMode) {
      return GetMaterialApp.router(
        title: 'EasySplit · GetX (Navigator 2.0)',
        theme: theme,
        getPages: demoPages,
        unknownRoute: unknownPage,
        debugShowCheckedModeBanner: false,
      );
    }
    return GetMaterialApp(
      title: 'EasySplit · GetX (onGenerateRoute)',
      theme: theme,
      initialRoute: '/',
      // 关键：不要同时传 getPages，否则 GetX 会用内部 generator
      // 覆盖 onGenerateRoute，适配器就不会被调用。
      onGenerateRoute: easySplitGetRouteAdapter(
        pages: demoPages,
        unknownRoute: unknownPage,
      ),
      // 经典模式可选：整栈重复路由收敛（与 EasySplit.routeAdapter 一致）。
      navigatorObservers: <NavigatorObserver>[EasySplit.dedupeObserver],
      unknownRoute: unknownPage,
      debugShowCheckedModeBanner: false,
    );
  }
}

// ---------------------------------------------------------------------------
// 页面
// ---------------------------------------------------------------------------

class AdPage extends StatelessWidget {
  const AdPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(Icons.splitscreen, size: 72, color: scheme.primary),
                const SizedBox(height: 24),
                Text(
                  'EasySplit + GetX',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  DemoNav.routerMode
                      ? 'GetMaterialApp.router · getPages'
                      : 'GetMaterialApp · onGenerateRoute',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 36),
                FilledButton.icon(
                  onPressed: () => DemoNav.offNamed('/home'),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('进入首页'),
                ),
                const SizedBox(height: 12),
                Text(
                  '宽屏（>= 600dp 且横屏）时，首页留在左栏，'
                  '后续页面自动进入右栏；窄屏则是普通单页。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('EasySplit · GetX'),
        actions: <Widget>[
          IconButton(
            tooltip: '切换分栏',
            onPressed: () {
              EasySplit.config.enabled.value = !EasySplit.config.enabled.value;
              EasySplit.updateLayout();
            },
            icon: ValueListenableBuilder<bool>(
              valueListenable: EasySplit.config.enabled,
              builder: (BuildContext context, bool enabled, _) =>
                  Icon(enabled ? Icons.splitscreen : Icons.crop_portrait),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '点击列表项打开右栏页面',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '左栏保持可交互，右栏页面带自己的 GetX Binding；'
                    '折叠屏展开/折叠不会重置状态。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < _items.length; i++)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Icon(_items[i].icon)),
                title: Text(_items[i].title),
                subtitle: Text(_items[i].subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => DemoNav.toNamed('/detail/$i'),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => DemoNav.toNamed('/secondary'),
                icon: const Icon(Icons.layers_outlined),
                label: const Text('二级页'),
              ),
              OutlinedButton.icon(
                onPressed: () => DemoNav.toNamed('/dialogs'),
                icon: const Icon(Icons.widgets_outlined),
                label: const Text('弹窗 / 底部弹层'),
              ),
              OutlinedButton.icon(
                onPressed: () => DemoNav.toNamed('/fullscreen'),
                icon: const Icon(Icons.fullscreen),
                label: const Text('全屏页'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DetailController extends GetxController {
  DetailController();

  final String index = DemoNav.parameters['index'] ?? '?';
  final RxInt count = 0.obs;

  void increment() => count.value++;
}

class DetailBinding extends Bindings {
  @override
  void dependencies() {
    // dependencies() 在路由内容首次构建时执行，此时路径参数已经解析完成。
    Get.lazyPut<DetailController>(DetailController.new);
  }
}

class DetailPage extends StatelessWidget {
  const DetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DetailController controller = Get.find<DetailController>();
    final DemoItem item = _items[int.tryParse(controller.index) ?? 0]
        .cloneWithIndex(controller.index);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Icon(item.icon, size: 56, color: scheme.primary),
          const SizedBox(height: 16),
          Text(
            '路由参数 index = ${controller.index}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '这个页面来自 EasySplitGetPage：宽屏时只占右栏，'
            '左栏首页仍然可见、可点击。GetX 的 Binding、middleware、'
            '转场和路由上报都保留了。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  const Expanded(child: Text('控制器状态（Binding 注入）')),
                  Obx(
                    () => Text(
                      '${controller.count.value}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: controller.increment,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: () => DemoNav.toNamed('/secondary'),
            icon: const Icon(Icons.layers_outlined),
            label: const Text('再开一个二级页'),
          ),
        ],
      ),
    );
  }
}

class SecondaryPage extends StatelessWidget {
  const SecondaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('二级页')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.layers_outlined, size: 56),
              const SizedBox(height: 16),
              const Text(
                'EasySplitGetPage（二级页）',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                '宽屏时同样进入右栏；返回时只弹这一层，首页状态保留。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: DemoNav.back, child: const Text('返回')),
            ],
          ),
        ),
      ),
    );
  }
}

class DialogsPage extends StatelessWidget {
  const DialogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('弹窗 / 底部弹层')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          FilledButton.tonal(
            onPressed: () => Get.dialog<void>(
              AlertDialog(
                title: const Text('Get.dialog'),
                content: const Text('对话框浮在整窗之上，分栏布局不受影响。'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Get.back<void>(),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ),
            child: const Text('打开对话框'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => Get.bottomSheet<void>(
              const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Get.bottomSheet：仍走 GetX 的导航栈。'),
                ),
              ),
            ),
            child: const Text('打开底部弹层'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () =>
                Get.snackbar('Get.snackbar', 'Snackbar 由 GetX 的 overlay 管理'),
            child: const Text('打开 snackbar'),
          ),
          const SizedBox(height: 24),
          Text(
            '这些弹层由 GetX 自己创建路由，和 EasySplit 的分栏路由互不干扰。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class FullscreenPage extends StatelessWidget {
  const FullscreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('全屏页')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.fullscreen, size: 64),
              const SizedBox(height: 16),
              const Text(
                'EasySplitGetPage(fullscreen: true)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                '即使宽屏也使用原生 GetPageRoute，占满整屏；'
                '与 EasySplit.config.fullscreenRoutes 等价。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: DemoNav.back, child: const Text('返回')),
            ],
          ),
        ),
      ),
    );
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('页面不存在')),
      body: Center(
        child: FilledButton(
          onPressed: () => DemoNav.offNamed('/home'),
          child: const Text('回首页'),
        ),
      ),
    );
  }
}

extension on DemoItem {
  DemoItem cloneWithIndex(String index) =>
      DemoItem('$title #$index', subtitle, icon);
}
