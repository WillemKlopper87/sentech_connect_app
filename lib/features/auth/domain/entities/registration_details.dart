import 'package:equatable/equatable.dart';

enum ContactMethod { email, sms, whatsapp }

extension ContactMethodLabel on ContactMethod {
  String get label => switch (this) {
        ContactMethod.email => 'Email',
        ContactMethod.sms => 'SMS',
        ContactMethod.whatsapp => 'WhatsApp',
      };
}

class RegistrationDetails extends Equatable {
  const RegistrationDetails({
    required this.fullName,
    required this.email,
    required this.mobileNumber,
    required this.address,
    this.latitude,
    this.longitude,
    this.marketingEmail = false,
    this.marketingSms = false,
    this.marketingPush = false,
    this.preferredContactMethod = ContactMethod.email,
  });

  final String fullName;
  final String email;
  final String mobileNumber;
  final String address;
  final double? latitude;
  final double? longitude;
  final bool marketingEmail;
  final bool marketingSms;
  final bool marketingPush;
  final ContactMethod preferredContactMethod;

  bool get hasDeviceLocation => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'email': email,
        'mobileNumber': mobileNumber,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'marketingEmail': marketingEmail,
        'marketingSms': marketingSms,
        'marketingPush': marketingPush,
        'preferredContactMethod': preferredContactMethod.name,
      };

  factory RegistrationDetails.fromJson(Map<String, dynamic> json) {
    return RegistrationDetails(
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      mobileNumber: json['mobileNumber'] as String,
      // Not stored on the device (LocalRegistrationRepository).
      address: json['address'] as String? ?? '',
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      marketingEmail: json['marketingEmail'] as bool? ?? false,
      marketingSms: json['marketingSms'] as bool? ?? false,
      marketingPush: json['marketingPush'] as bool? ?? false,
      preferredContactMethod: ContactMethod.values.firstWhere(
        (m) => m.name == json['preferredContactMethod'],
        orElse: () => ContactMethod.email,
      ),
    );
  }

  @override
  List<Object?> get props => [
        fullName,
        email,
        mobileNumber,
        address,
        latitude,
        longitude,
        marketingEmail,
        marketingSms,
        marketingPush,
        preferredContactMethod,
      ];
}
