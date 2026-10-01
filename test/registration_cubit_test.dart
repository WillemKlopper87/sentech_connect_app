import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/registration_details.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/local_registration_repository.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/registration_cubit.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/local_consent_repository.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';

/// Records the order of the writes.
class _Journal {
  final events = <String>[];
}

class _JournalRegistrations extends LocalRegistrationRepository {
  _JournalRegistrations(super.store, this.journal);

  final _Journal journal;

  @override
  Future<Either<Failure, Unit>> save(RegistrationDetails details) {
    journal.events.add('profile');
    return super.save(details);
  }
}

class _JournalConsents extends LocalConsentRepository {
  _JournalConsents(super.store, this.journal);

  final _Journal journal;
  ConsentPurpose? failOn;

  @override
  Future<Either<Failure, ConsentRecord>> grant(ConsentPurpose purpose) {
    journal.events.add(purpose.name);
    if (purpose == failOn) return Future.value(const Left(NetworkFailure()));
    return super.grant(purpose);
  }
}

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

  group('consents are recorded BEFORE the profile', () {
    late _Journal journal;
    late _JournalConsents journalConsents;
    late RegistrationCubit ordered;

    setUp(() {
      journal = _Journal();
      journalConsents = _JournalConsents(InMemorySecureStore(), journal);
      ordered = RegistrationCubit(
        _JournalRegistrations(InMemorySecureStore(), journal),
        consents: journalConsents,
        initialMobile: '+27821234567',
      )
        ..setFullName('Thandi Mokoena')
        ..setEmail('thandi@example.test')
        ..setAddress('12 Main Road, Soweto')
        ..setAcceptedTerms(true)
        ..setMarketingSms(true);
    });

    tearDown(() => ordered.close());

    test('terms, privacy and marketing come first, the profile last', () async {
      await ordered.submit();
      expect(journal.events, ['terms', 'privacy', 'marketingSms', 'profile']);
      expect(ordered.state.submitStatus, SubmitStatus.submitted);
    });

    test('when a consent cannot be recorded the profile is NOT saved (no named customer without terms)', () async {
      journalConsents.failOn = ConsentPurpose.terms;
      await ordered.submit();
      expect(journal.events, ['terms'], reason: 'no profile write');
      expect(ordered.state.submitStatus, SubmitStatus.failed);
    });

    test('a failure on the optional marketing consent also stops before the profile; a retry succeeds', () async {
      journalConsents.failOn = ConsentPurpose.marketingSms;
      await ordered.submit();
      expect(journal.events.contains('profile'), isFalse);
      expect(ordered.state.submitStatus, SubmitStatus.failed);

      journalConsents.failOn = null;
      await ordered.submit();
      expect(ordered.state.submitStatus, SubmitStatus.submitted);
      expect(journal.events.last, 'profile');
    });
  });
}
