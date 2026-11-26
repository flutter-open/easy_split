import 'package:easy_split/easy_split.dart';
import 'package:easy_split_go_router/easy_split_go_router.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, mapEquals, visibleForTesting;
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// ============================================================================
/// 方案三：混合导航 · go_router + 非 go_router 入口 + 浮层
///
/// 真实项目里常见的三类「漏网」，本 demo 一次演示完，可直接抄：
///
/// 1. 参数化页：大量 WebView 入口（广告、支付、登录回跳、JSSDK）指向同一
///    个页面，只是 url/header 不同 → 一条 `/webview` 路由 + 参数放 extra；
///    同 url + 同 header 重复打开自动去重（默认深比较）。
/// 2. 显式全屏：广告页、登录页、整窗 H5（支付/风控）→ 用
///    `EasySplitGoRoute(fullscreen: true)` 或 `EasySplit.fullscreenRoutes`。
/// 3. 面板内浮层：`EasySplit.showPaneOverlay` 把 OverlayEntry 约束到某一栏，
///    窗口缩放/展开折叠自动重排（直接 insert 的浮层会按整窗布局）。
///
/// 另外挂了 `EasySplit.auditObserver`：debug 下任何裸
/// `Navigator.push(MaterialPageRoute(...))` 都会告警，把漏网点打出来。
///
/// 运行：flutter run -t lib/main_mixed.dart
/// ============================================================================

void main() {
  // 首路由（广告页）与左栏首页自包 EasySplitScope，本来就该整窗：
  // 显式登记进全屏名单，审计 observer 才不会误报。
  EasySplit.config.fullscreenRoutes.addAll(<String>['/', '/home']);
  runApp(const MixedDemoApp());
}

// ---------------------------------------------------------------------------
// WebView 参数：必须值相等，否则去重退化成「引用比较」，永远不命中
// ---------------------------------------------------------------------------

/// 打开 WebView 页的参数（url / 标题 / 请求头 / 是否整窗）
class WebViewArgs {
  const WebViewArgs({
    required this.url,
    this.title = 'H5',
    this.headers = const <String, String>{},
    this.fullscreen = false,
  });

  final String url;
  final String title;
  final Map<String, String> headers;
  final bool fullscreen;

  static WebViewArgs fromExtra(Object? extra) => extra is WebViewArgs
      ? extra
      : const WebViewArgs(url: 'https://example.com/empty');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebViewArgs &&
          other.url == url &&
          other.title == title &&
          other.fullscreen == fullscreen &&
          mapEquals(other.headers, headers);

  @override
  int get hashCode => Object.hash(
    url,
    title,
    fullscreen,
    Object.hashAllUnordered(
      headers.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

// ---------------------------------------------------------------------------
// 导航层收口：业务只调这一个方法（真实项目里放在 nav_util.dart）
// ---------------------------------------------------------------------------

/// 打开 H5：push = 压栈（右栏叠一层）/ pushReplacement = 替换当前页
Future<T?> openWebView<T>(
  BuildContext context,
  WebViewArgs args, {
  bool replace = false,
}) {
  if (replace) {
    // go_router 16 的 pushReplacement 不返回 Future、无类型参数
    context.pushReplacement('/webview', extra: args);
    return Future<T?>.value();
  }
  return context.push<T>('/webview', extra: args);
}

// ---------------------------------------------------------------------------
// 路由表
// ---------------------------------------------------------------------------

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    // 广告页：普通 GoRoute = 永远全屏（已在 fullscreenRoutes 登记）
    GoRoute(path: '/', builder: (_, _) => const AdPage()),
    // 左栏首页：自己包 EasySplitScope
    GoRoute(
      path: '/home',
      builder: (_, _) => EasySplitScope(child: const HomePage()),
    ),
    // 参数化页：一条路由吃掉所有 H5 入口。
    // url/header 放 extra（go_router 的 matchedLocation 不含 query，
    // 想靠 query 区分页面、又想让去重按内容比较，extra 才是正确位置）。
    EasySplitGoRoute(
      path: '/webview',
      pageBuilder: (BuildContext context, GoRouterState state) {
        final WebViewArgs args = WebViewArgs.fromExtra(state.extra);
        return EasySplitPage<void>(
          fullscreen: args.fullscreen,
          child: (_) => WebViewPage(args: args),
        );
      },
    ),
  ],
  // debug 下把裸「非 easy_split 路由」的入栈打印出来，防止回归
  observers: <NavigatorObserver>[if (kDebugMode) EasySplit.auditObserver],
);

/// 仅供测试在用例之间复位路由栈（真实项目不需要）
@visibleForTesting
GoRouter get mixedRouter => _router;

class MixedDemoApp extends StatelessWidget {
  const MixedDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EasySplit · 混合导航',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      routerConfig: _router,
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
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/home'),
          child: const Text('进入首页'),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const WebViewArgs _promo = WebViewArgs(
    url: 'https://example.com/promo',
    title: '活动页',
    headers: <String, String>{'token': 'abc'},
  );

  OverlayEntry? _mask;

  @override
  void dispose() {
    _mask?.remove();
    _mask = null;
    super.dispose();
  }

  void _toggleMask(BuildContext context, EasySplitPaneSide side) {
    final OverlayEntry? current = _mask;
    if (current != null) {
      current.remove();
      _mask = null;
      return;
    }
    _mask = EasySplit.showPaneOverlay(
      context,
      side: side,
      builder: (BuildContext context) => Align(
        alignment: side == EasySplitPaneSide.left
            ? Alignment.bottomCenter
            : Alignment.topCenter,
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('${side == EasySplitPaneSide.left ? '左侧' : '右侧'}浮层已打开'),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    _mask?.remove();
                    _mask = null;
                  },
                  child: const Text('关闭浮层'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('混合导航示例')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _section('1. 参数化页 + 去重'),
          ListTile(
            title: const Text('同一 H5 连点两次'),
            subtitle: const Text('url + header 都相同 → 只保留一页（默认去重）'),
            onTap: () {
              openWebView(context, _promo);
              openWebView(context, _promo);
            },
          ),
          ListTile(
            title: const Text('同一 H5、不同 header'),
            subtitle: const Text('内容不同 → 正常叠两层（可返回）'),
            onTap: () => openWebView(
              context,
              const WebViewArgs(
                url: 'https://example.com/promo',
                title: '活动页',
                headers: <String, String>{'token': 'xyz'},
              ),
            ),
          ),
          ListTile(
            title: const Text('整窗 H5（支付/风控）'),
            subtitle: const Text('fullscreen: true → 任何宽度都全屏'),
            onTap: () => openWebView(
              context,
              const WebViewArgs(
                url: 'https://example.com/pay',
                title: '支付',
                fullscreen: true,
              ),
            ),
          ),
          const Divider(height: 32),
          _section('2. 浮层'),
          ListTile(
            title: const Text('右栏浮层'),
            subtitle: const Text('EasySplit.showPaneOverlay(side: right)'),
            onTap: () => _toggleMask(context, EasySplitPaneSide.right),
          ),
          ListTile(
            title: const Text('左栏浮层'),
            subtitle: const Text('EasySplit.showPaneOverlay(side: left)'),
            onTap: () => _toggleMask(context, EasySplitPaneSide.left),
          ),
          const Divider(height: 32),
          _section('3. 反面教材：裸 push（看 debug 告警）'),
          ListTile(
            title: const Text('Navigator.push(MaterialPageRoute)'),
            subtitle: const Text('分栏无法接管 → 整窗覆盖左栏，auditObserver 会告警'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/bare-push'),
                builder: (_) => const Scaffold(
                  appBar: null,
                  body: Center(child: Text('裸 push 页面（永远全屏）')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// 伪 WebView 页：只把参数显示出来，证明「一条路由 + extra」够用
class WebViewPage extends StatelessWidget {
  const WebViewPage({super.key, required this.args});

  final WebViewArgs args;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(args.title),
        leading: IconButton(
          // 路由化后必须用 context.pop()，直接 Navigator.pop 会让 go_router
          // 的 match list 失步
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('url: ${args.url}'),
          const SizedBox(height: 8),
          Text('headers: ${args.headers}'),
          const SizedBox(height: 8),
          Text('fullscreen: ${args.fullscreen}'),
          const SizedBox(height: 8),
          Text(args.fullscreen ? '当前整窗显示' : '宽屏时本页在右栏（窄屏整窗）'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => openWebView(
              context,
              const WebViewArgs(
                url: 'https://example.com/promo/detail',
                title: '活动详情',
              ),
            ),
            child: const Text('再打开一个 H5'),
          ),
        ],
      ),
    );
  }
}
