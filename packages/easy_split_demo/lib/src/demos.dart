import 'package:easy_split/easy_split.dart';
// Flutter 3.47+ deprecates flutter/material.dart in favour of package:material_ui,
// which requires Flutter 3.47; this package supports Flutter 3.27+.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 示例页：
///
/// [TabsHomePage]：底部 tabbar 形式的首页，4 个 tab（计数 / 滚动 / 输入 / 宽度）。
/// - 折叠 ⇄ 展开时，当前 tab、计数、滚动位置、输入内容都保留；
/// - 「宽度」tab 演示面板尺寸 vs 整窗尺寸、百分比 / 栅格，以及 ScreenUtil
///   （`.w` / `.sp`）在窗格里的适配方式。
///
/// 入口见 `example/lib/main.dart` / `example/lib/main_1.dart` 的路由表，
/// 与 `pages.dart` 首页列表里的入口卡片。

/// 设计稿尺寸：ScreenUtil 的换算基准（375×812 = iPhone 逻辑分辨率）
const Size kDesignSize = Size(375, 812);

/// 演示用：强制"折叠 / 展开"，不依赖窗口宽度。
///
/// 手机、iPhone 模拟器上没法随时改窗口宽度，但本系列问题的关键在
/// **窄屏 ⇄ 宽屏两条分支之间的结构切换**，所以这里用
/// [EasySplitConfig.isWideOverride] 直接把判定结果钉死，
/// 触发的是与真机折叠完全相同的代码路径。
class DemoViewport {
  DemoViewport._();

  /// null = 跟随窗口；true = 强制宽屏（展开）；false = 强制窄屏（折叠）
  static bool? forceWide;

  static void apply() {
    final value = forceWide;
    EasySplit.config.isWideOverride = value == null
        ? null
        : (BuildContext _) => value;
    EasySplit.updateLayout();
  }
}

/// 自动化（截图 / 回归）用的启动开关，只在 example 生效：
///
/// ```bash
/// flutter run -t lib/main.dart \
///   --dart-define=EASYSPLIT_FORCE_MODE=wide \
///   --dart-define=EASYSPLIT_START_ROUTE=/tabs-home \
///   --dart-define=EASYSPLIT_START_TAB=3
/// ```
///
/// - `EASYSPLIT_FORCE_MODE`：`wide` / `folded` / 空（跟随窗口）；
/// - `EASYSPLIT_START_ROUTE`：启动后直接进入的页面（`/tabs-home`）；
/// - `EASYSPLIT_START_TAB`：TabBar 首页启动时停在第几个 tab（3 = 宽度）。
///
/// 这些开关只影响 example，不改变 easy_split 的行为。
const String _kForceMode = String.fromEnvironment('EASYSPLIT_FORCE_MODE');
const String _kStartRoute = String.fromEnvironment('EASYSPLIT_START_ROUTE');
const int _kStartTab = int.fromEnvironment('EASYSPLIT_START_TAB');

/// 在 `main()` 的 `runApp(...)` 之后调用，应用 `EASYSPLIT_FORCE_MODE`。
void applyDemoAutostart() {
  if (_kForceMode.isEmpty) return;
  DemoViewport.forceWide = switch (_kForceMode) {
    'wide' => true,
    'folded' => false,
    _ => null,
  };
  DemoViewport.apply();
}

/// 首页包装：设置了 `EASYSPLIT_START_ROUTE` 时，直接把对应演示页当成首页。
///
/// 只影响 example 的启动画面（截图 / 手动验收用），不改接入方式：
/// - `EASYSPLIT_START_ROUTE=/tabs-home` → TabBar 首页（第 4 个 tab 是窗格宽度）。
///
/// 其它值则保留原首页，等首帧后再 push（例如 `/detail`）。
Widget demoHome(Widget home, {String? title}) {
  if (_kStartRoute.isEmpty) return home;
  final route = _kStartRoute;
  final direct = switch (route) {
    '/tabs-home' => EasySplitScope(
      child: TabsHomePage(title: title ?? '', initialIndex: _kStartTab),
    ),
    _ => null,
  };
  if (direct != null) return direct;
  // 广告页会在倒计时后 replace 首页，push 到它上面容易被顶掉，
  // 所以只对非演示路由保留 push 行为（首页仍是调用方给的 home）。
  return _StartRoutePusher(route: route, child: home);
}

class _StartRoutePusher extends StatefulWidget {
  const _StartRoutePusher({required this.route, required this.child});

  final String route;
  final Widget child;

  @override
  State<_StartRoutePusher> createState() => _StartRoutePusherState();
}

class _StartRoutePusherState extends State<_StartRoutePusher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushNamed(widget.route);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ---------------------------------------------------------------------------
// 通用小部件
// ---------------------------------------------------------------------------

/// 折叠 / 展开 三态切换（放 AppBar actions）：跟随窗口、强制折叠、强制展开
///
/// 用弹出菜单而不是 SegmentedButton：面板可能只有 200 宽，横排三个选项会溢出。
class ForceModeButton extends StatelessWidget {
  const ForceModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = DemoViewport.forceWide;
    return PopupMenuButton<int>(
      tooltip: '折叠 / 展开（演示）',
      icon: const Icon(Icons.unfold_more),
      onSelected: (value) {
        DemoViewport.forceWide = switch (value) {
          0 => null,
          1 => false,
          _ => true,
        };
        DemoViewport.apply();
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: 0,
          checked: mode == null,
          child: const Text('跟随窗口'),
        ),
        CheckedPopupMenuItem(
          value: 1,
          checked: mode == false,
          child: const Text('强制折叠'),
        ),
        CheckedPopupMenuItem(
          value: 2,
          checked: mode == true,
          child: const Text('强制展开'),
        ),
      ],
    );
  }
}

/// 一行"标签 = 值"的读数
class MetricRow extends StatelessWidget {
  const MetricRow(this.label, this.value, {super.key, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: highlight ? FontWeight.bold : null,
                color: highlight ? theme.colorScheme.primary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 演示卡片：标题 + 说明 + 内容
class DemoCard extends StatelessWidget {
  const DemoCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.tint,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: tint ?? theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. TabBar 形式的首页：折叠 ⇄ 展开，页面状态保留
// ---------------------------------------------------------------------------

/// 底部 tabbar 形式的首页（栈底 + 自带 EasySplitScope，见 main.dart）。
///
/// 展开 / 折叠前请切到任意 tab、把计数加几下、滚动列表、输入几个字 ——
/// 切换之后这四份状态都还在。
class TabsHomePage extends StatefulWidget {
  const TabsHomePage({super.key, required this.title, this.initialIndex = 0});

  /// 当前接入方案（首页标题下方展示）
  final String title;

  /// 启动时停在第几个 tab（演示脚本 / 截图用）
  final int initialIndex;

  @override
  State<TabsHomePage> createState() => _TabsHomePageState();
}

class _TabsHomePageState extends State<TabsHomePage> {
  int _index = 0;
  int _counter = 0;
  String _text = '';
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _scroll.addListener(() {
      final offset = _scroll.offset;
      if ((offset - _offset).abs() >= 1) setState(() => _offset = offset);
    });
    _input.addListener(() => setState(() => _text = _input.text));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = EasySplit.isWide(context);
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('TabBar 首页'),
        actions: const [ForceModeButton(), SizedBox(width: 4)],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          _CounterTab(value: _counter, onAdd: () => setState(() => _counter++)),
          _ScrollTab(controller: _scroll, offset: _offset),
          _InputTab(controller: _input, text: _text),
          const _WidthTab(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 状态条：始终可见，四份状态一眼就能核对
          Material(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '折叠 ⇄ 展开后，下面四份状态都应保留',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    children: [
                      Text(
                        wide ? '已展开' : '折叠态',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        '面板 ${size.width.toStringAsFixed(0)}×'
                        '${size.height.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        'tab：${_tabTitles[_index]}',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text('计数：$_counter', style: theme.textTheme.bodySmall),
                      Text(
                        '滚动：${_offset.toStringAsFixed(0)} px',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text('输入："$_text"', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.exposure_plus_1_outlined),
                selectedIcon: Icon(Icons.exposure_plus_1),
                label: '计数',
              ),
              NavigationDestination(
                icon: Icon(Icons.list_alt_outlined),
                selectedIcon: Icon(Icons.list_alt),
                label: '滚动',
              ),
              NavigationDestination(
                icon: Icon(Icons.edit_note_outlined),
                selectedIcon: Icon(Icons.edit_note),
                label: '输入',
              ),
              NavigationDestination(
                icon: Icon(Icons.straighten_outlined),
                selectedIcon: Icon(Icons.straighten),
                label: '宽度',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// tab 1：计数（值存在父 State，展开后被重建的话会归零）
class _CounterTab extends StatelessWidget {
  const _CounterTab({required this.value, required this.onAdd});

  final int value;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value', style: theme.textTheme.displayMedium),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('加一下'),
          ),
          const SizedBox(height: 8),
          Text('切换折叠 / 展开后，这个数字应该不变', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// tab 2：长列表（滚动位置存在 ScrollController 里）
class _ScrollTab extends StatelessWidget {
  const _ScrollTab({required this.controller, required this.offset});

  final ScrollController controller;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      itemCount: 60,
      itemBuilder: (context, index) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.15,
              ),
              child: Text('$index', style: theme.textTheme.labelSmall),
            ),
            title: Text(
              '第 $index 条 · '
              '${offset.toStringAsFixed(0)} px 处滚动位置会被记住',
            ),
          ),
        );
      },
    );
  }
}

/// tab 3：输入（文本存在 TextEditingController 里）
class _InputTab extends StatelessWidget {
  const _InputTab({required this.controller, required this.text});

  final TextEditingController controller;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
      children: [
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '随便输点字，然后切换折叠 / 展开',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '已输入 ${text.characters.length} 个字符',
          style: theme.textTheme.bodySmall,
        ),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('重建后仍然在：$text', style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ],
    );
  }
}

const _tabTitles = ['计数', '滚动', '输入', '宽度'];

// ---------------------------------------------------------------------------
// tab 4：窗格宽度适配 + ScreenUtil
// ---------------------------------------------------------------------------

/// 按"整体宽度"写的布局，在窗格里拿到的就是窗格自己的宽度。
class _WidthTab extends StatelessWidget {
  const _WidthTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pane = MediaQuery.sizeOf(context);
    final view = View.of(context);
    final window = view.physicalSize / view.devicePixelRatio;
    final ratio = window.width <= 0 ? 1.0 : pane.width / window.width;
    final columns = (pane.width / 170).floor().clamp(1, 4);
    final screenUtilWidth = 240.w;
    final expected = pane.width * 240 / kDesignSize.width;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        DemoCard(
          title: '面板尺寸 vs 整窗尺寸',
          subtitle:
              '面板里 MediaQuery.sizeOf(context) 拿到的就是面板尺寸，'
              '按整体宽度写的百分比 / 栅格 / 间距都会按面板宽度换算。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MetricRow(
                '面板宽 × 高',
                '${pane.width.toStringAsFixed(0)} × '
                    '${pane.height.toStringAsFixed(0)}',
                highlight: true,
              ),
              MetricRow(
                '整窗宽 × 高',
                '${window.width.toStringAsFixed(0)} × '
                    '${window.height.toStringAsFixed(0)}',
              ),
              MetricRow('面板 ÷ 整窗', '${(ratio * 100).toStringAsFixed(0)}%'),
              MetricRow(
                'EasySplit.paneWidth',
                EasySplit.paneWidth(context).toStringAsFixed(0),
              ),
              MetricRow(
                '布局方向',
                MediaQuery.orientationOf(context) == Orientation.landscape
                    ? '横屏'
                    : '竖屏',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DemoCard(
          title: '百分比宽度（不用改代码）',
          subtitle:
              '三条都按"面板宽度"的 100% / 50% / 25% 排，'
              '窗格多宽就是多宽，不受整窗宽度影响。',
          child: Column(
            children: [
              for (final f in const [1.0, 0.5, 0.25])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: pane.width - 28,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: f,
                      child: Container(
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${(f * 100).toStringAsFixed(0)}% = '
                          '${(pane.width * f).toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DemoCard(
          title: 'ScreenUtil（.w / .sp）适配',
          subtitle:
              'ScreenUtil 读的是原始 FlutterView，不是 MediaQuery，'
              '所以要在 main() 里用 onPaneMediaQuery 转发一次（见 main.dart）。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MetricRow('设计稿宽度', kDesignSize.width.toStringAsFixed(0)),
              MetricRow(
                '240.w 实际',
                screenUtilWidth.toStringAsFixed(1),
                highlight: true,
              ),
              MetricRow(
                '期望值',
                '${expected.toStringAsFixed(1)}（= 面板宽 × 240 / 375）',
              ),
              const SizedBox(height: 10),
              Container(
                // 盒子高度也跟着 sp 缩放，否则大字体会被裁掉
                height: 16.sp * 2.2,
                width: screenUtilWidth,
                alignment: Alignment.center,
                color: theme.colorScheme.tertiary.withValues(alpha: 0.18),
                child: Text('240.w', style: TextStyle(fontSize: 16.sp)),
              ),
              const SizedBox(height: 10),
              Text(
                'ScreenUtil 是全局单例：左右两栏同时可见时，后构建的一栏生效。'
                '多栏同屏且各自需要不同缩放比的场景，请改用 '
                'EasySplit.paneMediaQuery 自行计算（README 有示例）。',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DemoCard(
          title: '栅格列数',
          subtitle:
              '按面板宽度算列数 = (面板宽 / 170).floor()，'
              '当前（面板 ${pane.width.toStringAsFixed(0)}）→ $columns 列。',
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 色块宽度按卡片实际可用宽度算（不是整窗宽度）
              final tileWidth =
                  (constraints.maxWidth - 8 * (columns - 1)) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < columns * 2; i++)
                    Container(
                      width: tileWidth,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.16,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('#$i', style: theme.textTheme.bodySmall),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
