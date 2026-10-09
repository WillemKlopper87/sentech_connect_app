import 'package:fpdart/fpdart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/account/presentation/pages/account_page.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant_directory.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';

import 'helpers/pump_themed.dart';
import 'helpers/screens.dart';
import 'helpers/test_setup.dart';

class _Repo implements TenantRepository {
  _Repo(this.config);
  final AppConfig config;
  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async =>
      Right(config);
  @override
  Future<Either<Failure, TenantDirectory>> listTenants() async =>
      Right(TenantDirectory([config.tenant]));
}

Future<TenantCubit> _tenant({
  SupportChannels support = const SupportChannels(),
  String? whatsApp,
}) async {
  final cubit = TenantCubit(
    repository: _Repo(
      AppConfig(
        tenant: Tenant(
          slug: 'acme-wifi',
          name: 'Acme Wi-Fi',
          type: 'reseller',
          branding: TenantBranding(whatsAppNumber: whatsApp),
        ),
        minAppVersion: '1.0.0',
        featureFlags: FeatureFlags.demo,
        legal: const LegalVersions(terms: '2026-09-30', privacy: '2026-09-29'),
        support: support,
      ),
    ),
    context: TenantContext(),
    preferences: InMemoryTenantPreferences(),
  );
  await cubit.bootstrap();
  return cubit;
}

void main() {
  setUpAppTests();

  late LocaleCubit locale;
  late ThemeCubit theme;
  final opened = <String>[];

  setUp(() {
    opened.clear();
    locale = LocaleCubit();
    theme = ThemeCubit();
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'launch') {
            opened.add((call.arguments as Map)['url'] as String);
          }
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      locale.close();
      theme.close();
    });
  });

  Future<void> pumpAccount(
    WidgetTester tester, {
    TenantCubit? tenant,
    VoidCallback? onOpenPasses,
    VoidCallback? onChangeProvider,
    String? providerName,
  }) async {
    final auth = authForScreenTest(signedIn: true);
    addTearDown(auth.close);
    if (tenant != null) addTearDown(tenant.close);
    await pumpThemed(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: auth),
          BlocProvider.value(value: theme),
          BlocProvider.value(value: locale),
          if (tenant != null) BlocProvider.value(value: tenant),
        ],
        child: AccountPage(
          onOpenPasses: onOpenPasses ?? () {},
          onChangeProvider: onChangeProvider ?? () {},
          providerName: providerName,
        ),
      ),
      // Tall enough that the whole list is built, so row order can be read.
      size: const Size(390, 2400),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('first screen leads with passes and language, not radio lists', (
    tester,
  ) async {
    await pumpAccount(tester);
    expect(find.text('My passes'), findsOneWidget);
    expect(find.text('Orders & receipts'), findsNothing);
    expect(find.byType(RadioListTile<String>), findsNothing);
    expect(find.byType(RadioListTile<ThemeMode>), findsNothing);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    expect(find.text('isiZulu'), findsOneWidget);
    expect(find.text('Afrikaans'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('rows follow the ruled order', (tester) async {
    final tenant = await _tenant(
      support: const SupportChannels(email: 'help@acme.example'),
    );
    await pumpAccount(tester, tenant: tenant);
    final titles = [
      'Nomsa Dlamini',
      'My passes',
      'Language',
      'Appearance',
      'Data saver: fewer pictures and no animations',
      'Usage alerts',
      'Push notifications',
      'Contact Acme Wi-Fi',
      'Privacy policy',
      'Switch WiFi provider',
      'Log out',
    ];
    final tops = [
      for (final t in titles) tester.getTopLeft(find.text(t).first).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()), reason: tops.toString());
    expect(tops.toSet(), hasLength(titles.length));
  });

  testWidgets('My passes and Switch WiFi provider call back', (tester) async {
    var passes = 0;
    var switched = 0;
    await pumpAccount(
      tester,
      onOpenPasses: () => passes++,
      onChangeProvider: () => switched++,
    );
    await tester.tap(find.text('My passes'));
    await tester.tap(find.text('Switch WiFi provider'));
    expect((passes, switched), (1, 1));
  });

  testWidgets('Language sheet changes the app language', (tester) async {
    await pumpAccount(tester);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('isiZulu'));
    await tester.pumpAndSettle();
    expect(locale.state, const Locale('zu'));
    // The sheet closes once a choice is made.
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('Appearance sheet changes the theme mode', (tester) async {
    await pumpAccount(tester);
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(theme.state, ThemeMode.dark);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('contact sheet lists only valid channels', (tester) async {
    final tenant = await _tenant(
      support: const SupportChannels(email: 'help@acme.example'),
    );
    await pumpAccount(tester, tenant: tenant);
    await tester.tap(find.text('Contact Acme Wi-Fi'));
    await tester.pumpAndSettle();
    expect(find.text('help@acme.example'), findsOneWidget);
    expect(find.byIcon(Icons.call_outlined), findsNothing);
    expect(find.text('WhatsApp'), findsNothing);
  });

  testWidgets('contact actions open mailto, tel and wa.me', (tester) async {
    final tenant = await _tenant(
      support: const SupportChannels(
        email: 'help@acme.example',
        phone: '+27 11 000 0000',
      ),
      whatsApp: '+27821234567',
    );
    await pumpAccount(tester, tenant: tenant);
    for (final label in ['help@acme.example', '+27 11 000 0000', 'WhatsApp']) {
      await tester.tap(find.text('Contact Acme Wi-Fi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(opened, [
      'mailto:help@acme.example',
      'tel:+27110000000',
      'https://wa.me/27821234567',
    ]);
  });

  testWidgets('no valid channel hides the Contact row', (tester) async {
    final tenant = await _tenant(
      support: SupportChannels.fromJson({
        'email': 'javascript:alert(1)',
        'phone': 'not a phone',
      }),
      whatsApp: 'not a number',
    );
    await pumpAccount(tester, tenant: tenant);
    expect(find.textContaining('Contact'), findsNothing);
  });

  testWidgets('every row fits and scrolls at text scale 2 in isiZulu', (
    tester,
  ) async {
    final tenant = await _tenant(
      support: const SupportChannels(
        email: 'help@acme.example',
        phone: '+27 11 000 0000',
      ),
      whatsApp: '+27821234567',
    );
    addTearDown(tenant.close);
    final auth = authForScreenTest(signedIn: true);
    addTearDown(auth.close);
    await pumpThemed(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: auth),
          BlocProvider.value(value: theme),
          BlocProvider.value(value: locale),
          BlocProvider.value(value: tenant),
        ],
        child: AccountPage(onOpenPasses: () {}, onChangeProvider: () {}),
      ),
      locale: const Locale('zu'),
      textScale: 2,
      size: const Size(360, 690),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byIcon(Icons.swap_horiz),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final tile in tester.widgetList<ListTile>(find.byType(ListTile))) {
      expect(tile.minTileHeight, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('without a tenant there is no Contact row either', (
    tester,
  ) async {
    await pumpAccount(tester);
    expect(find.textContaining('Contact'), findsNothing);
  });
}
