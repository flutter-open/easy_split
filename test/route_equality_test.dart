import 'package:easy_split/easy_split.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 值相等、但每次都是新实例的参数对象（模拟业务模型类）
class _Id {
  const _Id(this.value);

  final int value;

  @override
  bool operator ==(Object other) => other is _Id && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

RouteSettings _s(String? name, Object? arguments) =>
    RouteSettings(name: name, arguments: arguments);

/// n 层嵌套 Map，叶子是每次新建的字符串（避免 identical 短路）
Object? _nested(int levels) => levels == 0
    ? String.fromCharCodes(const [108, 101, 97, 102]) // 'leaf'
    : <String, Object?>{'k': _nested(levels - 1)};

void main() {
  group('easySplitSameRoute：name', () {
    test('name 不同 → false，即使参数相同', () {
      expect(easySplitSameRoute(_s('/a', 'x'), _s('/b', 'x')), isFalse);
    });

    test('name 相同 + 参数相等 → true', () {
      expect(easySplitSameRoute(_s('/a', 'x'), _s('/a', 'x')), isTrue);
    });

    test('name 都为 null + 参数都为 null → true', () {
      expect(easySplitSameRoute(_s(null, null), _s(null, null)), isTrue);
    });

    test('name 相同 + 一侧参数为 null → false', () {
      expect(easySplitSameRoute(_s('/a', null), _s('/a', {})), isFalse);
    });
  });

  group('easySplitArgumentsEqual：Map / List', () {
    test('内容相同的两个 Map（不同实例）→ true', () {
      expect(
        easySplitArgumentsEqual(
          {
            'url': 'https://x',
            'headerMap': {'token': 't'}
          },
          {
            'url': 'https://x',
            'headerMap': {'token': 't'}
          },
        ),
        isTrue,
      );
    });

    test('Map 键顺序不同 → true', () {
      expect(
        easySplitArgumentsEqual({'a': 1, 'b': 2}, {'b': 2, 'a': 1}),
        isTrue,
      );
    });

    test('嵌套值不同 → false', () {
      expect(
        easySplitArgumentsEqual(
          {
            'headerMap': {'token': 't'}
          },
          {
            'headerMap': {'token': 'u'}
          },
        ),
        isFalse,
      );
    });

    test('键数量 / 缺少键 → false', () {
      expect(easySplitArgumentsEqual({'a': 1}, {'a': 1, 'b': 2}), isFalse);
      expect(easySplitArgumentsEqual({'a': 1}, {'b': 1}), isFalse);
    });

    test('List 顺序 / 长度不同 → false', () {
      expect(easySplitArgumentsEqual([1, 2], [2, 1]), isFalse);
      expect(easySplitArgumentsEqual([1, 2], [1, 2, 3]), isFalse);
    });

    test('Map 与 List 类型不同 → false', () {
      expect(easySplitArgumentsEqual(<Object?>{}, <Object?>[]), isFalse);
    });

    test('嵌套 List<Map> → true', () {
      expect(
        easySplitArgumentsEqual(
          [
            {'id': 1},
            {'id': 2},
          ],
          [
            {'id': 1},
            {'id': 2},
          ],
        ),
        isTrue,
      );
    });
  });

  group('easySplitArgumentsEqual：其他类型', () {
    test('重写 == 的模型类按值比较', () {
      expect(easySplitArgumentsEqual(const _Id(1), const _Id(1)), isTrue);
      expect(easySplitArgumentsEqual(const _Id(1), const _Id(2)), isFalse);
    });

    test('未重写 == 的普通对象仍按引用比较', () {
      final a = Object();
      expect(easySplitArgumentsEqual(a, a), isTrue);
      expect(easySplitArgumentsEqual(Object(), Object()), isFalse);
    });

    test('相同实例的 Map 走 identical 快速路径', () {
      final map = <String, Object?>{'a': 1};
      expect(easySplitArgumentsEqual(map, map), isTrue);
    });
  });

  group('easySplitArgumentsEqual：预算与自引用', () {
    test('自引用 Map（不同实例）不会栈溢出，返回 false', () {
      final a = <String, Object?>{'self': null};
      a['self'] = a;
      final b = <String, Object?>{'self': null};
      b['self'] = b;
      expect(easySplitArgumentsEqual(a, b), isFalse);
    });

    test('同一自引用实例 → true（identical 短路）', () {
      final a = <String, Object?>{'self': null};
      a['self'] = a;
      expect(easySplitArgumentsEqual(a, a), isTrue);
    });

    test('嵌套 12 层仍可比较，13 层视为不同', () {
      expect(easySplitArgumentsEqual(_nested(12), _nested(12)), isTrue);
      expect(easySplitArgumentsEqual(_nested(13), _nested(13)), isFalse);
    });

    test('节点预算 256：255 个元素 → true，256 个 → false', () {
      List<_Id> ids(int n) => List<_Id>.generate(n, (i) => _Id(i));
      expect(easySplitArgumentsEqual(ids(255), ids(255)), isTrue);
      expect(easySplitArgumentsEqual(ids(256), ids(256)), isFalse);
    });

    test('预算内的大列表仍按内容比较（值不同 → false）', () {
      expect(
        easySplitArgumentsEqual(
          List<_Id>.generate(100, (i) => _Id(i)),
          List<_Id>.generate(100, (i) => _Id(i + 1)),
        ),
        isFalse,
      );
    });
  });
}
