import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/theme/app_theme.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/security/human_check_provider.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_check_controller.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_config.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_message.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_provider.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';
import 'package:sentech_connect_app/l10n/failure_copy.dart';
import 'package:sentech_connect_app/shared/widgets/human_check_sheet.dart';

import 'helpers/fake_turnstile_surface.dart';

final _config = TurnstileConfig.resolve(siteKey: '0x4AAAAAAAbcdEFGH', baseUrl: 'https://www.example.co.za', isDebug: false)!;

class _Harness {
  _Harness(this.locale, {this.textScale = 1.0});

  final Locale locale;
  final double textScale;
  final navigatorKey = GlobalKey<NavigatorState>();
  final surface = FakeTurnstileSurface();
  late final TurnstileCheckController check = TurnstileCheckController(
    surface: surface,
    config: _config,
    loadTimeout: const Duration(days: 1),
    challengeTimeout: const Duration(days: 1),
    maxAutoRetries: 0,
  );

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: Text('home')),
      ),
    );
    await check.start();
    NavigatorHumanCheckPresenter(navigatorKey).present(check);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // the spinner never settles
  }

  AppLocalizations get l10n => lookupAppLocalizations(locale);
}

void main() {
  for (final locale in const [Locale('en'), Locale('af'), Locale('zu')]) {
    group('Quick check sheet (${locale.languageCode})', () {
      testWidgets('shows the title, the explanation, the widget view and Cancel', (tester) async {
        final h = _Harness(locale);
        await h.open(tester);
        expect(find.text(h.l10n.humanCheckTitle), findsOneWidget);
        expect(find.text(h.l10n.humanCheckBody), findsOneWidget);
        expect(find.text(h.l10n.humanCheckLoading), findsOneWidget);
        expect(find.byKey(const Key('fakeTurnstileView')), findsOneWidget);
        expect(find.text(h.l10n.humanCheckCancel), findsOneWidget);
        expect(find.byKey(const Key('humanCheckRetry')), findsNothing);
        h.check.cancel();
        await tester.pumpAndSettle();
      });

      testWidgets('asks the customer to act when the widget needs it', (tester) async {
        final h = _Harness(locale);
        await h.open(tester);
        h.surface.send(const TurnstileReady());
        h.surface.send(const TurnstileInteractive());
        await tester.pump();
        expect(find.text(h.l10n.humanCheckChallenge), findsOneWidget);
        h.check.cancel();
        await tester.pumpAndSettle();
      });

      testWidgets('a failed check shows its reason, a way out and Retry; Retry asks for a new challenge', (tester) async {
        final h = _Harness(locale);
        await h.open(tester);
        h.surface.send(const TurnstilePageError());
        await tester.pump();
        expect(find.text(h.l10n.humanCheckFailedNetwork), findsOneWidget);
        expect(find.text(h.l10n.humanCheckHelp), findsOneWidget);
        expect(find.byKey(const Key('humanCheckRetry')), findsOneWidget);
        expect(find.byKey(const Key('humanCheckCancel')), findsOneWidget);
        await tester.tap(find.byKey(const Key('humanCheckRetry')));
        await tester.pump();
        expect(h.surface.resets, 1);
        expect(find.text(h.l10n.humanCheckLoading), findsOneWidget);
        h.check.cancel();
        await tester.pumpAndSettle();
      });

      testWidgets('widget error and timeout have their own copy', (tester) async {
        final h = _Harness(locale);
        await h.open(tester);
        h.surface.send(const TurnstileWidgetError('1'));
        await tester.pump();
        expect(find.text(h.l10n.humanCheckFailedWidget), findsOneWidget);
        await tester.tap(find.byKey(const Key('humanCheckRetry')));
        await tester.pump();
        h.surface.send(const TurnstileWidgetTimeout());
        await tester.pump();
        expect(find.text(h.l10n.humanCheckFailedTimeout), findsOneWidget);
        h.check.cancel();
        await tester.pumpAndSettle();
      });

      testWidgets('Cancel closes the sheet and cancels the check', (tester) async {
        final h = _Harness(locale);
        await h.open(tester);
        await tester.tap(find.byKey(const Key('humanCheckCancel')));
        await tester.pumpAndSettle();
        expect(find.text(h.l10n.humanCheckTitle), findsNothing);
        expect(await h.check.result, isA<TurnstileCancelled>());
      });

      testWidgets('a solved check closes the sheet by itself', (tester) async {
        final h = _Harness(locale);
        await h.open(tester);
        h.surface.sendRaw('{"t":"token","v":"$testTurnstileToken"}');
        await tester.pumpAndSettle();
        expect(find.text(h.l10n.humanCheckTitle), findsNothing);
        expect((await h.check.result as TurnstileSolved).token, testTurnstileToken);
      });

      testWidgets('is readable at the largest text size without overflow, Cancel and Retry reachable', (tester) async {
        final h = _Harness(locale, textScale: 2.0);
        await h.open(tester);
        expect(tester.takeException(), isNull);
        h.surface.send(const TurnstilePageError());
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('humanCheckRetry')), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('humanCheckCancel')));
        await tester.tap(find.byKey(const Key('humanCheckCancel')));
        await tester.pumpAndSettle();
        expect(find.text(h.l10n.humanCheckTitle), findsNothing);
      });

      testWidgets('is accessible: a header, a live status, a labelled widget area, 48dp buttons', (tester) async {
        final handle = tester.ensureSemantics();
        final h = _Harness(locale);
        await h.open(tester);
        expect(find.bySemanticsLabel(h.l10n.humanCheckWidgetLabel), findsOneWidget);
        expect(
          tester.getSemantics(find.text(h.l10n.humanCheckTitle)),
          matchesSemantics(label: h.l10n.humanCheckTitle, isHeader: true),
        );
        expect(tester.getSize(find.byKey(const Key('humanCheckCancel'))).height, greaterThanOrEqualTo(48));
        h.check.cancel();
        await tester.pumpAndSettle();
        handle.dispose();
      });
    });
  }

  testWidgets('dismissing the sheet with the back button cancels the provider call', (tester) async {
    final h = _Harness(const Locale('en'));
    final provider = TurnstileWebViewProvider(
      config: _config,
      presenter: NavigatorHumanCheckPresenter(h.navigatorKey),
      surfaceFactory: () => h.surface,
    );
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: h.navigatorKey,
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Text('home')),
      ),
    );
    Object? error;
    provider.token().then<void>((_) {}, onError: (Object e) => error = e);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HumanCheckSheet), findsOneWidget);
    // The scrim tap and the back button are the same pop of the modal route.
    h.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(error, isA<HumanCheckCancelled>());
    expect(h.surface.disposed, isTrue);
  });

  testWidgets('without a navigator the presenter says the check is unavailable', (tester) async {
    final presenter = NavigatorHumanCheckPresenter(GlobalKey<NavigatorState>());
    final h = _Harness(const Locale('en'));
    await expectLater(presenter.present(h.check), throwsA(isA<HumanCheckUnavailable>()));
  });

  testWidgets('the typed server refusals still read well next to the sheet copy (existing failure copy)', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(typedFailureText(l10n, const HumanVerificationFailedFailure()), l10n.failureHumanVerificationFailed);
    expect(typedFailureText(l10n, const HumanVerificationUnavailableFailure(Duration(seconds: 30))), l10n.failureHumanVerificationUnavailableSeconds(30));
    expect(localizedFailureText(l10n, const HumanCheckCancelledFailure().message), l10n.failureTheRequestWasCancelled);
  });
}
