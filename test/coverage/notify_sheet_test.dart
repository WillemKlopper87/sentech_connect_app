import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/coverage/data/coverage_json.dart';
import 'package:sentech_connect_app/features/coverage/data/pending_lead_keys.dart';
import 'package:sentech_connect_app/features/coverage/domain/device_location.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_meta.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/geo_point.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';
import 'package:sentech_connect_app/features/coverage/domain/repositories/coverage_repository.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/address_search_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/coverage_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/location_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/notify_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/pages/coverage_page.dart';
import 'package:sentech_connect_app/features/coverage/presentation/widgets/leave_list_sheet.dart';
import 'package:sentech_connect_app/features/coverage/presentation/widgets/notify_me_sheet.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_themed.dart';
import '../helpers/test_setup.dart';
import 'fake_coverage_repository.dart';

class _NoLocation implements DeviceLocationService {
  @override
  Future<DeviceLocationResult> current() async => const LocationFailed();

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

const _point = GeoPoint(-26.514, 29.103);
const _scope = 'sentech|-26.51400,29.10300|any';

void main() {
  setUpAppTests();

  late FakeCoverageRepository repo;
  late PendingLeadKeys pending;
  late CoverageCubit coverage;
  var keys = 0;
  var clock = DateTime.utc(2026, 11, 26, 10);

  setUp(() async {
    repo = FakeCoverageRepository();
    pending = PendingLeadKeys();
    keys = 0;
    clock = DateTime.utc(2026, 11, 26, 10);
    coverage = CoverageCubit(repo, debounce: const Duration(milliseconds: 10));
    await coverage.load();
  });

  tearDown(() => coverage.close());

  Future<void> pumpSheet(WidgetTester tester, {TechnologyInterest interest = TechnologyInterest.any, String? address = '12 Lifalethu Avenue, eMbalenhle'}) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpThemed(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: coverage),
          BlocProvider(create: (_) => NotifyCubit(repo, newKey: () => 'key-${++keys}', pending: pending, scope: _scope, now: () => clock)),
        ],
        child: Scaffold(body: NotifyMeSheet(point: _point, initialAddress: address, interest: interest)),
      ),
      size: const Size(390, 1400),
    );
    await tester.pump();
  }

  Finder consent(int index) => find.byType(CheckboxListTile).at(index);

  bool ticked(WidgetTester tester, int index) => tester.widget<CheckboxListTile>(consent(index)).value ?? false;

  Future<void> fill(WidgetTester tester, {String contact = '082 123 4567'}) async {
    await tester.enterText(find.byKey(const ValueKey('notify-contact')), contact);
    await tester.pump();
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('notify-submit')));
    await tester.tap(find.byKey(const ValueKey('notify-submit')));
    await tester.pump();
    await tester.pump();
  }

  bool submitEnabled(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const ValueKey('notify-submit'))).onPressed != null;

  group('NotifyMeSheet', () {
    testWidgets('consents_start_unticked_and_are_sent_separately', (tester) async {
      await pumpSheet(tester);
      expect(find.byType(CheckboxListTile), findsNWidgets(2));
      expect(ticked(tester, 0), isFalse);
      expect(ticked(tester, 1), isFalse);
      // Both consent texts name the version the platform expects.
      expect(find.textContaining('Consent version 2026-10-01'), findsOneWidget);
      expect(find.textContaining('Separate consent, version 2026-11-18'), findsOneWidget);
      await fill(tester);
      expect(submitEnabled(tester), isFalse, reason: 'no consent yet');
      // The optional arrival consent alone is not the sign-up consent.
      await tester.ensureVisible(consent(1));
      await tester.tap(consent(1));
      await tester.pump();
      expect(ticked(tester, 0), isFalse, reason: 'ticking one never ticks the other');
      expect(submitEnabled(tester), isFalse);
      await tester.tap(consent(1)); // untick again
      await tester.pump();
      await tester.tap(consent(0));
      await tester.pump();
      expect(ticked(tester, 1), isFalse);
      expect(submitEnabled(tester), isTrue);
      await tapSubmit(tester);
      var sent = repo.leadCalls.single.request;
      expect(sent.waitlistConsentVersion, '2026-10-01');
      expect(sent.arrivalConsentGranted, isFalse);
      expect(sent.arrivalConsentVersion, '2026-11-18');
      expect(sent.contactType, ContactKind.phone);
      expect(sent.contactValue, '082 123 4567');
      expect(sent.addressText, '12 Lifalethu Avenue, eMbalenhle');
      expect(sent.lat, -26.514);
      // A second sign-up with both ticked sends the arrival consent as granted.
      await pumpSheet(tester);
      await fill(tester, contact: '083 111 2222');
      await tester.tap(consent(0));
      await tester.ensureVisible(consent(1));
      await tester.tap(consent(1));
      await tester.pump();
      await tapSubmit(tester);
      sent = repo.leadCalls.last.request;
      expect(sent.arrivalConsentGranted, isTrue);
    });

    testWidgets('the form checks the contact and the address before it can be sent', (tester) async {
      await pumpSheet(tester, address: null);
      await tester.tap(consent(0));
      await tester.pump();
      await fill(tester, contact: 'nonsense');
      expect(find.text('Enter a valid mobile number or email address.'), findsOneWidget);
      expect(submitEnabled(tester), isFalse);
      await fill(tester);
      await tester.enterText(find.byKey(const ValueKey('notify-address')), 'abc');
      await tester.pump();
      expect(submitEnabled(tester), isFalse, reason: 'the platform wants 5 characters');
      await tester.enterText(find.byKey(const ValueKey('notify-address')), '12 Main Road');
      await tester.pump();
      expect(submitEnabled(tester), isTrue);
      // An email contact is checked as an email address and sent as one.
      await tester.tap(find.text('Email address'));
      await tester.pump();
      await fill(tester, contact: 'jane@example.com');
      await tapSubmit(tester);
      expect(repo.leadCalls.single.request.contactType, ContactKind.email);
    });

    testWidgets('the technology interest the customer came from is preselected and is sent', (tester) async {
      await pumpSheet(tester, interest: TechnologyInterest.fiveG);
      await fill(tester);
      await tester.tap(consent(0));
      await tester.pump();
      await tapSubmit(tester);
      expect(repo.leadCalls.single.request.technologyInterest, TechnologyInterest.fiveG);
    });

    testWidgets('a_double_tap_sends_one_request', (tester) async {
      repo.leadGate = Completer<void>();
      await pumpSheet(tester);
      await fill(tester);
      await tester.tap(consent(0));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('notify-submit')));
      await tester.tap(find.byKey(const ValueKey('notify-submit')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('notify-submit')), warnIfMissed: false);
      await tester.pump();
      repo.leadGate!.complete();
      await tester.pump();
      await tester.pump();
      expect(repo.leadCalls, hasLength(1));
    });

    testWidgets('the_contact_is_cleared_after_success: the thank-you replaces the form and holds no contact', (tester) async {
      await pumpSheet(tester);
      await fill(tester, contact: '082 123 4567');
      await tester.tap(consent(0));
      await tester.pump();
      await tapSubmit(tester);
      await tester.pump();
      expect(find.text('Thank you. We will let you know when coverage reaches this place.'), findsOneWidget);
      expect(find.byKey(const ValueKey('notify-contact')), findsNothing);
      expect(find.textContaining('082'), findsNothing);
      expect(find.textContaining('Lifalethu'), findsNothing);
      expect(pending.pendingFor(_scope), isNull);
    });

    testWidgets('the_form_really_lets_go_of_the_contact_and_address_once_the_sign_up_is_accepted', (tester) async {
      await pumpSheet(tester);
      await fill(tester, contact: '082 123 4567');
      await tester.tap(consent(0));
      await tester.pump();
      final state = tester.state<NotifyMeSheetState>(find.byType(NotifyMeSheet));
      expect(state.heldText, contains('082 123 4567'), reason: 'the form does hold it while it is open');
      expect(state.heldText, contains('Lifalethu'));
      await tapSubmit(tester);
      await tester.pump();
      expect(state.heldText, isEmpty, reason: 'accepted: the typed contact and address are cleared');
    });

    testWidgets('a security check outage says the details were not sent, never that they may have been', (tester) async {
      repo.leadResults
        ..clear()
        ..add(const Left(HumanVerificationUnavailableFailure()));
      await pumpSheet(tester);
      await fill(tester);
      await tester.tap(consent(0));
      await tester.pump();
      await tapSubmit(tester);
      expect(find.textContaining('were not sent'), findsOneWidget);
      expect(find.textContaining('may not have finished'), findsNothing);
    });

    testWidgets('a rate limit counts down, holds the button and lets go when the wait is over', (tester) async {
      repo.leadResults
        ..clear()
        ..addAll([const Left(RateLimitedFailure('Too many attempts. Please wait and try again.', Duration(seconds: 5))), const Right(unit)]);
      await pumpSheet(tester);
      await fill(tester);
      await tester.tap(consent(0));
      await tester.pump();
      await tapSubmit(tester);
      expect(find.textContaining('try again in 5 seconds'), findsOneWidget);
      expect(find.textContaining('may not have finished'), findsNothing);
      expect(submitEnabled(tester), isFalse);
      expect(repo.leadCalls, hasLength(1));
      clock = clock.add(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 1));
      expect(submitEnabled(tester), isTrue);
      await tapSubmit(tester);
      expect(repo.leadCalls, hasLength(2));
      expect(find.textContaining('Thank you'), findsOneWidget);
    });

    testWidgets('a lost response keeps the form, says it may not have finished, and the retry sends the same key', (tester) async {
      repo.leadResults
        ..clear()
        ..addAll([const Left(NetworkFailure()), const Right(unit)]);
      await pumpSheet(tester);
      await fill(tester);
      await tester.tap(consent(0));
      await tester.pump();
      await tapSubmit(tester);
      expect(find.textContaining('may not have finished'), findsOneWidget);
      expect(find.textContaining("You're offline"), findsOneWidget);
      expect(find.byKey(const ValueKey('notify-contact')), findsOneWidget, reason: 'nothing the customer typed is lost');
      await tapSubmit(tester);
      expect(repo.leadCalls.map((c) => c.key), ['key-1', 'key-1']);
      expect(find.textContaining('Thank you'), findsOneWidget);
    });

    testWidgets('a refusal is read in words and a stale consent text unticks both boxes and reads the meta again', (tester) async {
      repo.leadResults
        ..clear()
        ..addAll([const Left(ConsentVersionOutdatedFailure()), const Left(InvalidContactFailure())]);
      await pumpSheet(tester);
      await fill(tester);
      await tester.tap(consent(0));
      await tester.ensureVisible(consent(1));
      await tester.tap(consent(1));
      await tester.pump();
      await tapSubmit(tester);
      expect(find.textContaining('consent text was updated'), findsOneWidget);
      expect(ticked(tester, 0), isFalse);
      expect(ticked(tester, 1), isFalse);
      expect(repo.metaRefreshes, 1);
      await tester.tap(consent(0));
      await tester.pump();
      await tapSubmit(tester);
      expect(find.textContaining('Check your contact details'), findsOneWidget);
    });

    testWidgets('a customer who backs out of the security check just returns to the form', (tester) async {
      repo.leadResults
        ..clear()
        ..add(const Left(HumanCheckCancelledFailure()));
      await pumpSheet(tester);
      await fill(tester);
      await tester.tap(consent(0));
      await tester.pump();
      await tapSubmit(tester);
      expect(find.textContaining('request was cancelled'), findsNothing);
      expect(find.byKey(const ValueKey('notify-contact')), findsOneWidget);
      expect(ticked(tester, 0), isTrue);
    });

    testWidgets('closing the sheet while the request is in flight throws nothing', (tester) async {
      repo.leadGate = Completer<void>();
      await pumpSheet(tester);
      await fill(tester);
      await tester.tap(consent(0));
      await tester.pump();
      await tapSubmit(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      repo.leadGate!.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text does not overflow the form', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpThemed(
        tester,
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: coverage),
            BlocProvider(create: (_) => NotifyCubit(repo, pending: pending, scope: _scope)),
          ],
          child: Scaffold(body: NotifyMeSheet(point: _point, initialAddress: '12 Lifalethu Avenue', interest: TechnologyInterest.any)),
        ),
        textScale: 2.0,
        size: const Size(320, 640),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('LeaveListSheet', () {
    Future<void> pumpLeave(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpThemed(
        tester,
        RepositoryProvider<CoverageRepository>.value(value: repo, child: const Scaffold(body: LeaveListSheet())),
        size: const Size(390, 1000),
      );
      await tester.pump();
    }

    testWidgets('withdrawal_never_claims_removal_before_the_link', (tester) async {
      await pumpLeave(tester);
      expect(find.textContaining('only the link can remove it'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('leave-contact')), '082 123 4567');
      await tester.pump();
      await tester.tap(find.text('Send me a link'));
      await tester.pump();
      await tester.pump();
      expect(repo.withdrawalCalls.single.contactValue, '082 123 4567');
      expect(find.textContaining('we have sent it a link'), findsOneWidget);
      expect(find.textContaining('If nothing arrives, it was not on the list'), findsOneWidget);
      // It never says the contact was removed, and it does not repeat the contact.
      expect(find.textContaining('removed'), findsNothing);
      expect(find.textContaining('You have left'), findsNothing);
      expect(find.textContaining('082'), findsNothing);
      expect(find.byKey(const ValueKey('leave-contact')), findsNothing);
    });

    testWidgets('a failure is read in words and the contact stays so the customer can try again', (tester) async {
      repo.withdrawalResult = const Left(RateLimitedFailure('Too many attempts. Please wait and try again.', Duration(seconds: 60)));
      await pumpLeave(tester);
      await tester.enterText(find.byKey(const ValueKey('leave-contact')), '082 123 4567');
      await tester.pump();
      await tester.tap(find.text('Send me a link'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Too many attempts'), findsOneWidget);
      expect(find.byKey(const ValueKey('leave-contact')), findsOneWidget);
      repo.withdrawalResult = const Right(unit);
      await tester.tap(find.text('Send me a link'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('we have sent it a link'), findsOneWidget);
    });
  });

  group('on the coverage page', () {
    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpThemed(
        tester,
        RepositoryProvider<CoverageRepository>.value(
          value: repo,
          child: MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => CoverageCubit(repo, debounce: const Duration(milliseconds: 10))),
              BlocProvider(create: (_) => AddressSearchCubit(repo, debounce: const Duration(milliseconds: 10))),
              BlocProvider(create: (_) => LocationCubit(_NoLocation())),
            ],
            child: CoveragePage(onCovered: () {}),
          ),
        ),
        size: const Size(390, 1400),
      );
      await tester.pump();
      await tester.pump();
    }

    Future<void> tapMap(WidgetTester tester) async {
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      map.options.onTap!(const TapPosition(Offset.zero, Offset.zero), const LatLng(-26.2, 28.0));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump();
    }

    testWidgets('an_older_server_hides_the_notify_action', (tester) async {
      // A server older than the waiting-list consent versions: meta has none.
      repo.metaResult = Right(coverageMetaFromJson({'tenant': 'sentech', 'dataset_version': 7, 'bounds': [16.0, -35.5, 33.5, -22.0]}));
      repo.checkResult = Right(checkFixture('coverage_check_planned.json'));
      await pumpPage(tester);
      await tapMap(tester);
      expect(find.text('5G: planned'), findsOneWidget);
      expect(find.text('Notify me'), findsNothing);
      expect(find.text('Already on the list and want to leave it?'), findsNothing);
    });

    testWidgets('with the consent versions the notify action opens the form for that place and the leave link opens the leave form', (tester) async {
      repo.checkResult = Right(checkFixture('coverage_check_planned.json'));
      await pumpPage(tester);
      await tapMap(tester);
      await tester.ensureVisible(find.text('Notify me'));
      await tester.tap(find.text('Notify me'));
      await tester.pumpAndSettle();
      expect(find.text('Join the waitlist'), findsWidgets);
      expect(find.byType(CheckboxListTile), findsNWidgets(2));
      // The coordinates sent are the ones checked, and the technology the card was for.
      await tester.enterText(find.byKey(const ValueKey('notify-contact')), '082 123 4567');
      await tester.enterText(find.byKey(const ValueKey('notify-address')), '12 Main Road');
      await tester.pump();
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('notify-submit')));
      await tester.tap(find.byKey(const ValueKey('notify-submit')));
      await tester.pump();
      await tester.pump();
      final sent = repo.leadCalls.single.request;
      expect(sent.lat, -26.2);
      expect(sent.technologyInterest, TechnologyInterest.fiveG);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Already on the list and want to leave it?'));
      await tester.tap(find.text('Already on the list and want to leave it?'));
      await tester.pumpAndSettle();
      expect(find.text('Leave the coverage waiting list'), findsOneWidget);
    });

    testWidgets('the notify action is not offered where the server did not allow it', (tester) async {
      await pumpPage(tester); // two options: only the LTE one allows it
      await tapMap(tester);
      expect(find.text('Notify me'), findsOneWidget);
      repo.checkResult = Right(checkFixture('coverage_check_placeholder.json'));
      await tapMap(tester);
      expect(find.text('Notify me'), findsNothing);
    });
  });

  test('the meta fixture offers the notify action', () {
    expect(metaFixture().canOfferNotify, isTrue);
    expect(const CoverageMeta().canOfferNotify, isFalse);
    expect(fixtureMap('coverage_meta.json')['waitlist_consent_version'], isNotNull);
  });
}
