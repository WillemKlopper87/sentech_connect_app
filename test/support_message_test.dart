import 'package:dio/dio.dart' show DioExceptionType;
import 'package:fpdart/fpdart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/security/human_check_provider.dart';
import 'package:sentech_connect_app/features/support/data/repositories/http_support_message_repository.dart';
import 'package:sentech_connect_app/features/support/domain/entities/support_message.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_message_repository.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/support_message_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/widgets/support_message_sheet.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'contract/openapi_schema.dart';
import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';
import 'helpers/pump_themed.dart';

const _draft = SupportMessageDraft(
  topic: SupportTopic.payment,
  contactKind: SupportContactKind.email,
  contact: ' thandi@example.co.za ',
  message: '  I paid for a pass but it is not on my account.  ',
  orderRef: 'AB12-CD34',
);

class _Check implements HumanCheckProvider {
  _Check(this.result);
  Object? result; // String, null, or an exception to throw
  int calls = 0;

  @override
  Future<String?> token() async {
    calls++;
    final r = result;
    if (r is Exception) throw r;
    return r as String?;
  }
}

class _FakeRepo implements SupportMessageRepository {
  final keys = <String>[];
  final drafts = <SupportMessageDraft>[];
  final answers = <Either<Failure, SupportReceipt>>[];

  @override
  Future<Either<Failure, SupportReceipt>> send(SupportMessageDraft draft, {required String idempotencyKey}) async {
    keys.add(idempotencyKey);
    drafts.add(draft);
    return answers.isEmpty ? const Right(SupportReceipt('SUP-1')) : answers.removeAt(0);
  }
}

void main() {
  group('HttpSupportMessageRepository', () {
    late ApiHarness h;
    late _Check check;
    late HttpSupportMessageRepository repo;

    setUp(() {
      h = ApiHarness(tenant: 'acme');
      check = _Check('human-token');
      repo = HttpSupportMessageRepository(h.api, tenant: h.tenantContext, humanCheck: check);
      h.adapter.on('POST', '/v1/support/messages', (_) => FakeReply(202, fixture('support_accepted.json')));
    });

    test('POSTs the contract body with the human-check token and the Idempotency-Key, unauthenticated', () async {
      await h.signIn();
      final result = await repo.send(_draft, idempotencyKey: 'app-key-0001');
      expect(result, const Right<Failure, SupportReceipt>(SupportReceipt('SUP-7K3QX2')));
      final sent = h.adapter.requests.single;
      expect(sent.headers['Idempotency-Key'], 'app-key-0001');
      expect(sent.headers.containsKey('Authorization'), isFalse);
      expect(sent.data, {
        'tenant': 'acme',
        'topic': 'payment',
        'reply': {'type': 'email', 'value': 'thandi@example.co.za'},
        'message': 'I paid for a pass but it is not on my account.',
        'order_ref': 'AB12-CD34',
        'turnstile_token': 'human-token',
      });
      // The very body on the wire satisfies the platform's request schema.
      final api = OpenApiSnapshot.load();
      final route = api.path('/v1/support/messages', 'post');
      final schema = Map<String, Object?>.from((((route['requestBody']! as Map)['content']! as Map)['application/json']! as Map)['schema']! as Map);
      expect(api.validate(sent.data, schema), isEmpty);
      expect(api.validate(fixture('support_accepted.json'), api.schema('SupportAcceptedOut')), isEmpty);
    });

    test('a mobile number is sent as E.164 and an empty order reference is left out', () async {
      await repo.send(
        const SupportMessageDraft(topic: SupportTopic.other, contactKind: SupportContactKind.phone, contact: '082 123 4567', message: 'Please call me about my pass.'),
        idempotencyKey: 'app-key-0002',
      );
      final body = h.adapter.requests.single.data as Map;
      expect(body['reply'], {'type': 'phone', 'value': '+27821234567'});
      expect(body.containsKey('order_ref'), isFalse);
    });

    test('no widget (dev stack): the dev constant goes in the required token field', () async {
      check.result = null;
      await repo.send(_draft, idempotencyKey: 'app-key-0003');
      expect((h.adapter.requests.single.data as Map)['turnstile_token'], devTurnstilePass);
    });

    test('the customer closing the human check sends nothing', () async {
      check.result = const HumanCheckCancelled();
      final result = await repo.send(_draft, idempotencyKey: 'app-key-0004');
      expect(result.swap().getOrElse((_) => throw StateError('expected a failure')), isA<HumanCheckCancelledFailure>());
      expect(h.adapter.requests, isEmpty);
    });

    test('a check that cannot run is HumanVerificationUnavailableFailure, nothing sent', () async {
      check.result = const HumanCheckUnavailable();
      final result = await repo.send(_draft, idempotencyKey: 'app-key-0005');
      expect(result.swap().getOrElse((_) => throw StateError('expected a failure')), isA<HumanVerificationUnavailableFailure>());
      expect(h.adapter.requests, isEmpty);
    });

    test('an invalid draft never reaches the network', () async {
      final bad = const SupportMessageDraft(topic: SupportTopic.other, contactKind: SupportContactKind.email, contact: 'nope', message: 'A long enough message.');
      final r = await repo.send(bad, idempotencyKey: 'app-key-0006');
      expect(r.swap().getOrElse((_) => throw StateError('expected a failure')), isA<InvalidContactFailure>());
      expect(h.adapter.requests, isEmpty);
      expect(check.calls, 0, reason: 'no human check for a draft that would be refused anyway');
    });

    final cases = <String, (FakeReply, Matcher)>{
      '409 support_contact_not_configured': (FakeReply.problem(409, 'support_contact_not_configured'), isA<SupportContactNotConfiguredFailure>()),
      '422 invalid_message': (FakeReply.problem(422, 'invalid_message'), isA<InvalidMessageFailure>()),
      '422 invalid_contact': (FakeReply.problem(422, 'invalid_contact'), isA<InvalidContactFailure>()),
      '503 support_unavailable keeps Retry-After': (
        FakeReply.problem(503, 'support_unavailable', headers: {'retry-after': ['120']}),
        isA<SupportUnavailableFailure>().having((f) => f.retryAfter, 'retryAfter', const Duration(seconds: 120)),
      ),
      '503 human_verification_unavailable': (FakeReply.problem(503, 'human_verification_unavailable'), isA<HumanVerificationUnavailableFailure>()),
      '403 human_verification_failed': (FakeReply.problem(403, 'human_verification_failed'), isA<HumanVerificationFailedFailure>()),
      '429 rate_limited': (FakeReply.problem(429, 'rate_limited', headers: {'retry-after': ['30']}), isA<RateLimitedFailure>()),
    };
    for (final MapEntry(key: name, value: (reply, matcher)) in cases.entries) {
      test('typed failure: $name', () async {
        h.adapter.on('POST', '/v1/support/messages', (_) => reply);
        final r = await repo.send(_draft, idempotencyKey: 'app-key-0007');
        expect(r.swap().getOrElse((_) => throw StateError('expected a failure')), matcher);
      });
    }

    test('offline is a NetworkFailure', () async {
      h.adapter.on('POST', '/v1/support/messages', (_) => const FakeReply.error(DioExceptionType.connectionError));
      final r = await repo.send(_draft, idempotencyKey: 'app-key-0008');
      expect(r.swap().getOrElse((_) => throw StateError('expected a failure')), isA<NetworkFailure>());
    });
  });

  group('SupportMessageCubit', () {
    late _FakeRepo repo;
    late int n;
    late SupportMessageCubit cubit;

    setUp(() {
      repo = _FakeRepo();
      n = 0;
      cubit = SupportMessageCubit(repo, newKey: () => 'key-${++n}');
      addTearDown(cubit.close);
    });

    test('a retry of the same draft after a failure reuses the idempotency key', () async {
      repo.answers.add(const Left(NetworkFailure()));
      await cubit.send(_draft);
      expect(cubit.state.failure, isA<NetworkFailure>());
      await cubit.send(_draft);
      expect(repo.keys, ['key-1', 'key-1']);
      expect(cubit.state.status, SupportSendStatus.sent);
      expect(cubit.state.receipt!.reference, 'SUP-1');
    });

    test('cosmetic edits (extra spaces) are still the same submission', () async {
      repo.answers.add(const Left(NetworkFailure()));
      await cubit.send(_draft);
      await cubit.send(SupportMessageDraft(topic: _draft.topic, contactKind: _draft.contactKind, contact: _draft.contact.trim(), message: _draft.message.trim(), orderRef: _draft.orderRef));
      expect(repo.keys, ['key-1', 'key-1']);
    });

    test('a changed draft is a new submission with a new key', () async {
      repo.answers.add(const Left(NetworkFailure()));
      await cubit.send(_draft);
      await cubit.send(SupportMessageDraft(topic: _draft.topic, contactKind: _draft.contactKind, contact: _draft.contact, message: 'A different message entirely.', orderRef: ''));
      expect(repo.keys, ['key-1', 'key-2']);
    });

    test('after a success the next send is a new submission', () async {
      await cubit.send(_draft);
      expect(cubit.state.status, SupportSendStatus.sent);
      await cubit.send(_draft);
      expect(repo.keys, ['key-1', 'key-2']);
    });

    test('a draft the device refuses is not sent and gets no key', () async {
      await cubit.send(const SupportMessageDraft(topic: SupportTopic.other, contactKind: SupportContactKind.email, contact: 'a@b.co', message: 'short'));
      expect(cubit.state.issue, SupportDraftIssue.messageTooShort);
      expect(repo.keys, isEmpty);
      expect(n, 0);
    });

    test('the customer closing the human check returns to the form without an error', () async {
      repo.answers.add(const Left(HumanCheckCancelledFailure()));
      await cubit.send(_draft);
      expect(cubit.state, const SupportMessageState());
    });

    test('a double tap while sending is ignored', () async {
      final a = cubit.send(_draft);
      final b = cubit.send(_draft);
      await Future.wait([a, b]);
      expect(repo.keys, hasLength(1));
    });
  });

  group('SupportMessageDraft checks', () {
    SupportMessageDraft d({String message = 'A long enough message.', String contact = 'a@b.co', SupportContactKind kind = SupportContactKind.email, String ref = ''}) =>
        SupportMessageDraft(topic: SupportTopic.other, contactKind: kind, contact: contact, message: message, orderRef: ref);

    test('limits follow the API schema (10 to 2000 after trimming, order ref pattern)', () {
      expect(d(message: '         x         ').issue, SupportDraftIssue.messageTooShort);
      expect(d(message: 'a' * 10).issue, isNull);
      expect(d(message: 'a' * 2000).issue, isNull);
      expect(d(message: 'a' * 2001).issue, SupportDraftIssue.messageTooLong);
      expect(d(ref: 'abc').issue, SupportDraftIssue.orderRefInvalid);
      expect(d(ref: 'AB 12').issue, SupportDraftIssue.orderRefInvalid);
      expect(d(ref: 'AB12-CD').issue, isNull);
      expect(d(contact: 'not-an-email').issue, SupportDraftIssue.contactInvalid);
      expect(d(kind: SupportContactKind.phone, contact: '0111234567').issue, SupportDraftIssue.contactInvalid);
      expect(d(kind: SupportContactKind.phone, contact: '+27 82 123 4567').issue, isNull);
    });
  });

  group('SupportMessageForm', () {
    late _FakeRepo repo;
    late SupportMessageCubit cubit;
    final opened = <Uri>[];

    Future<void> pump(WidgetTester tester, {String? fallbackEmail}) async {
      repo = _FakeRepo();
      cubit = SupportMessageCubit(repo);
      addTearDown(cubit.close);
      opened.clear();
      await pumpThemed(
        tester,
        BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: SupportMessageForm(
              initialTopic: SupportTopic.payment,
              fallbackEmail: fallbackEmail,
              openEmail: (uri) async {
                opened.add(uri);
                return true;
              },
            ),
          ),
        ),
      );
    }

    Future<void> fill(WidgetTester tester) async {
      await tester.enterText(find.byKey(const Key('support-contact')), 'thandi@example.co.za');
      await tester.enterText(find.byKey(const Key('support-message')), 'I paid for a pass but it is not on my account.');
    }

    AppLocalizations l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(SupportMessageForm)));

    testWidgets('sends the draft and shows the reference to quote', (tester) async {
      await pump(tester);
      await fill(tester);
      await tester.tap(find.text('Send message'));
      await tester.pumpAndSettle();
      expect(repo.drafts.single.topic, SupportTopic.payment);
      expect(repo.drafts.single.contact, 'thandi@example.co.za');
      expect(find.text('Message sent'), findsOneWidget);
      expect(find.text('Reference: SUP-1'), findsOneWidget);
    });

    testWidgets('a message that is too short is refused on the device', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(const Key('support-contact')), 'thandi@example.co.za');
      await tester.enterText(find.byKey(const Key('support-message')), 'short');
      await tester.tap(find.text('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('Write at least 10 characters.'), findsOneWidget);
      expect(repo.drafts, isEmpty);
    });

    final failureCopy = <String, (Failure, String Function(AppLocalizations))>{
      'support_unavailable': (const SupportUnavailableFailure(Duration(seconds: 90)), (l) => l.failureSupportUnavailable),
      'invalid_message': (const InvalidMessageFailure(), (l) => l.failureInvalidMessage),
      'invalid_contact': (const InvalidContactFailure(), (l) => l.failureInvalidContact),
      'human_verification_failed': (const HumanVerificationFailedFailure(), (l) => l.failureHumanVerificationFailed),
      'rate limited': (const RateLimitedFailure('Too many attempts. Please wait and try again.', Duration(seconds: 30)), (l) => l.accountRequestRateLimited),
      'offline': (const NetworkFailure(), (l) => l.accountRequestOffline),
      'unknown': (ServerFailure('Something went wrong on our end.'), (l) => l.accountRequestFailed),
    };
    for (final MapEntry(key: name, value: (failure, copy)) in failureCopy.entries) {
      testWidgets('failure $name shows its customer copy and keeps the draft for a retry', (tester) async {
        await pump(tester);
        repo.answers.add(Left(failure));
        await fill(tester);
        await tester.tap(find.text('Send message'));
        await tester.pumpAndSettle();
        expect(find.text(copy(l10n(tester))), findsOneWidget);
        expect(find.text('Email us instead'), findsNothing);
        expect(find.text('thandi@example.co.za'), findsOneWidget, reason: 'the draft is kept');
        await tester.tap(find.text('Send message'));
        await tester.pumpAndSettle();
        expect(find.text('Message sent'), findsOneWidget);
        expect(repo.keys.toSet(), hasLength(1), reason: 'the retry is the same submission');
      });
    }

    testWidgets('support_contact_not_configured offers the email fallback only when there is an address', (tester) async {
      await pump(tester, fallbackEmail: 'help@isp.example');
      repo.answers.add(const Left(SupportContactNotConfiguredFailure()));
      await fill(tester);
      await tester.tap(find.text('Send message'));
      await tester.pumpAndSettle();
      expect(find.text(l10n(tester).failureSupportContactNotConfigured), findsOneWidget);
      await tester.tap(find.text('Email us instead'));
      await tester.pumpAndSettle();
      expect(opened.single.scheme, 'mailto');
      expect(opened.single.path, 'help@isp.example');
      expect(opened.single.queryParameters['body'], 'I paid for a pass but it is not on my account.');
    });

    testWidgets('no fallback button without an address', (tester) async {
      await pump(tester);
      repo.answers.add(const Left(SupportContactNotConfiguredFailure()));
      await fill(tester);
      await tester.tap(find.text('Send message'));
      await tester.pumpAndSettle();
      expect(find.text(l10n(tester).failureSupportContactNotConfigured), findsOneWidget);
      expect(find.text('Email us instead'), findsNothing);
    });
  });
}
