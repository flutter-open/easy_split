import 'package:flutter/material.dart';
import 'package:easy_split/easy_split.dart';

/// 详情页：普通页面，无需任何注解
class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({super.key, this.order});

  final int? order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('订单详情 ${order ?? ''}'),
        // 宽屏：显示 pane 关闭按钮；窄屏：使用系统原生返回
        leading: EasySplit.isWide(context)
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: '关闭 pane',
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('这是详情页'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, '/filter'),
              child: const Text('打开筛选页'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}
