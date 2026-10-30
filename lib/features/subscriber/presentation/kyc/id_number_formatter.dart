import 'package:flutter/services.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/kyc/kyc_validators.dart';

/// Keeps only the characters an ID number of [type] can contain, caps the
/// length, and for a company registration number inserts the slashes
/// (`1234/123456/12`) while typing. A passport number is shown upper-case.
/// This shapes input only; validity is `KycValidators.isValidIdNumber`.
class IdNumberFormatter extends TextInputFormatter {
  const IdNumberFormatter(this.type);

  final KycIdType type;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final kept = StringBuffer();
    for (final rune in newValue.text.runes) {
      final char = String.fromCharCode(rune);
      if (KycValidators.isAllowedChar(type, char)) kept.write(char);
    }
    var text = kept.toString();
    if (type == KycIdType.passport) text = text.toUpperCase();
    if (type == KycIdType.companyReg) text = _withSlashes(text);
    final max = KycValidators.maxFieldLength(type);
    if (text.length > max) text = text.substring(0, max);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Digits (slashes the customer typed are ignored) -> `NNNN/NNNNNN/NN`.
  static String _withSlashes(String raw) {
    final digits = raw.replaceAll('/', '');
    final out = StringBuffer();
    for (var i = 0; i < digits.length && i < 12; i++) {
      if (i == 4 || i == 10) out.write('/');
      out.write(digits[i]);
    }
    return out.toString();
  }
}
