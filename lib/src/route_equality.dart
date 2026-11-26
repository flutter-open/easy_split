import 'package:flutter/widgets.dart';

/// 参数比较的最大嵌套层数（Map / List 才算一层）
const int _maxArgumentDepth = 12;

/// 参数比较的最大节点预算，超出后直接判定为「不同」
const int _maxArgumentNodes = 256;

/// 默认的「同一页面」判等：`name` 相同且 `arguments` 结构相等
///
/// 这是 `EasySplitConfig.sameRoute` 未设置时使用的规则。之所以不能直接用
/// `a.arguments == b.arguments`：Dart 的 `Map` / `List` 没有重写 `==`，比较的
/// 是引用；而重复点击同一链接时每次都会 new 一个内容相同的新 `Map`
/// （如 webview 的 `{'url': ..., 'headerMap': {...}}`），`==` 永远不成立，
/// 去重也就永远不命中。
///
/// 规则：
/// - `Map` / `List`：按内容递归比较，嵌套结构同样生效（键顺序不影响 `Map`）；
/// - 其他类型：直接用 `==`（`String` / `num` / `bool` / 重写了 `==` 的模型类等）；
/// - 设有深度（12 层）与节点（256 个）预算：超出预算或遇到自引用结构时返回
///   `false`——宁可多压一页（可返回），也不误去重（页面状态被顶掉）或栈溢出。
///
/// 自定义 `EasySplitConfig.sameRoute` 时可以直接复用它比较参数：
/// ```dart
/// EasySplit.config.sameRoute = (a, b) =>
///     a.name == '/detail' && easySplitArgumentsEqual(a.arguments, b.arguments);
/// ```
bool easySplitSameRoute(RouteSettings a, RouteSettings b) =>
    a.name == b.name && easySplitArgumentsEqual(a.arguments, b.arguments);

/// 按内容比较两个路由参数（只对 `Map` / `List` 递归，其余用 `==`）
///
/// 预算与自引用保护见 [easySplitSameRoute]。
bool easySplitArgumentsEqual(Object? a, Object? b) =>
    _argumentsEqual(a, b, 0, _Budget(_maxArgumentNodes));

bool _argumentsEqual(Object? a, Object? b, int depth, _Budget budget) {
  if (identical(a, b)) return true;
  if (!budget.spend()) return false;
  if (a is Map && b is Map) {
    if (depth >= _maxArgumentDepth) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_argumentsEqual(a[key], b[key], depth + 1, budget)) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (depth >= _maxArgumentDepth) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_argumentsEqual(a[i], b[i], depth + 1, budget)) return false;
    }
    return true;
  }
  return a == b;
}

/// 节点预算：每次比较消耗一个，耗尽即失败（fail-closed）
class _Budget {
  _Budget(this._remaining);

  int _remaining;

  bool spend() {
    if (_remaining <= 0) return false;
    _remaining--;
    return true;
  }
}
