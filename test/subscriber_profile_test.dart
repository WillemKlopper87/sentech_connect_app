import 'dart:async';

import 'package:dio/dio.dart' show DioExceptionType;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_subscriber_profile_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_account.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_profile_edit.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_profile_repository.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/signup_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/subscriber_profile_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/pages/subscriber_profile_page.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/plans/signup_page.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/subscriber_entries.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';
import 'helpers/pump_themed.dart';
import 'signup_cubit_test.dart' show FakePlans, SignupRepo, hotspot;
import 'subscriber_services_cubit_test.dart' show FakeSubscriberRepository;

const _path = '/v1/me/subscriber';

Failure? _failure<T>(Either<Failure, T> e) => e.match((f) => f, (_) => null);

SubscriberAccount _account({String name = 'Thandi Mokoena', String? email = 'thandi@example.test', String? phone = '+27821234567', String language = 'zu'}) =>
    SubscriberAccount(
      id: 'a1',
      accountNo: 'AC-000101',
      kind: SubscriberAccountKind.individual,
      status: SubscriberAccountStatus.active,
      serviceCounts: const ServiceCounts(active: 1),
      profile: SubscriberProfile(displayName: name, email: email, phoneE164: phone, language: language),
    );

class _Accounts extends FakeSubscriberRepository {
  _Accounts(this.account, {super.failure});
  SubscriberAccount? account;

  @override
  Future<Either<Failure, SubscriberAccount?>> getAccount() async => failure != null ? Left(failure!) : Right(account);
}

class _Profiles implements SubscriberProfileRepository {
  final patches = <SubscriberProfilePatch>[];
  final keys = <String>[];
  final loginPatches = <(String?, String?, bool)>[];
  final replies = <Either<Failure, SubscriberAccount>>[];
  final loginReplies = <Either<Failure, LoginContact>>[];
  LoginContact login = const LoginContact(phoneE164: '+27821234567', displayName: 'Thandi', email: 'bad email');
  Completer<void>? gate;

  @override
  Future<Either<Failure, SubscriberAccount>> patchProfile(SubscriberProfilePatch patch, {required String idempotencyKey}) async {
    patches.add(patch);
    keys.add(idempotencyKey);
    await gate?.future;
    if (replies.isNotEmpty) return replies.removeAt(0);
    final p = _account().profile!;
    return Right(
      _account(
        name: patch.displayName ?? p.displayName,
        email: patch.clearEmail ? null : (patch.email ?? p.email),
        phone: patch.clearPhone ? null : (patch.phoneE164 ?? p.phoneE164),
        language: patch.language ?? p.language,
      ),
    );
  }

  @override
  Future<Either<Failure, LoginContact>> getLoginContact() async => Right(login);

  @override
  Future<Either<Failure, LoginContact>> patchLoginContact({String? displayName, String? email, bool clearEmail = false}) async {
    loginPatches.add((displayName, email, clearEmail));
    if (loginReplies.isNotEmpty) return loginReplies.removeAt(0);
    return Right(LoginContact(phoneE164: login.phoneE164, displayName: displayName ?? login.displayName, email: clearEmail ? null : (email ?? login.email)));
  }
}

Future<SubscriberProfileCubit> _cubit(_Profiles profiles, SubscriberAccount? account, {Failure? failure}) async {
  var n = 0;
  final cubit = SubscriberProfileCubit(profiles, _Accounts(account, failure: failure), newKey: () => 'key-${++n}');
  await cubit.stream.firstWhere((s) => s.phase != ProfilePhase.loading);
  return cubit;
}

void main() {
  group('HttpSubscriberProfileRepository', () {
    late ApiHarness h;
    late HttpSubscriberProfileRepository repo;

    setUp(() async {
      h = ApiHarness();
      await h.signIn();
      repo = HttpSubscriberProfileRepository(h.api);
    });

    test('sends only the set fields with the Idempotency-Key and reads the account', () async {
      h.adapter.on('PATCH', _path, (_) => FakeReply(200, fixture('subscriber_profile_patched.json')));
      final account = (await repo.patchProfile(const SubscriberProfilePatch(language: 'af'), idempotencyKey: 'k-1')).getOrElse((f) => throw f);
      expect(account.profile!.language, 'af');
      final request = h.adapter.requests.single;
      expect(request.data, {'language': 'af'});
      expect(request.headers['Idempotency-Key'], 'k-1');
      expect(request.headers['Authorization'], 'Bearer access-1');
    });

    test('clearing the email sends an explicit null; a set field replaces it', () async {
      h.adapter.on('PATCH', _path, (_) => FakeReply(200, fixture('subscriber_profile_patched.json')));
      await repo.patchProfile(const SubscriberProfilePatch(clearEmail: true, phoneE164: '+27829998888'), idempotencyKey: 'k-2');
      expect(h.adapter.requests.single.data, {'email': null, 'phone_e164': '+27829998888'});
    });

    test('a replay answers the same account', () async {
      h.adapter.on('PATCH', _path, (_) => FakeReply(200, fixture('subscriber_profile_patched.json'), const {'idempotent-replayed': ['true']}));
      final first = (await repo.patchProfile(const SubscriberProfilePatch(language: 'af'), idempotencyKey: 'k-3')).getOrElse((f) => throw f);
      final again = (await repo.patchProfile(const SubscriberProfilePatch(language: 'af'), idempotencyKey: 'k-3')).getOrElse((f) => throw f);
      expect(again, first);
    });

    test('every refusal the platform can send maps to its typed failure', () async {
      final cases = <(int, String, Matcher)>[
        (404, 'subscriber_not_found', isA<SubscriberNotFoundFailure>()),
        (409, 'account_closed', isA<ServiceStateFailure>()),
        (409, 'profile_unavailable', isA<AccountProblemFailure>()),
        (422, 'profile_invalid', isA<ProfileInvalidFailure>()),
        (403, 'module_not_enabled', isA<ModuleDisabledFailure>()),
        (409, 'feature_disabled', isA<FeatureDisabledFailure>()),
        (429, 'rate_limited', isA<RateLimitedFailure>()),
      ];
      for (final (status, code, matcher) in cases) {
        final fresh = ApiHarness();
        await fresh.signIn();
        fresh.adapter.on('PATCH', _path, (_) => FakeReply.problem(status, code));
        final result = await HttpSubscriberProfileRepository(fresh.api).patchProfile(const SubscriberProfilePatch(language: 'af'), idempotencyKey: 'k');
        expect(_failure(result), matcher, reason: code);
      }
    });

    test('a validation_error names the rejected fields', () async {
      h.adapter.on(
        'PATCH',
        _path,
        (_) => const FakeReply(422, {
          'type': 'about:blank',
          'title': 'Unprocessable Content',
          'status': 422,
          'code': 'validation_error',
          'errors': [
            {'loc': ['body', 'email'], 'msg': 'x', 'type': 'string_pattern_mismatch'},
            {'loc': ['body', 'phone_e164'], 'msg': 'x', 'type': 'value_error'},
          ],
        }),
      );
      final f = _failure(await repo.patchProfile(const SubscriberProfilePatch(email: 'x'), idempotencyKey: 'k'));
      expect(f, isA<ValidationFailure>());
      expect((f! as ValidationFailure).fields, ['email', 'phone_e164']);
    });

    test('offline is a NetworkFailure', () async {
      h.adapter.on('PATCH', _path, (_) => const FakeReply.error(DioExceptionType.connectionError));
      expect(_failure(await repo.patchProfile(const SubscriberProfilePatch(language: 'af'), idempotencyKey: 'k')), isA<NetworkFailure>());
    });

    test('the sign-in profile: read, and edit sends name and email only', () async {
      h.adapter
        ..on('GET', '/v1/me/profile', (_) => FakeReply(200, fixture('profile_complete.json')))
        ..on('PATCH', '/v1/me/profile', (_) => FakeReply(200, fixture('profile_complete.json')));
      final contact = (await repo.getLoginContact()).getOrElse((f) => throw f);
      expect(contact.phoneE164, '+27821234567');
      await repo.patchLoginContact(displayName: 'Thandi', clearEmail: true);
      expect(h.adapter.requests.last.data, {'display_name': 'Thandi', 'email': null});
    });
  });

  group('SubscriberProfileCubit', () {
    test('account mode: loads the account, nothing changed means nothing to send', () async {
      final cubit = await _cubit(_Profiles(), _account());
      expect(cubit.state.mode, ProfileMode.account);
      expect(cubit.state.accountNo, 'AC-000101');
      expect(cubit.state.name, 'Thandi Mokoena');
      expect(cubit.hasChanges, isFalse);
      await cubit.close();
    });

    test('only the changed fields are sent, the phone as E.164, the same draft reuses its key', () async {
      final profiles = _Profiles();
      final cubit = await _cubit(profiles, _account());
      cubit
        ..setName('  Thandi M  ')
        ..setPhone('082 999 8888');
      await cubit.save();
      expect(profiles.patches.single, const SubscriberProfilePatch(displayName: 'Thandi M', phoneE164: '+27829998888'));
      expect(cubit.state.phase, ProfilePhase.saved);
      expect(cubit.state.phone, '+27829998888');
      expect(cubit.hasChanges, isFalse);
      await cubit.close();
    });

    test('a retry of the same draft reuses the key; an edit starts a new one', () async {
      final profiles = _Profiles()..replies.add(const Left(NetworkFailure()));
      final cubit = await _cubit(profiles, _account());
      cubit.setLanguage('af');
      await cubit.save();
      expect(cubit.state.failure, isA<NetworkFailure>());
      expect(cubit.state.phase, ProfilePhase.ready);
      await cubit.save();
      cubit.setLanguage('en');
      await cubit.save();
      expect(profiles.keys, ['key-1', 'key-1', 'key-2']);
      await cubit.close();
    });

    test('clearing the email sends clearEmail when a phone remains', () async {
      final profiles = _Profiles();
      final cubit = await _cubit(profiles, _account());
      cubit.setEmail('');
      await cubit.save();
      expect(profiles.patches.single, const SubscriberProfilePatch(clearEmail: true));
      await cubit.close();
    });

    test('client validation mirrors the schema and blocks the call', () async {
      final profiles = _Profiles();
      final cubit = await _cubit(profiles, _account());
      cubit.setName('   ');
      expect(cubit.issues, {ProfileField.name});
      cubit
        ..setName('x' * 121)
        ..setEmail('not an email')
        ..setPhone('0123456789');
      expect(cubit.issues, {ProfileField.name, ProfileField.email, ProfileField.phone});
      cubit
        ..setName('Thandi')
        ..setEmail('')
        ..setPhone('');
      expect(cubit.issues, {ProfileField.contact});
      await cubit.save();
      expect(cubit.state.showErrors, isTrue);
      expect(profiles.patches, isEmpty);
      await cubit.close();
    });

    test('profile_invalid and the account refusals keep the draft', () async {
      final profiles = _Profiles()
        ..replies.addAll([const Left(ProfileInvalidFailure()), const Left(ServiceStateFailure('account_closed'))]);
      final cubit = await _cubit(profiles, _account());
      cubit.setName('Other');
      await cubit.save();
      expect(cubit.state.failure, isA<ProfileInvalidFailure>());
      expect(cubit.state.name, 'Other');
      await cubit.save();
      expect(cubit.state.failure, isA<ServiceStateFailure>());
      expect(cubit.state.phase, ProfilePhase.ready);
      await cubit.close();
    });

    test('a double tap while saving sends one request', () async {
      final profiles = _Profiles()..gate = Completer<void>();
      final cubit = await _cubit(profiles, _account());
      cubit.setLanguage('af');
      final first = cubit.save();
      await cubit.save();
      profiles.gate!.complete();
      await first;
      expect(profiles.patches, hasLength(1));
      await cubit.close();
    });

    test('login mode (no account yet): edits the sign-in profile, name up to 80, phone is read only', () async {
      final profiles = _Profiles();
      final cubit = await _cubit(profiles, null);
      expect(cubit.state.mode, ProfileMode.login);
      expect(cubit.state.accountNo, isNull);
      cubit.setName('x' * 81);
      expect(cubit.issues, contains(ProfileField.name));
      cubit
        ..setName('Thandi')
        ..setEmail('thandi@example.test');
      expect(cubit.issues, isEmpty);
      await cubit.save();
      expect(profiles.loginPatches.single, (null, 'thandi@example.test', false));
      expect(profiles.patches, isEmpty);
      expect(cubit.state.phase, ProfilePhase.saved);
      await cubit.close();
    });

    test('a failed read is a retryable load failure', () async {
      final cubit = await _cubit(_Profiles(), null, failure: const NetworkFailure());
      expect(cubit.state.phase, ProfilePhase.loadFailed);
      await cubit.close();
    });
  });

  group('SubscriberProfilePage', () {
    Future<_Profiles> pumpPage(WidgetTester tester, {SubscriberAccount? account, VoidCallback? onDone}) async {
      final profiles = _Profiles();
      final cubit = SubscriberProfileCubit(profiles, _Accounts(account), newKey: () => 'k');
      addTearDown(cubit.close);
      await pumpThemed(
        tester,
        BlocProvider.value(value: cubit, child: SubscriberProfilePage(onDone: onDone ?? () {})),
        size: const Size(390, 1200),
      );
      await tester.pumpAndSettle();
      return profiles;
    }

    testWidgets('shows the account number and the fields; Save waits for a change', (tester) async {
      await pumpPage(tester, account: _account());
      expect(find.text('Account number AC-000101'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Thandi Mokoena'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('profile-save'))).onPressed, isNull);
      await tester.enterText(find.byKey(const Key('profile-name')), 'Thandi M');
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const Key('profile-save'))).onPressed, isNotNull);
    });

    testWidgets('field errors appear under the fields after Save is pressed', (tester) async {
      final profiles = await pumpPage(tester, account: _account());
      await tester.enterText(find.byKey(const Key('profile-email')), 'nope');
      await tester.pump();
      await tester.tap(find.byKey(const Key('profile-save')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(profiles.patches, isEmpty);
    });

    testWidgets('a server validation_error marks the named field; saving closes the page', (tester) async {
      var done = 0;
      final profiles = await pumpPage(tester, account: _account(), onDone: () => done++);
      profiles.replies.add(const Left(ValidationFailure('Unprocessable Content', 'validation_error', false, ['email'])));
      await tester.enterText(find.byKey(const Key('profile-email')), 'a@b.co');
      await tester.pump();
      await tester.tap(find.byKey(const Key('profile-save')));
      await tester.pumpAndSettle();
      expect(find.text('Check this field.'), findsOneWidget);
      expect(find.text('Some of your contact details are not valid. Check them and try again.'), findsOneWidget);
      expect(done, 0);
      await tester.tap(find.byKey(const Key('profile-save')));
      await tester.pumpAndSettle();
      expect(done, 1);
    });

    testWidgets('no account: the sign-in note, no account number, the phone is not editable', (tester) async {
      await pumpPage(tester);
      expect(find.byKey(const Key('profile-login-note')), findsOneWidget);
      expect(find.byKey(const Key('profile-account-no')), findsNothing);
      expect(tester.widget<TextField>(find.byKey(const Key('profile-phone'))).enabled, isFalse);
      expect(find.byKey(const Key('profile-language')), findsNothing);
    });
  });

  group('Signup failure subscriber_profile_invalid', () {
    testWidgets('offers "Update your contact details"; coming back keeps the draft and clears the message', (tester) async {
      final repo = SignupRepo()..replies.add(const Left(SubscriberProfileInvalidFailure()));
      final cubit = SignupCubit(FakePlans([hotspot]), repo, 'p-hot', termsVersion: () => '2026-09-30');
      addTearDown(cubit.close);
      var opened = 0;
      await pumpThemed(
        tester,
        BlocProvider.value(
          value: cubit,
          child: SignupPage(
            onPayNow: (_) {},
            onPayLater: (_) {},
            onStartIdCheck: null,
            onBackToPlans: () {},
            onUpdateContactDetails: () async => opened++,
          ),
        ),
        size: const Size(390, 1800),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('signup-update-contact')), findsNothing);
      await tester.tap(find.byKey(const Key('signup-terms')));
      await tester.tap(find.byKey(const Key('signup-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Update your contact details before signing up.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('signup-update-contact')));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.byKey(const Key('signup-failure')), findsNothing);
      expect(cubit.state.acceptTerms, isTrue);
      expect(cubit.state.phase, SignupPhase.ready);
      // Submitting again works with the same draft.
      await tester.tap(find.byKey(const Key('signup-submit')));
      await tester.pumpAndSettle();
      expect(repo.calls, hasLength(2));
      expect(find.byKey(const Key('signup-done')), findsOneWidget);
    });

    testWidgets('without the screen registered the button is hidden', (tester) async {
      final repo = SignupRepo()..replies.add(const Left(SubscriberProfileInvalidFailure()));
      final cubit = SignupCubit(FakePlans([hotspot]), repo, 'p-hot', termsVersion: () => '2026-09-30');
      addTearDown(cubit.close);
      await pumpThemed(
        tester,
        BlocProvider.value(
          value: cubit,
          child: SignupPage(onPayNow: (_) {}, onPayLater: (_) {}, onStartIdCheck: null, onBackToPlans: () {}),
        ),
        size: const Size(390, 1800),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('signup-terms')));
      await tester.tap(find.byKey(const Key('signup-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('signup-update-contact')), findsNothing);
    });
  });

  test('the contact details screen is registered in the Home internet section', () {
    expect(subscriberEntryRegistered(AppRoutes.subscriberProfile), isTrue);
  });
}
