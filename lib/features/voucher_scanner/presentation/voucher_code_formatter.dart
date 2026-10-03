import 'package:flutter/services.dart';

/// Formats a voucher code as it is typed: upper case, grouped in fours with
/// dashes (`ABCD-2345-EFGH`). Purely cosmetic: [VoucherCode.tryParse] strips
/// the dashes again, exactly as the server does.
///
/// Characters the server refuses (0, 1, I, L, O, U) are kept, not dropped or
/// guessed, so the customer sees what they typed and the result can point at
/// it. Anything that is not letters, digits, spaces and dashes (a pasted
/// /redeem link) is left untouched for the parser.
class VoucherCodeFormatter extends TextInputFormatter {
  const VoucherCodeFormatter();

  static final _plain = RegExp(r'^[A-Za-z0-9\s-]*$');
  static final _separator = RegExp(r'[\s-]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!_plain.hasMatch(newValue.text)) return newValue;
    var symbols = _strip(newValue.text);
    var cursor = _symbolsBefore(newValue.text, newValue.selection.extentOffset);
    // Backspace over a dash removes only the dash, which the grouping would
    // put straight back; delete the symbol before it instead.
    if (newValue.text.length < oldValue.text.length &&
        symbols == _strip(oldValue.text) &&
        cursor > 0) {
      symbols = symbols.substring(0, cursor - 1) + symbols.substring(cursor);
      cursor -= 1;
    }
    final grouped = StringBuffer();
    var offset = 0;
    for (var i = 0; i < symbols.length; i++) {
      if (i > 0 && i % 4 == 0) grouped.write('-');
      grouped.write(symbols[i]);
      if (i < cursor) offset = grouped.length;
    }
    if (cursor == 0) offset = 0;
    return TextEditingValue(
      text: grouped.toString(),
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  static String _strip(String text) =>
      text.replaceAll(_separator, '').toUpperCase();

  static int _symbolsBefore(String text, int offset) {
    final end = offset < 0 || offset > text.length ? text.length : offset;
    return _strip(text.substring(0, end)).length;
  }
}
