import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/shared/actions/support_actions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/features/support/data/repositories/mock_support_message_repository.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_message_repository.dart';
import 'package:sentech_connect_app/features/support/data/repositories/mock_support_repository.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/support_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/pages/support_page.dart';

import 'helpers/pump_themed.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester) {
    return pumpThemed(
      tester,
      BlocProvider(
        create: (_) => SupportCubit(MockSupportRepository()),
        child: const SupportPage(),
      ),
    );
  }

  testWidgets('search filters the FAQ list', (tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text("I can't connect to the WiFi"), findsOneWidget);
    expect(find.text('I paid but have no pass'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'paid');
    await tester.pump();

    expect(find.text('I paid but have no pass'), findsOneWidget);
    expect(find.text("I can't connect to the WiFi"), findsNothing);
  });

  testWidgets('tapping an FAQ expands its answer', (tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    // AnimatedCrossFade keeps both children permanently mounted (it fades
    // between them rather than removing either from the tree), so
    // collapsed/expanded is asserted via its crossFadeState, not via
    // presence/absence of the answer text.
    CrossFadeState state() => tester
        .widgetList<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
        .first
        .crossFadeState;

    expect(state(), CrossFadeState.showFirst);
    await tester.tap(find.text("I can't connect to the WiFi"));
    await tester.pumpAndSettle();
    expect(state(), CrossFadeState.showSecond);
    expect(
      find.text(lookupAppLocalizations(const Locale('en')).hotspotFaq1Answer),
      findsOneWidget,
    );

    // Tapping again collapses it.
    await tester.tap(find.text("I can't connect to the WiFi"));
    await tester.pumpAndSettle();
    expect(state(), CrossFadeState.showFirst);
  });

  testWidgets('Submit a ticket opens the real message form', (tester) async {
    await locator.reset();
    locator.registerLazySingleton<SupportMessageRepository>(
      () => MockSupportMessageRepository(),
    );
    addTearDown(locator.reset);
    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit a ticket'));
    await tester.pumpAndSettle();

    expect(find.text('Message support'), findsOneWidget);
    expect(find.text('Send message'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('support-contact')),
      'thandi@example.co.za',
    );
    await tester.enterText(
      find.byKey(const Key('support-message')),
      'My router keeps disconnecting.',
    );
    await tester.tap(find.text('Send message'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Reference: DEMO-0001'), findsOneWidget);
  });

  testWidgets('prod: no FAQ list (it is mock), the contact actions stay', (
    tester,
  ) async {
    await pumpThemed(tester, const SupportPage(showFaqs: false));
    await tester.pumpAndSettle();
    expect(find.text("I can't connect to the WiFi"), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Submit a ticket'), findsOneWidget);
  });

  test(
    'tenant WhatsApp setting survives cache and rejects invalid contacts',
    () {
      final branding = TenantBranding.fromJson({
        'whatsapp_number': '+27825550100',
      });
      expect(branding.whatsAppNumber, '+27825550100');
      expect(TenantBranding.fromJson(branding.toJson()), branding);
      final uri = supportWhatsAppUri(
        branding.whatsAppNumber,
        message: 'Hello & help',
      );
      expect(uri!.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/27825550100');
      expect(uri.queryParameters, {'text': 'Hello & help'});
      for (final value in [
        null,
        '',
        '270000000000',
        '0825550100',
        '+2782',
        '+27825550100?text=fake',
        'https://wa.me/27825550100',
        '+27825550100 ',
        '+27825550100\n',
      ]) {
        expect(
          TenantBranding.fromJson({'whatsapp_number': value}).whatsAppNumber,
          isNull,
        );
        expect(supportWhatsAppUri(value), isNull);
      }
    },
  );

  testWidgets('hotspot help is first and router answers require cpe', (
    tester,
  ) async {
    for (final cpe in [false, true]) {
      final cubit = SupportCubit(MockSupportRepository());
      await pumpThemed(
        tester,
        BlocProvider.value(
          value: cubit,
          child: SupportPage(cpe: cpe),
        ),
      );
      await tester.pumpAndSettle();
      final questions = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where(
            (s) => [
              "I can't connect to the WiFi",
              'I paid but have no pass',
              'My hotspot connection is slow',
              'Why is my speed slower than expected?',
            ].contains(s),
          )
          .toList();
      expect(questions.take(3), [
        "I can't connect to the WiFi",
        'I paid but have no pass',
        'My hotspot connection is slow',
      ]);
      await tester.enterText(find.byType(TextField), 'router');
      await tester.pumpAndSettle();
      expect(
        find.text('My router lights are red'),
        cpe ? findsOneWidget : findsNothing,
      );
      await cubit.close();
    }
  });

  testWidgets(
    'absent or invalid WhatsApp leaves an accessible secondary ticket',
    (tester) async {
      await locator.reset();
      locator.registerLazySingleton<SupportMessageRepository>(
        () => MockSupportMessageRepository(),
      );
      addTearDown(locator.reset);
      for (final number in <String?>[null, '270000000000']) {
        final cubit = SupportCubit(MockSupportRepository());
        await pumpThemed(
          tester,
          BlocProvider.value(
            value: cubit,
            child: SupportPage(whatsAppNumber: number),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('WhatsApp'), findsNothing);
        expect(
          find.widgetWithText(OutlinedButton, 'Submit a ticket'),
          findsOneWidget,
        );
        await tester.tap(find.text('Submit a ticket'));
        await tester.pumpAndSettle();
        expect(find.text('Message support'), findsOneWidget);
        await tester.tapAt(const Offset(10, 10)); // the barrier closes the sheet
        await tester.pumpAndSettle();
        expect(find.text('Message support'), findsNothing);
        await cubit.close();
      }
    },
  );

  testWidgets(
    'configured WhatsApp is primary and launches only the configured URL',
    (tester) async {
      final opened = <String>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            opened.add((call.arguments as Map)['url'] as String);
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final cubit = SupportCubit(MockSupportRepository());
      addTearDown(cubit.close);
      await pumpThemed(
        tester,
        BlocProvider.value(
          value: cubit,
          child: const SupportPage(whatsAppNumber: '+27825550100'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ElevatedButton, 'WhatsApp'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Submit a ticket'),
        findsOneWidget,
      );
      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();
      expect(opened, hasLength(1));
      expect(Uri.parse(opened.single).path, '/27825550100');
      expect(
        Uri.parse(opened.single).queryParameters['text'],
        lookupAppLocalizations(const Locale('en')).supportChatGreeting,
      );
      final context = tester.element(find.byType(SupportPage));
      await openWhatsAppChat(context);
      expect(
        opened,
        hasLength(1),
        reason: 'Shared action cannot invent a contact',
      );
    },
  );

  for (final lang in ['en', 'zu', 'af']) {
    testWidgets('hotspot help and both contact buttons fit 200% in $lang', (
      tester,
    ) async {
      final cubit = SupportCubit(MockSupportRepository());
      addTearDown(cubit.close);
      await pumpThemed(
        tester,
        BlocProvider.value(
          value: cubit,
          child: const SupportPage(whatsAppNumber: '+27825550100'),
        ),
        locale: Locale(lang),
        textScale: 2,
        size: const Size(360, 690),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final l10n = lookupAppLocalizations(Locale(lang));
      expect(
        find.widgetWithText(ElevatedButton, l10n.supportWhatsApp),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.hotspotFaq1Question));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
