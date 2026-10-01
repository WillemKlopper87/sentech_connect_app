/// Money is integer cents end to end (platform spec §2, review item C1).
/// Rands only exist as text shown to a person; never parse this back.
String formatRands(int cents, {bool wholeRands = false}) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final rands = abs ~/ 100;
  final remainder = abs % 100;
  if (wholeRands && remainder == 0) return '${sign}R$rands';
  return '${sign}R$rands.${remainder.toString().padLeft(2, '0')}';
}
