import 'package:equatable/equatable.dart';

/// The changes of one `PATCH /v1/me/subscriber`. Only the fields that are set
/// are sent; `clearEmail` / `clearPhone` send an explicit `null` (the platform
/// merges the patch into the stored profile and then needs a phone or an
/// email to remain).
class SubscriberProfilePatch extends Equatable {
  const SubscriberProfilePatch({
    this.displayName,
    this.email,
    this.phoneE164,
    this.language,
    this.clearEmail = false,
    this.clearPhone = false,
  });

  final String? displayName;
  final String? email;
  final String? phoneE164;
  final String? language;
  final bool clearEmail;
  final bool clearPhone;

  bool get isEmpty =>
      displayName == null && email == null && phoneE164 == null && language == null && !clearEmail && !clearPhone;

  /// The `AccountProfilePatchIn` body.
  Map<String, Object?> toBody() => {
    'display_name': ?displayName,
    if (clearEmail) 'email': null else 'email': ?email,
    if (clearPhone) 'phone_e164': null else 'phone_e164': ?phoneE164,
    'language': ?language,
  };

  // Personal data: never in logs.
  @override
  String toString() => 'SubscriberProfilePatch(${toBody().keys.join(', ')})';

  @override
  List<Object?> get props => [displayName, email, phoneE164, language, clearEmail, clearPhone];
}

/// The sign-in profile (`GET /v1/me/profile`), which the platform copies when
/// a customer without an account signs up. The phone is the sign-in identity
/// and is read only.
class LoginContact extends Equatable {
  const LoginContact({required this.phoneE164, this.displayName, this.email});

  final String phoneE164;
  final String? displayName;
  final String? email;

  @override
  String toString() => 'LoginContact()';

  @override
  List<Object?> get props => [phoneE164, displayName, email];
}
