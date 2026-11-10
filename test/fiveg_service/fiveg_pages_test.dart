import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/theme/app_theme.dart';
import 'package:sentech_connect_app/app/theme/color_contrast.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/fiveg_service/data/mock_fiveg_repository.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/repositories/fiveg_repository.dart';
import 'package:sentech_connect_app/features/fiveg_service/presentation/bloc/fiveg_usage_cubit.dart';
import 'package:sentech_connect_app/features/fiveg_service/presentation/pages/fiveg_usage_page.dart';
import 'package:sentech_connect_app/features/fiveg_service/presentation/widgets/fiveg_service_entry.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

import '../helpers/pump_themed.dart';

const _service = 'svc-5g-1';
final _now = DateTime.utc(2026, 11, 10, 9);

/// Renders the usage page for [scenario] with the real cubit and the demo
/// repository (no latency, no timers: restore polling waits zero time).
Future<FiveGRepository> pumpUsage(
  WidgetTester tester, {
  FiveGScenario scenario = FiveGScenario.normal,
  FiveGRepository? repository,
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
  void Function(String orderId)? onOpenPayment,
  InMemorySecureStore? store,
}) async {
  final repo =
      repository ??
      MockFiveGRepository(
        store: store ?? InMemorySecureStore(),
        scenario: scenario,
        latency: Duration.zero,
        now: () => _now,
      );
  await pumpThemed(
    tester,
    BlocProvider(
      create: (_) => FiveGUsageCubit(
        repo,
        _service,
        restoringPollDelays: const [Duration.zero, Duration.zero, Duration.zero],
        wait: (_) async {},
      ),
      child: FiveGUsagePage(
        serviceId: _service,
        repository: repo,
        now: () => _now,
        onOpenPayment: onOpenPayment ?? (_) {},
      ),
    ),
    textScale: textScale,
    brightness: brightness,
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('usage page per scenario', () {
    testWidgets('normal: full speed, the meter sentence, the reset day and the rollover', (tester) async {
      await pumpUsage(tester);
      expect(find.text('Full speed. You can use your data as normal.'), findsOneWidget);
      expect(find.bySemanticsLabel('20 percent used: 20 GB of 100 GB.'), findsOneWidget);
      expect(find.textContaining('Resets on'), findsOneWidget);
      expect(find.text('1 day left'), findsNothing);
      expect(find.textContaining('days left'), findsOneWidget);
      expect(find.text('5 GB rolled over from last month'), findsOneWidget);
      expect(find.text('+50 GB'), findsOneWidget);
    });

    testWidgets('warn50: the half-way notice and no state warning', (tester) async {
      await pumpUsage(tester, scenario: FiveGScenario.warn50);
      expect(find.text("You have used half of this month's data."), findsOneWidget);
      expect(find.textContaining('rolled over'), findsNothing);
    });

    testWidgets('warn80: the 80 percent notice', (tester) async {
      await pumpUsage(tester, scenario: FiveGScenario.warn80);
      expect(find.text("You have used 80% of this month's data."), findsOneWidget);
    });

    testWidgets('warn100: cut off, the 100 percent notice and the unlock offers stay open', (tester) async {
      await pumpUsage(tester, scenario: FiveGScenario.warn100);
      expect(
        find.text("Your service is cut off because you have used this month's data. Buy an unlock to get back online."),
        findsOneWidget,
      );
      // A cut-off service shows the cut-off headline; the 100% notice is for normal state only.
      expect(find.text("You have used all of this month's data."), findsNothing);
      expect(find.text('+100 GB'), findsOneWidget);
    });

    testWidgets('slow lane: the speed is named in plain words', (tester) async {
      await pumpUsage(tester, scenario: FiveGScenario.slowLane);
      expect(
        find.text(
          'Slow lane: your speed is reduced to 5/2 Mbit/s until your data resets or you buy an unlock.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('out of bundle: says the data is used up and offers an unlock', (tester) async {
      await pumpUsage(tester, scenario: FiveGScenario.outOfBundle);
      expect(find.text("You have used this month's data. Buy an unlock to keep your full speed."), findsOneWidget);
      expect(find.text('Buy'), findsWidgets);
    });

    testWidgets('fair use: no meter, no unlock section, the fair-use headline', (tester) async {
      await pumpUsage(tester, scenario: FiveGScenario.fupThrottled);
      expect(find.text('Fair use plan'), findsOneWidget);
      expect(
        find.text('Fair use: your speed is reduced for the rest of this month. It returns to full speed on the 1st.'),
        findsOneWidget,
      );
      expect(find.textContaining('percent used'), findsNothing);
      expect(find.text('Buy more data'), findsNothing);
    });

    testWidgets('restoring after an unlock: a calm message, and a pull-to-refresh hint once polling stops', (tester) async {
      await pumpUsage(tester, scenario: FiveGScenario.unlockedRestoring);
      expect(find.text('Unlock applied. Restoring your service.'), findsOneWidget);
      expect(find.text('This is taking longer than usual. Pull down to refresh.'), findsOneWidget);
    });

    testWidgets('not available: a calm message, never an error screen', (tester) async {
      await pumpUsage(tester, scenario: FiveGScenario.notAvailable);
      expect(find.text('5G data details are not available for this service right now.'), findsOneWidget);
      expect(find.byType(FailureView), findsNothing);
    });

    testWidgets('a failed read shows the failure view with a retry', (tester) async {
      await pumpUsage(tester, scenario: FiveGScenario.failure);
      expect(find.byType(FailureView), findsOneWidget);
    });
  });

  group('accessibility and theme', () {
    for (final scenario in [FiveGScenario.normal, FiveGScenario.warn100, FiveGScenario.slowLane]) {
      for (final (scale, brightness) in [(1.0, Brightness.light), (2.0, Brightness.light), (1.0, Brightness.dark), (2.0, Brightness.dark)]) {
        testWidgets('$scenario at text scale $scale in ${brightness.name}: no overflow, offers reachable', (tester) async {
          await pumpUsage(tester, scenario: scenario, textScale: scale, brightness: brightness);
          expect(tester.takeException(), isNull);
          // The list is lazy: scroll the reset line into view, then the offers below it.
          final resets = find.textContaining('Resets on');
          await tester.scrollUntilVisible(resets, 120, scrollable: find.byType(Scrollable).first);
          expect(resets, findsOneWidget);
          expect(find.text('Unlock applied. Restoring your service.'), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('every unlock Buy button has a screen-reader label with the size and the price', (tester) async {
      await pumpUsage(tester);
      expect(find.bySemanticsLabel('Buy 50 GB of data for R199.00'), findsOneWidget);
      expect(find.bySemanticsLabel('Buy 100 GB of data for R349.00'), findsOneWidget);
    });

    testWidgets('the meter has text for the used share (meaning is not carried by colour alone)', (tester) async {
      await pumpUsage(tester, scenario: FiveGScenario.warn80);
      expect(find.textContaining('82%'), findsOneWidget);
      expect(find.bySemanticsLabel('82 percent used: 82 GB of 100 GB.'), findsOneWidget);
    });
  });

  group('buying an unlock', () {
    testWidgets('buy opens the confirmation with the price incl. VAT, and continuing hands the order id to payment', (tester) async {
      final store = InMemorySecureStore();
      String? paidOrder;
      await pumpUsage(tester, store: store, onOpenPayment: (id) => paidOrder = id);
      await tester.tap(find.text('Buy').first);
      await tester.pumpAndSettle();
      expect(find.text('Confirm your data unlock'), findsOneWidget);
      expect(find.text('R199.00 incl. VAT'), findsWidgets);
      expect(find.text('Valid until Nov 30, 2026'), findsWidgets);
      await tester.tap(find.text('Continue to payment'));
      await tester.pumpAndSettle();
      expect(paidOrder, isNotNull);
      expect(paidOrder, startsWith('fiveg_ord_'));
    });

    testWidgets('the monthly limit is shown in the sheet and no order is handed on', (tester) async {
      String? paidOrder;
      await pumpUsage(tester, scenario: FiveGScenario.limitReached, onOpenPayment: (id) => paidOrder = id);
      await tester.tap(find.text('Buy').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue to payment'));
      await tester.pumpAndSettle();
      expect(find.text('You have reached the data unlock limit for this month.'), findsOneWidget);
      expect(paidOrder, isNull);
    });

    testWidgets('an unpaid unlock shows the waiting card, and continuing pays that same order', (tester) async {
      final store = InMemorySecureStore();
      final repo = MockFiveGRepository(store: store, latency: Duration.zero, now: () => _now);
      await repo.createUnlockOrder(_service, productCode: 'data_unlock_50gb', idempotencyKey: 'key-waiting-1');
      String? paidOrder;
      await pumpUsage(tester, repository: repo, onOpenPayment: (id) => paidOrder = id);
      expect(find.text('An unlock is waiting for payment'), findsOneWidget);
      await tester.tap(find.text('Continue payment'));
      await tester.pumpAndSettle();
      expect(paidOrder, startsWith('fiveg_ord_'));
    });
  });

  group('service detail entry', () {
    testWidgets('shows the 5G row with the share used', (tester) async {
      final repo = MockFiveGRepository(store: InMemorySecureStore(), latency: Duration.zero, now: () => _now);
      var opened = false;
      await pumpThemed(
        tester,
        FiveGServiceEntry(serviceId: _service, repository: repo, onOpen: () => opened = true),
      );
      await tester.pumpAndSettle();
      expect(find.text('5G data'), findsOneWidget);
      expect(find.text("20% of this month's data used"), findsOneWidget);
      await tester.tap(find.text('5G data'));
      expect(opened, isTrue);
    });

    testWidgets('hides itself quietly when the feature is not available', (tester) async {
      final repo = MockFiveGRepository(
        store: InMemorySecureStore(),
        scenario: FiveGScenario.notAvailable,
        latency: Duration.zero,
        now: () => _now,
      );
      await pumpThemed(
        tester,
        FiveGServiceEntry(serviceId: _service, repository: repo, onOpen: () {}),
      );
      await tester.pumpAndSettle();
      expect(find.text('5G data'), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides itself quietly on a failed read too', (tester) async {
      final repo = MockFiveGRepository(
        store: InMemorySecureStore(),
        scenario: FiveGScenario.failure,
        latency: Duration.zero,
        now: () => _now,
      );
      await pumpThemed(
        tester,
        FiveGServiceEntry(serviceId: _service, repository: repo, onOpen: () {}),
      );
      await tester.pumpAndSettle();
      expect(find.text('5G data'), findsNothing);
    });
  });

  group('contrast of the notice colours (WCAG AA)', () {
    test('notice text, the accent icons and the error text clear their WCAG minimums in both themes', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final s = theme.colorScheme;
        final name = theme.brightness.name;
        expect(
          ColorContrast.ratio(s.onSurface, s.surfaceContainerHigh),
          greaterThanOrEqualTo(ColorContrast.minimumText),
          reason: 'notice text ($name)',
        );
        for (final accent in [s.primary, s.onSurface, s.error]) {
          expect(
            ColorContrast.ratio(accent, s.surfaceContainerHigh),
            greaterThanOrEqualTo(3.0),
            reason: 'accent icon/border $accent ($name)',
          );
        }
        expect(
          ColorContrast.ratio(s.error, s.surface),
          greaterThanOrEqualTo(ColorContrast.minimumText),
          reason: 'error text on the sheet ($name)',
        );
      }
    });
  });
}
