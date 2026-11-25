import 'package:equatable/equatable.dart';

enum ContactKind { phone, email }

enum TechnologyInterest { any, fiveG, lte }

/// What the customer asks for on the coverage waiting list. Everything here is
/// personal data (contact, address, coordinates): [toString] prints none of it,
/// and the request is only ever sent to the customer's own provider.
class NotifyRequest extends Equatable {
  const NotifyRequest({
    required this.contactType,
    required this.contactValue,
    required this.addressText,
    required this.lat,
    required this.lon,
    required this.technologyInterest,
    required this.waitlistConsentVersion,
    required this.arrivalConsentGranted,
    required this.arrivalConsentVersion,
  });

  final ContactKind contactType;
  final String contactValue;
  final String addressText;
  final double lat;
  final double lon;
  final TechnologyInterest technologyInterest;

  /// `waitlist_consent_version` from `GET /v1/coverage/meta`: the text the customer ticked.
  final String waitlistConsentVersion;

  /// The separate "tell me when coverage arrives or improves" consent. Its own
  /// tick box: ticking one never ticks the other.
  final bool arrivalConsentGranted;
  final String arrivalConsentVersion;

  @override
  List<Object?> get props => [
    contactType,
    contactValue,
    addressText,
    lat,
    lon,
    technologyInterest,
    waitlistConsentVersion,
    arrivalConsentGranted,
    arrivalConsentVersion,
  ];

  @override
  String toString() => 'NotifyRequest(${contactType.name}, arrival: $arrivalConsentGranted)';
}

/// Start leaving the list: the platform sends a one-time link to this contact.
class WithdrawalRequest extends Equatable {
  const WithdrawalRequest({required this.contactType, required this.contactValue});

  final ContactKind contactType;
  final String contactValue;

  @override
  List<Object?> get props => [contactType, contactValue];

  @override
  String toString() => 'WithdrawalRequest(${contactType.name})';
}
