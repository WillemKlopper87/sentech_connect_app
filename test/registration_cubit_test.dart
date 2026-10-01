import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/local_registration_repository.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/registration_cubit.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/local_consent_repository.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';

void main() {
  late LocalConsentRepository consents;
  late RegistrationCubit cubit;

  setUp(() {
    consents = LocalConsentRepository(InMemorySecureStore());
    cubit = RegistrationCubit(
      LocalRegistrationRepository(InMemorySecureStore()),
      consents: consents,
      initialMobile: '+27821234567',
    )
      ..setFullName('Thandi Mokoena')
      ..setEmail('thandi@example.test')
      ..setAddress('12 Main Road, Soweto');
  });

  tearDown(() => cubit.close());

  test('the verified mobile number is prefilled', () {
    expect(cubit.state.mobileNumber, '+27821234567');
  });

  test('cannot submit before accepting the terms', () async {
    await cubit.submit();
    expect(cubit.state.submitStatus, SubmitStatus.idle);
  });

  test('submitting records terms and privacy consent, and SMS marketing only when chosen', () async {
    cubit
      ..setAcceptedTerms(true)
      ..setMarketingSms(true);
    await cubit.submit();
    expect(cubit.state.submitStatus, SubmitStatus.submitted);
    for (final purpose in [ConsentPurpose.terms, ConsentPurpose.privacy, ConsentPurpose.marketingSms]) {
      expect((await consents.currentConsent(purpose)).getOrElse((_) => null), isNotNull, reason: '$purpose');
    }
  });
}
