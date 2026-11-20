import 'package:easy_split/easy_split.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import 'pages/detail_page.dart';
import 'pages/filter_page.dart';
import 'pages/login_page.dart';

/// EasySplit 全局配置（各入口共用）
void configureEasySplit() {
  EasySplit.config
    ..paneRatio = 0.5 // 左右占比（右侧比例，默认 0.5）
    ..placeholderBuilder = (context) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.dashboard_outlined,
                  size: 48, color: Theme.of(context).disabledColor),
              const SizedBox(height: 12),
              const Text('请选择一个订单查看详情',
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        );
  EasySplit.fullscreenRoutes.addAll({'/login'}); // 沉浸页不参与分栏
}

/// 路由表（各入口共用同一份业务路由）
Map<String, WidgetBuilder> demoRoutes() => {
      '/detail': (_) => const OrderDetailPage(),
      '/filter': (_) => const FilterPage(),
      '/login': (_) => const LoginPage(),
    };

/// 列表页（栈底）：各入口共用；[title] 用于区分当前运行的入口
///
/// 跳转通过 [onDetail] / [onLogin] 回调注入：
/// - 命名路由入口传 null（默认走 Navigator.pushNamed）
/// - GoRouter 入口传 `() => context.push('/detail')`
class DemoRootPage extends StatelessWidget {
  const DemoRootPage({super.key, this.title = 'EasySplit Demo'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // 适配开关：随时切换（默认开启）
          ValueListenableBuilder<bool>(
            valueListenable: EasySplit.config.enabled,
            builder: (_, on, __) => Row(children: [
              Text(on ? '适配开' : '适配关',
                  style: const TextStyle(fontSize: 13)),
              Switch(value: on, onChanged: (v) => EasySplit.enabled = v),
            ]),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _section(
            context,
            title: '订单列表',
            icon: Icons.list_alt,
            children: [
              for (var i = 1; i <= 8; i++)
                ListTile(
                  leading: CircleAvatar(child: Text('$i')),
                  title: Text('订单 #$i'),
                  subtitle: const Text('宽屏：右侧分栏显示；窄屏：全屏'),
                  trailing: const Icon(Icons.chevron_right),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  onTap: () =>
                      Navigator.pushNamed(context, '/detail', arguments: i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _section(
            context,
            title: '沉浸页',
            icon: Icons.login,
            children: [
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('登录页'),
                subtitle: const Text('fullscreenRoutes 名单：任何宽度都全屏'),
                trailing: const Icon(Icons.chevron_right),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                onTap: () => context.push('/login'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _section(
            context,
            title: '弹窗表现测试（系统 Dialog / Actionsheet / SnackBar）',
            icon: Icons.picture_in_picture_alt,
            children: [
              ListTile(
                leading: const Icon(Icons.center_focus_strong),
                title: const Text('系统 Dialog'),
                subtitle: const Text('验证：分栏模式下弹窗全屏居中显示'),
                trailing: const Icon(Icons.chevron_right),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                onTap: () => _showDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.call_to_action),
                title: const Text('系统 Actionsheet（底部弹层）'),
                subtitle: const Text('验证：底部弹层的宽度与避让表现'),
                trailing: const Icon(Icons.chevron_right),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                onTap: () => _showActionSheet(context),
              ),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('SnackBar'),
                subtitle: const Text('验证：轻提示的表现'),
                trailing: const Icon(Icons.chevron_right),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                onTap: () => _showSnackBar(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 分组卡片
  Widget _section(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          ...children,
        ],
      ),
    );
  }

  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('系统 Dialog'),
        content: const Text('验证分栏模式下系统弹窗的表现：弹窗应全屏居中显示，'
            '不随左栏 / 右栏布局变化。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'ok'),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('编辑订单'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('删除订单'),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('EasySplit SnackBar 测试'),
        behavior: SnackBarBehavior.floating,
        width: 360,
      ),
    );
  }
}
