import 'package:flutter/material.dart';
import 'package:easy_split/easy_split.dart';

/// 筛选页：普通页面，无需任何注解
class FilterPage extends StatelessWidget {
  const FilterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('筛选'),
        leading: EasySplit.isWide(context)
            ? CloseButton(onPressed: () => Navigator.pop(context))
            : BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        children: [
          for (final s in ['价格', '销量', '好评率', '配送时效'])
            CheckboxListTile(title: Text(s), value: false, onChanged: (_) {}),
        ],
      ),
    );
  }
}
