import 'dart:async';

import 'package:easy_split/easy_split.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// Demo 页面：广告页 → 首页（可开始分屏）→ 一级页 → 二级页 → 系统弹窗大全
/// （导航直接调 Navigator.pushNamed，入口见 main.dart）

// ---------------------------------------------------------------------------
// 演示数据
// ---------------------------------------------------------------------------

class DemoItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> paragraphs;

  const DemoItem(
    this.title,
    this.subtitle,
    this.icon,
    this.color, [
    this.paragraphs = const [],
  ]);
}

const kDemoItems = [
  DemoItem(
    '平行视界是什么',
    '一个路由栈，宽窄自适应',
    Icons.splitscreen_outlined,
    Colors.indigo,
    [
      '折叠（窄屏）时是普通的全屏路由；展开（宽屏）时同一条路由渲染到右侧面板，栈完全不动。',
      '宽窄切换是纯表现层的自适应，旋转屏幕、拖动窗口宽度的瞬间不丢状态。',
    ],
  ),
  DemoItem(
    '接入三件套',
    'Scope + 路由适配 + 配置',
    Icons.checklist_outlined,
    Colors.blue,
    ['列表页（栈底）包 EasySplitScope；路由接入一行；配置全在 EasySplit.config。'],
  ),
  DemoItem('一级页 · 详情', '本页就是被分栏的一级页', Icons.article_outlined, Colors.teal, [
    '宽屏时本页渲染在右栏，窄屏时是普通全屏页。右上角可进入二级页。',
  ]),
  DemoItem(
    '全屏沉浸页',
    'fullscreenRoutes 名单',
    Icons.fullscreen_outlined,
    Colors.deepOrange,
    ['登录页、播放页等任何宽度都全屏；首页不是启动首路由的应用也靠它分栏。'],
  ),
  DemoItem(
    '铰链避让',
    'displayFeatures.hinge',
    Icons.smartphone_outlined,
    Colors.purple,
    ['右栏宽度计算会扣除 hinge 区域；安全区按方向自动避让。'],
  ),
];

// ---------------------------------------------------------------------------
// 0. 模拟登录（纯内存态，重启即失效；真实项目换成自己的登录服务即可）
// ---------------------------------------------------------------------------

/// 演示用的登录态：null = 未登录，非 null = 当前登录用户名。
class DemoAuth {
  DemoAuth._();

  static final ValueNotifier<String?> currentUser = ValueNotifier<String?>(null);

  static bool get isLoggedIn => currentUser.value != null;

  static void login([String name = '演示用户']) => currentUser.value = name;

  static void logout() => currentUser.value = null;
}

/// 需要登录才能进入的页面（demo 统一在入口按钮处拦截）。
const kProtectedRoutes = {'/detail', '/secondary', '/dialogs'};

/// 未登录时先跳登录页，登录成功返回 true；已登录直接返回 true。
Future<bool> ensureLoggedIn(BuildContext context) async {
  if (DemoAuth.isLoggedIn) return true;
  final ok = await Navigator.pushNamed<bool>(context, '/login');
  return ok ?? false;
}

/// 首页按钮统一走这里：先登录，登录成功后再跳目标页。
Future<void> openProtected(
  BuildContext context,
  String route, {
  Object? arguments,
}) async {
  if (kProtectedRoutes.contains(route)) {
    if (!await ensureLoggedIn(context)) return;
    if (!context.mounted) return;
  }
  await Navigator.pushNamed(context, route, arguments: arguments);
}

/// 登录页（模拟）：入口处把 '/login' 放进 fullscreenRoutes，宽屏也全屏展示。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController(text: '138 0000 8888');
  final _code = TextEditingController(text: '8888');
  bool _agree = true;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    DemoAuth.login();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
        leading: IconButton(
          tooltip: '关闭',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.splitscreen_outlined,
                  size: 44,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '登录后继续',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '这是演示用的模拟登录，不会真的发请求；登录后才能查看详情、二级页和弹窗示例。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '手机号',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_iphone),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '验证码',
                helperText: '演示用，随便填',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.sms_outlined),
              ),
            ),
            CheckboxListTile(
              value: _agree,
              onChanged: (value) => setState(() => _agree = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: const Text('已阅读并同意《演示用户协议》'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _agree ? _submit : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('模拟登录'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('暂不登录，先逛逛'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. 广告页（全屏，不参与分栏）
// ---------------------------------------------------------------------------

class AdPage extends StatefulWidget {
  const AdPage({super.key});

  @override
  State<AdPage> createState() => _AdPageState();
}

class _AdPageState extends State<AdPage> {
  int _remaining = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) {
        timer.cancel();
        if (mounted) _goHome(context);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goHome(BuildContext context) =>
      Navigator.pushReplacementNamed(context, '/home'); // replace，广告页不留在栈里

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A237E), Color(0xFF3949AB), Color(0xFF5C6BC0)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const Icon(
                        Icons.splitscreen_outlined,
                        size: 96,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'EasySplit',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '折叠屏 · 平行视界 · 一栈双栏',
                      style: TextStyle(fontSize: 15, color: Colors.white70),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: () => _goHome(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1A237E),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 14,
                        ),
                      ),
                      child: const Text(
                        '立即进入首页',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 16,
                child: OutlinedButton(
                  onPressed: () => _goHome(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: Text('跳过 $_remaining'),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Text(
                  '广告页不参与分栏 · 全屏沉浸',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. 首页（列表页 = 左栏）：包 EasySplitScope
// ---------------------------------------------------------------------------

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('EasySplit 平行视界'),
        actions: [
          IconButton(
            tooltip: '系统弹窗大全',
            icon: const Icon(Icons.widgets_outlined),
            onPressed: () => openProtected(context, '/dialogs'),
          ),
          const _LoginButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: ValueListenableBuilder<String?>(
        valueListenable: DemoAuth.currentUser,
        builder: (context, user, _) {
          final locked = user == null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // —— 分屏控制卡片 ——
              _SplitControlCard(title: title),
              const SizedBox(height: 12),
              // —— 登录状态：未登录时所有入口先跳登录页 ——
              _AuthCard(user: user),
              const SizedBox(height: 12),
              // —— 弹窗入口 ——
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest,
                child: ListTile(
                  leading: Icon(
                    Icons.widgets_outlined,
                    color: Colors.pink.shade400,
                  ),
                  title: const Text('系统弹窗大全'),
                  subtitle: const Text(
                    'AlertDialog / BottomSheet / Picker / SnackBar…',
                  ),
                  trailing: Icon(
                    locked ? Icons.lock_outline : Icons.chevron_right,
                  ),
                  onTap: () => openProtected(context, '/dialogs'),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 8,
                ),
                child: Text(
                  locked ? '内容列表（未登录，点击先去登录）' : '内容列表（点击 → 一级页详情）',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
              // —— 列表：宽屏点开进右栏，窄屏全屏 push ——
              for (final item in kDemoItems)
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.color.withValues(alpha: 0.15),
                      foregroundColor: item.color,
                      child: Icon(item.icon, size: 22),
                    ),
                    title: Text(item.title),
                    subtitle: Text(item.subtitle, maxLines: 1),
                    trailing: Icon(
                      locked ? Icons.lock_outline : Icons.chevron_right,
                      size: 20,
                    ),
                    onTap: () =>
                        openProtected(context, '/detail', arguments: item),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 右上角登录 / 退出按钮：登录态变化时自动重建。
class _LoginButton extends StatelessWidget {
  const _LoginButton();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: DemoAuth.currentUser,
      builder: (context, user, _) {
        if (user == null) {
          return TextButton.icon(
            onPressed: () async {
              final ok = await ensureLoggedIn(context);
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('登录成功，入口已解锁')),
                  );
              }
            },
            icon: const Icon(Icons.login),
            label: const Text('登录'),
          );
        }
        return TextButton.icon(
          onPressed: () {
            DemoAuth.logout();
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('已退出登录')));
          },
          icon: const Icon(Icons.logout),
          label: Text(user),
        );
      },
    );
  }
}

/// 登录状态卡片：未登录时提示入口会先跳登录，登录后显示当前用户。
class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.user});

  final String? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loggedIn = user != null;
    return Card(
      elevation: 0,
      color: loggedIn
          ? theme.colorScheme.tertiaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: loggedIn
              ? theme.colorScheme.tertiary
              : theme.colorScheme.outlineVariant,
          child: Icon(loggedIn ? Icons.person : Icons.lock_outline),
        ),
        title: Text(loggedIn ? '已登录：$user' : '未登录（演示）'),
        subtitle: Text(loggedIn ? '所有入口已解锁' : '点任意条目会先进入模拟登录页'),
        trailing: loggedIn
            ? null
            : TextButton(
                onPressed: () => ensureLoggedIn(context),
                child: const Text('去登录'),
              ),
      ),
    );
  }
}

/// 演示用：自定义分栏布局（layoutDelegate）与比例，改完调用
/// [EasySplit.updateLayout] 立即生效，路由栈不动。
enum DemoSplitMode {
  sideBySide('左右分栏'),
  swapped('内容在左'),
  vertical('上下分栏'),
  floating('悬浮内容栏');

  const DemoSplitMode(this.label);

  final String label;
}

class DemoSplitLayout {
  DemoSplitLayout._();

  static const double minRatio = 0.2;
  static const double maxRatio = 0.8;
  static const double defaultRatio = 0.5;

  /// 当前布局模式
  static DemoSplitMode mode = DemoSplitMode.sideBySide;

  static bool get isDefault =>
      mode == DemoSplitMode.sideBySide && EasySplit.paneRatio == defaultRatio;

  static void apply() {
    EasySplit.config.layoutDelegate = switch (mode) {
      DemoSplitMode.sideBySide => null,
      DemoSplitMode.swapped => _swapped,
      DemoSplitMode.vertical => _vertical,
      DemoSplitMode.floating => _floating,
    };
    EasySplit.updateLayout();
  }

  static void setMode(DemoSplitMode value) {
    mode = value;
    apply();
  }

  static void setRatio(double ratio) {
    EasySplit.paneRatio = ratio.clamp(minRatio, maxRatio);
    apply();
  }

  static void reset() {
    mode = DemoSplitMode.sideBySide;
    EasySplit.paneRatio = defaultRatio;
    apply();
  }

  /// 交换默认布局的左右矩形：内容栏去左边，列表去右边
  static EasySplitLayout _swapped(BuildContext context) {
    final layout = EasySplit.defaultLayout(context);
    return EasySplitLayout(
      leftRect: layout.paneRect,
      paneRect: layout.leftRect,
    );
  }

  /// 上下分栏：列表在上、内容栏在下，内容栏高度占 paneRatio
  static EasySplitLayout _vertical(BuildContext context) {
    final layout = EasySplit.defaultLayout(context);
    final width = layout.leftRect.width + layout.paneRect.width;
    final height = layout.leftRect.height;
    final paneHeight = height * EasySplit.paneRatio;
    return EasySplitLayout(
      leftRect: Rect.fromLTWH(0, 0, width, height - paneHeight),
      paneRect: Rect.fromLTWH(0, height - paneHeight, width, paneHeight),
    );
  }

  /// 悬浮内容栏：右侧内容区四周留出 16 的间距
  static EasySplitLayout _floating(BuildContext context) {
    final layout = EasySplit.defaultLayout(context);
    return EasySplitLayout(
      leftRect: layout.leftRect,
      paneRect: layout.paneRect.deflate(16),
    );
  }

  /// 打开设置弹窗
  static Future<void> openSettings(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final ratio = EasySplit.paneRatio;
          final labelStyle = Theme.of(context).textTheme.labelLarge;
          return AlertDialog(
            title: const Text('分栏布局设置'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('布局模式', style: labelStyle),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final value in DemoSplitMode.values)
                        ChoiceChip(
                          label: Text(value.label),
                          selected: mode == value,
                          onSelected: (_) {
                            setMode(value);
                            setDialogState(() {});
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('内容栏占比', style: labelStyle),
                      const Spacer(),
                      Text('${(ratio * 100).round()}%'),
                    ],
                  ),
                  Slider(
                    value: ratio,
                    min: minRatio,
                    max: maxRatio,
                    divisions: 12,
                    label: '${(ratio * 100).round()}%',
                    onChanged: (value) {
                      setRatio(value);
                      setDialogState(() {});
                    },
                  ),
                  Text(
                    '${mode.label}：内容栏 ${(ratio * 100).round()}% · '
                    '列表 ${((1 - ratio) * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  reset();
                  setDialogState(() {});
                },
                child: const Text('恢复默认'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成'),
              ),
            ],
          );
        },
      ),
    );
  }
}
/// 「开始分屏 / 停止分屏 + 分栏布局设置」：布局改动调用 EasySplit.updateLayout 即时生效
class _SplitControlCard extends StatelessWidget {
  const _SplitControlCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        EasySplit.config.enabled,
        EasySplit.config.layoutVersion,
      ]),
      builder: (context, _) {
        final enabled = EasySplit.config.enabled.value;
        final isWide = EasySplit.isWide(context);
        final ratio = (EasySplit.paneRatio * 100).round();
        final modeLabel = DemoSplitLayout.mode.label;
        return Card(
          elevation: 0,
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isWide
                          ? Icons.tablet_mac_outlined
                          : Icons.smartphone_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isWide ? '当前：宽屏（已展开）' : '当前：窄屏（折叠态）',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isWide ? '点击列表项，内容会显示在分栏区。' : '把窗口拖宽（或旋转模拟器）即可展开左右分栏。',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '布局：$modeLabel · 内容栏 $ratio%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => EasySplit.enabled = !EasySplit.enabled,
                      icon: Icon(
                        enabled ? Icons.flip_outlined : Icons.open_in_full,
                      ),
                      label: Text(enabled ? '停止分屏适配' : '开始分屏适配'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => DemoSplitLayout.openSettings(context),
                      icon: const Icon(Icons.tune),
                      label: const Text('分栏设置'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 3. 一级页（详情）—— 宽屏右栏 / 窄屏全屏
// ---------------------------------------------------------------------------

class DetailPage extends StatelessWidget {
  const DetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final item = ModalRoute.of(context)!.settings.arguments as DemoItem;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/secondary'),
            child: const Text('进入二级页'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [item.color, item.color.withValues(alpha: 0.55)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(item.icon, size: 56, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            item.subtitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 16,
                color: theme.hintColor,
              ),
              const SizedBox(width: 4),
              Text(
                '当前登录：${DemoAuth.currentUser.value ?? '未登录'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final p in item.paragraphs) ...[
            Text(p, style: theme.textTheme.bodyMedium?.copyWith(height: 1.7)),
            const SizedBox(height: 12),
          ],
          const Divider(height: 32),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pushNamed(context, '/secondary'),
            icon: const Icon(Icons.layers_outlined),
            label: const Text('打开二级页'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/dialogs'),
            icon: const Icon(Icons.widgets_outlined),
            label: const Text('看看系统弹窗大全'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. 二级页
// ---------------------------------------------------------------------------

class SecondaryPage extends StatelessWidget {
  const SecondaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('二级页'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/dialogs'),
            child: const Text('弹窗大全'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(
            Icons.layers_outlined,
            size: 72,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            '这是二级页',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            '宽屏下：一二级页同在右栏区域，右栏内部形成层级；\n窄屏下：这就是普通的全屏返回栈。',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/dialogs'),
            icon: const Icon(Icons.widgets_outlined),
            label: const Text('打开系统弹窗大全'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. 系统弹窗大全（Overlay 天然盖在分栏之上，无需适配）
// ---------------------------------------------------------------------------

class DialogsPage extends StatelessWidget {
  const DialogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('系统弹窗大全')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            '弹窗基于 Overlay，天然悬浮于分栏之上，无需任何适配。',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 12),
          _Section('Dialog 对话框'),
          _DialogTile(
            'AlertDialog · 确认框',
            'showDialog + AlertDialog',
            (ctx) => _confirmDialog(ctx),
          ),
          _DialogTile(
            'AlertDialog · 输入框',
            'TextField 嵌入对话框',
            (ctx) => _inputDialog(ctx),
          ),
          _DialogTile(
            'SimpleDialog · 单选',
            'SimpleDialogOption',
            (ctx) => _simpleDialog(ctx),
          ),
          _DialogTile(
            '自定义 Dialog',
            'showDialog + Dialog',
            (ctx) => _customDialog(ctx),
          ),
          _DialogTile(
            'AboutDialog',
            'showAboutDialog',
            (ctx) => _aboutDialog(ctx),
          ),
          _DialogTile(
            '全屏对话框',
            'showGeneralDialog',
            (ctx) => _fullscreenDialog(ctx),
          ),
          const _Section('BottomSheet 底部弹层'),
          _DialogTile(
            '模态 BottomSheet',
            'showModalBottomSheet',
            (ctx) => _modalSheet(ctx),
          ),
          _DialogTile(
            '持久 BottomSheet',
            'Scaffold.showBottomSheet',
            (ctx) => _persistentSheet(ctx),
          ),
          const _Section('Picker 选择器'),
          _DialogTile('日期选择器', 'showDatePicker', (ctx) => _pickDate(ctx)),
          _DialogTile('时间选择器', 'showTimePicker', (ctx) => _pickTime(ctx)),
          _DialogTile(
            '日期范围选择器',
            'showDateRangePicker',
            (ctx) => _pickRange(ctx),
          ),
          const _Section('提示类'),
          _DialogTile(
            'SnackBar',
            'ScaffoldMessenger 底部提示',
            (ctx) => _snackBar(ctx),
          ),
          _DialogTile('MaterialBanner', '顶部横幅', (ctx) => _banner(ctx)),
          const _Section('Menu 菜单'),
          _DialogTile('PopupMenuButton', '锚点弹出菜单', (ctx) => _popupMenu(ctx)),
          _DialogTile(
            'showMenu · 定位菜单',
            'RelativeRect 定位弹出',
            (ctx) => _menuAt(ctx),
          ),
          _DialogTile(
            'DropdownMenu 下拉',
            '表单式下拉选择（M3）',
            (ctx) => _dropdown(ctx),
          ),
        ],
      ),
    );
  }

  void _confirmDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.help_outline),
        title: const Text('开启分屏适配？'),
        content: const Text('开启后宽屏设备自动左右分栏，路由栈不动，可随时关闭。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              EasySplit.enabled = true;
              Navigator.pop(context);
              _toast(context, '已开启分屏适配');
            },
            child: const Text('开启'),
          ),
        ],
      ),
    );
  }

  void _inputDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '新名称',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    ).then((v) {
      if (v != null && v.isNotEmpty && context.mounted) {
        _toast(context, '新名称：$v');
      }
    });
  }

  void _simpleDialog(BuildContext context) {
    showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择分栏比例'),
        children: [
          for (final ratio in const [0.35, 0.4, 0.5, 0.6])
            SimpleDialogOption(
              onPressed: () {
                EasySplit.paneRatio = ratio;
                Navigator.pop(context);
                _toast(context, '右栏占比已设为 ${(ratio * 100).round()}%');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('${(ratio * 100).round()}%'),
              ),
            ),
        ],
      ),
    );
  }

  void _customDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              const Text('自定义样式对话框'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _aboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'EasySplit Demo',
      applicationVersion: '0.1.0',
      applicationIcon: const Icon(Icons.splitscreen_outlined, size: 40),
      children: const [Text('仿鸿蒙"平行视界"的 Flutter 分栏适配引擎示例。')],
    );
  }

  void _fullscreenDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '全屏对话框',
      pageBuilder: (context, _, _) => Scaffold(
        appBar: AppBar(title: const Text('全屏对话框')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.open_with_outlined, size: 64),
              const SizedBox(height: 12),
              const Text('fullscreenDialog：整页弹出'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('关闭'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _modalSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              leading: Icon(Icons.tune_outlined),
              title: Text('分栏设置'),
              subtitle: Text('模态底部弹层（上滑关闭）'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.refresh_outlined),
              title: const Text('重置配置'),
              onTap: () {
                EasySplit.config.paneRatio = 0.5;
                Navigator.pop(context);
                _toast(context, '配置已重置');
              },
            ),
            ListTile(
              leading: const Icon(Icons.toggle_on_outlined),
              title: const Text('切换适配开关'),
              onTap: () {
                EasySplit.enabled = !EasySplit.enabled;
                Navigator.pop(context);
                _toast(context, '适配开关：${EasySplit.enabled ? "开" : "关"}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.close_outlined),
              title: const Text('取消'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _persistentSheet(BuildContext context) {
    Scaffold.of(context).showBottomSheet(
      (context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('持久 BottomSheet（不遮挡整页）'),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context),
              child: const Text('收起'),
            ),
          ],
        ),
      ),
    );
    _toast(context, '已展开持久底部弹层');
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: '选择日期',
    );
    if (date != null && context.mounted) {
      _toast(context, '选择了 ${date.toLocal()}'.split(' ').first);
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: '选择时间',
    );
    if (time != null && context.mounted) _toast(context, '选择了 $time');
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDateRange: DateTimeRange(
        start: now,
        end: now.add(const Duration(days: 6)),
      ),
      helpText: '选择日期范围',
    );
    if (range != null && context.mounted) {
      final start = '${range.start.toLocal()}'.split(' ').first;
      final end = '${range.end.toLocal()}'.split(' ').first;
      _toast(context, '$start ~ $end');
    }
  }

  void _snackBar(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('这是一条 SnackBar（带撤销操作）'),
          action: SnackBarAction(label: '撤销', onPressed: () {}),
        ),
      );
  }

  void _banner(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          content: const Text('这是一条 MaterialBanner 顶部横幅'),
          leading: const Icon(Icons.info_outline),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            TextButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
  }

  void _popupMenu(BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromCenter(
          center: box.localToGlobal(box.size.center(Offset.zero)),
          width: 0,
          height: 0,
        ),
        Offset.zero & box.size,
      ),
      items: const [
        PopupMenuItem(value: 'ratio', child: Text('调整分栏比例')),
        PopupMenuItem(value: 'toggle', child: Text('切换适配开关')),
        PopupMenuItem(value: 'about', child: Text('关于 EasySplit')),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'ratio':
          _simpleDialog(context);
        case 'toggle':
          EasySplit.enabled = !EasySplit.enabled;
          _toast(context, '适配开关：${EasySplit.enabled ? "开" : "关"}');
        case 'about':
          _aboutDialog(context);
      }
    });
  }

  void _menuAt(BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(24, box.size.height - 200, 24, 0),
      items: List.generate(
        3,
        (i) => PopupMenuItem(value: i, child: Text('选项 ${i + 1}')),
      ),
    ).then((v) {
      if (v != null && context.mounted) _toast(context, '选择了选项 ${v + 1}');
    });
  }

  void _dropdown(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        String? value;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('DropdownMenu'),
            content: DropdownButtonFormField<String>(
              initialValue: value,
              decoration: const InputDecoration(
                labelText: '布局模式',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'auto', child: Text('自动（默认布局）')),
                DropdownMenuItem(value: 'custom', child: Text('自定义布局')),
                DropdownMenuItem(value: 'off', child: Text('关闭分栏')),
              ],
              onChanged: (v) => setState(() => value = v),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (value != null) _toast(context, '布局模式：$value');
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DialogTile extends StatelessWidget {
  const _DialogTile(this.title, this.subtitle, this.onTap);

  final String title;
  final String subtitle;
  final void Function(BuildContext) onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => onTap(context),
      ),
    );
  }
}
