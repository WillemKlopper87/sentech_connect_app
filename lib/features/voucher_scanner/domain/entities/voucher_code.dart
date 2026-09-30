import 'package:equatable/equatable.dart';

/// A syntactically valid Sentech voucher code (`SEN-XXXX-XXXX`, letters and
/// digits). Being a valid [VoucherCode] says nothing about whether the
/// voucher exists or is unused — only the server can decide that.
///
/// Raw scanner/typed input is parsed here and never shown back to the user;
/// the UI only ever displays [masked].
class VoucherCode extends Equatable {
  const VoucherCode._(this.value);

  static final _pattern = RegExp(r'^SEN-[A-Z0-9]{4}-[A-Z0-9]{4}$');

  /// Normalised (trimmed, upper-case) code. Send this to the server; do not
  /// render it.
  final String value;

  /// Returns null when [raw] is not a well-formed voucher code.
  static VoucherCode? tryParse(String? raw) {
    if (raw == null) return null;
    // Reject oversized payloads (e.g. a QR carrying a long URL) before any
    // normalisation work.
    if (raw.length > 64) return null;
    final normalised = raw.trim().toUpperCase();
    if (!_pattern.hasMatch(normalised)) return null;
    return VoucherCode._(normalised);
  }

  /// Safe-to-display form, e.g. `SEN-••••-••LM`.
  String get masked => 'SEN-••••-••${value.substring(value.length - 2)}';

  @override
  List<Object?> get props => [value];
}
