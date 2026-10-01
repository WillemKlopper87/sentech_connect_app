import 'dart:math';

/// True when [current] >= [minimum], comparing dotted numeric versions
/// ("1.2.10" > "1.2.9"). Build (+n) and pre-release (-x) suffixes are
/// ignored. An unparseable [minimum] never blocks the app.
bool isVersionAtLeast(String current, String minimum) {
  final min = _parse(minimum);
  if (min == null) return true;
  final cur = _parse(current);
  if (cur == null) return false;
  for (var i = 0; i < max(cur.length, min.length); i++) {
    final a = i < cur.length ? cur[i] : 0;
    final b = i < min.length ? min[i] : 0;
    if (a != b) return a > b;
  }
  return true;
}

List<int>? _parse(String version) {
  final core = version.split('+').first.split('-').first.trim();
  if (core.isEmpty) return null;
  final parts = <int>[];
  for (final piece in core.split('.')) {
    final n = int.tryParse(piece);
    if (n == null || n < 0) return null;
    parts.add(n);
  }
  return parts;
}
