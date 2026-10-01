import 'package:equatable/equatable.dart';

/// What the customer is consenting to. One record per purpose so each can be
/// asked for (and later withdrawn) independently, as POPIA requires.
enum ConsentPurpose {
  /// One-off use of the device location for the coverage check (device-only).
  locationCapture,

  /// Processing of face/ID data for RICA identity verification (device-only).
  ricaCapture,

  /// Terms of Service acceptance, held by the server (`/v1/me/consents`).
  terms,

  /// Privacy notice acknowledgement, held by the server.
  privacy,

  /// Marketing by SMS, held by the server.
  marketingSms,
}

extension ConsentPurposeApi on ConsentPurpose {
  /// The platform's purpose name, or null for consents that only exist on
  /// this device (ruling R-M4-11).
  String? get apiName => switch (this) {
        ConsentPurpose.terms => 'terms',
        ConsentPurpose.privacy => 'privacy',
        ConsentPurpose.marketingSms => 'marketing_sms',
        ConsentPurpose.locationCapture || ConsentPurpose.ricaCapture => null,
      };
}

/// Proof that a customer agreed: which purpose, to which version of the
/// notice, and when (UTC). [synced] flips once the backend has a copy.
class ConsentRecord extends Equatable {
  const ConsentRecord({
    required this.purpose,
    required this.policyVersion,
    required this.grantedAt,
    this.synced = false,
  });

  final ConsentPurpose purpose;
  final String policyVersion;
  final DateTime grantedAt;
  final bool synced;

  ConsentRecord copyWith({bool? synced}) => ConsentRecord(
        purpose: purpose,
        policyVersion: policyVersion,
        grantedAt: grantedAt,
        synced: synced ?? this.synced,
      );

  Map<String, dynamic> toJson() => {
        'purpose': purpose.name,
        'policyVersion': policyVersion,
        'grantedAt': grantedAt.toUtc().toIso8601String(),
        'synced': synced,
      };

  static ConsentRecord? fromJson(Map<String, dynamic> json) {
    final purpose = ConsentPurpose.values.where((p) => p.name == json['purpose']).firstOrNull;
    final grantedAt = DateTime.tryParse(json['grantedAt'] as String? ?? '');
    final version = json['policyVersion'] as String?;
    if (purpose == null || grantedAt == null || version == null) return null;
    return ConsentRecord(
      purpose: purpose,
      policyVersion: version,
      grantedAt: grantedAt.toUtc(),
      synced: json['synced'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [purpose, policyVersion, grantedAt, synced];
}
