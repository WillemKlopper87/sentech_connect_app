import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/l10n/app_localizations_af.dart';
import 'package:sentech_connect_app/l10n/app_localizations_en.dart';
import 'package:sentech_connect_app/l10n/app_localizations_zu.dart';
import 'package:sentech_connect_app/l10n/failure_copy.dart';

void main() {
  final typed = <Failure>[
    const BindingRequiredFailure(),
    const HumanVerificationFailedFailure(),
    const HumanVerificationUnavailableFailure(),
    const ReauthRequiredFailure(),
    const SmsUnavailableFailure(),
    const ConsentVersionOutdatedFailure(),
    const SubscriberNotFoundFailure(),
    const ActiveServiceExistsFailure(),
    const FeatureDisabledFailure(),
    const OrderNotCancellableFailure(),
    const OrderCancelledFailure(),
    const SupportUnavailableFailure(),
    const SupportContactNotConfiguredFailure(),
    const InvalidMessageFailure(),
    const InvalidContactFailure(),
    const InvoiceNotPayableFailure(),
    const CustomerLinkRequiredFailure(),
    const SubscriberProfileInvalidFailure(),
    const PlanUnavailableFailure(),
    const ServiceStateFailure(),
    const AccountProblemFailure(),
    const NoActiveEntitlementFailure(),
    const MacInvalidFailure(),
    const NasUnavailableFailure(),
    const LoginUrlInvalidFailure(),
    const ControllerNotSupportedFailure(),
    const KycInvalidIdFailure(),
    const KycInvalidAddressFailure(),
    const KycDocumentRejectedFailure(),
    const KycUploadFailedFailure(),
    const KycRequiredFailure(),
  ];

  for (final l10n in [AppLocalizationsEn(), AppLocalizationsAf(), AppLocalizationsZu()]) {
    test('every typed refusal has customer copy in ${l10n.localeName}', () {
      for (final f in typed) {
        final text = typedFailureText(l10n, f);
        expect(text, isNotNull, reason: '$f');
        expect(text, isNotEmpty);
        // The message-only path (cubits that keep only failure.message) agrees.
        expect(localizedFailureText(l10n, f.message), text, reason: '$f');
      }
    });
  }

  test('a refusal that is not typed has no typed copy', () {
    final l10n = AppLocalizationsEn();
    expect(typedFailureText(l10n, const NetworkFailure()), isNull);
    expect(typedFailureText(l10n, const ValidationFailure('x', 'other')), isNull);
    expect(typedFailureText(l10n, null), isNull);
  });

  test('the security check outage gives a retry hint from Retry-After', () {
    final l10n = AppLocalizationsEn();
    expect(
      typedFailureText(l10n, const HumanVerificationUnavailableFailure(Duration(seconds: 45))),
      contains('45 seconds'),
    );
    expect(
      typedFailureText(l10n, const HumanVerificationUnavailableFailure(Duration(seconds: 90))),
      contains('90 seconds'),
    );
    expect(
      typedFailureText(l10n, const HumanVerificationUnavailableFailure(Duration(seconds: 121))),
      contains('3 minutes'),
    );
    expect(
      typedFailureText(l10n, const HumanVerificationUnavailableFailure()),
      isNot(contains('seconds')),
    );
  });

  test('a wrong delete code reads "That code did not work"', () {
    expect(typedFailureText(AppLocalizationsEn(), const ReauthRequiredFailure()), startsWith('That code did not work'));
  });
}
