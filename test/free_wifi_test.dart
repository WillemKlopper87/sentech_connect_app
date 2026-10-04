import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/core/time/platform_clock.dart';
import 'package:sentech_connect_app/features/wifi_voucher/data/repositories/mock_free_wifi_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/bloc/free_wifi_cubit.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/pages/free_wifi_card.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';
import 'package:sentech_connect_app/l10n/app_localizations_zu.dart';

import 'helpers/pump_themed.dart';

class _LongWifiZulu extends AppLocalizationsZu {
  @override
  String get freeWifiFreeWifi =>
      'Free WiFi available for everyone nearby today';

  @override
  String get freeWifiFreeWifiActive =>
      'Free WiFi active for your current session today';
}

class _LongWifiDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _LongWifiDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'zu';

  @override
  Future<AppLocalizations> load(Locale locale) async => _LongWifiZulu();

  @override
  bool shouldReload(_LongWifiDelegate old) => false;
}

void main() {
  MockFreeWifiRepository newRepo() =>
      MockFreeWifiRepository(InMemorySecureStore(), clock: FakePlatformClock());

  // The real AppTheme: its full-width button minimumSize is what broke the
  // card's button row, which Flutter's default theme never showed.
  Future<void> pumpCard(WidgetTester tester, {MockFreeWifiRepository? repo}) =>
      pumpThemed(
        tester,
        BlocProvider(
          create: (_) => FreeWifiCubit(repo ?? newRepo()),
          child: FreeWifiCard(onFindHotspots: () {}),
        ),
      );

  testWidgets('Watch ad and Hotspots render under the real theme', (
    tester,
  ) async {
    await pumpCard(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(FilledButton, 'Watch ad'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Hotspots'), findsOneWidget);
    for (final label in ['Watch ad', 'Hotspots']) {
      final size = tester.getSize(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(size.width, greaterThan(80), reason: label);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
  });

  testWidgets('the active session button renders under the real theme', (
    tester,
  ) async {
    final repo = newRepo();
    await repo.recordAdWatchedAndGrantSession();
    await pumpCard(tester, repo: repo);
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(
      find.widgetWithText(OutlinedButton, 'Find hotspots near me'),
      findsOneWidget,
    );
  });

  for (final active in [false, true]) {
    testWidgets(
      '${active ? 'active' : 'offer'} heading wraps at 360x690, 2x with expanded copy',
      (tester) async {
        final repo = newRepo();
        if (active) await repo.recordAdWatchedAndGrantSession();
        await pumpThemed(
          tester,
          BlocProvider(
            create: (_) => FreeWifiCubit(repo),
            child: SingleChildScrollView(
              child: FreeWifiCard(onFindHotspots: () {}),
            ),
          ),
          size: const Size(360, 690),
          textScale: 2,
          locale: const Locale('zu'),
          localizationDelegate: const _LongWifiDelegate(),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 100));
        final heading = active
            ? 'Free WiFi active for your current session today'
            : 'Free WiFi available for everyone nearby today';
        expect(find.text(heading), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (active) {
          expect(find.text('TIME LEFT'), findsOneWidget);
          expect(find.text('DATA LEFT'), findsOneWidget);
          expect(find.byType(OutlinedButton), findsOneWidget);
        } else {
          expect(find.byType(FilledButton), findsOneWidget);
          expect(find.byType(OutlinedButton), findsOneWidget);
        }
        final action = active
            ? find.byType(OutlinedButton)
            : find.byType(FilledButton);
        await tester.ensureVisible(action.first);
        await tester.pump();
        expect(tester.getSize(action.first).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('the offer body meets the 15 px floor under the real theme', (
    tester,
  ) async {
    await pumpCard(tester);
    await tester.pumpAndSettle();

    final body = find.textContaining('3 of 3 free views left today');
    final rendered = tester.widget<RichText>(
      find.descendant(of: body, matching: find.byType(RichText)),
    );
    expect(rendered.text.style!.fontSize, greaterThanOrEqualTo(15));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the active session body meets the 15 px floor', (tester) async {
    final repo = newRepo();
    await repo.recordAdWatchedAndGrantSession();
    await pumpCard(tester, repo: repo);
    await tester.pump(const Duration(milliseconds: 100));

    final body = find.text('Updates from your account as you use it.');
    final renderedBody = tester.widget<RichText>(
      find.descendant(of: body, matching: find.byType(RichText)),
    );
    expect(renderedBody.text.style!.fontSize, greaterThanOrEqualTo(15));
    expect(tester.takeException(), isNull);
  });

  testWidgets('active session stat labels meet the 13 px floor', (
    tester,
  ) async {
    final repo = newRepo();
    await repo.recordAdWatchedAndGrantSession();
    await pumpCard(tester, repo: repo);
    await tester.pump(const Duration(milliseconds: 100));

    for (final label in ['TIME LEFT', 'DATA LEFT']) {
      final rendered = tester.widget<RichText>(
        find.descendant(of: find.text(label), matching: find.byType(RichText)),
      );
      expect(
        rendered.text.style!.fontSize,
        greaterThanOrEqualTo(13),
        reason: label,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers to watch an ad with 3 free views available initially', (
    tester,
  ) async {
    await pumpCard(tester);
    await tester.pumpAndSettle();

    expect(find.text('Free WiFi'), findsOneWidget);
    expect(find.textContaining('3 of 3 free views left today'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Watch ad'), findsOneWidget);
  });

  testWidgets('watching an ad grants a session and shows a live countdown', (
    tester,
  ) async {
    await pumpCard(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Watch ad'));
    await tester.pump(); // enter watchingAd state, dialog opens
    await tester.pump(const Duration(seconds: 6)); // simulated ad duration
    await tester.pump(); // dialog pops, claim completes
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Free WiFi active'), findsOneWidget);
    expect(find.text('TIME LEFT'), findsOneWidget);
    expect(find.text('DATA LEFT'), findsOneWidget);
    // Roughly 45 minutes should be left immediately after granting.
    expect(find.textContaining('44m'), findsOneWidget);
  });

  testWidgets('a granted session counts against the daily allowance', (
    tester,
  ) async {
    final repo = newRepo();
    // Grant via the repository so the test doesn't need to sit through a
    // simulated ad. The full cap is covered in free_wifi_repository_test.dart.
    await repo.recordAdWatchedAndGrantSession();

    await pumpCard(tester, repo: repo);
    await tester.pumpAndSettle();

    // A session is active, so the countdown shows; assert on cubit state.
    final cubit = BlocProvider.of<FreeWifiCubit>(
      tester.element(find.byType(FreeWifiCard)),
    );
    expect(cubit.state.adsRemainingToday, 2);
  });
}
