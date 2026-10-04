import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/core/privacy/privacy_constants.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/first_run_tenant.dart';
import 'helpers/pump_themed.dart';
import 'helpers/screens.dart';
import 'helpers/test_setup.dart';

void main() {
  setUpAppTests();

  for (final privacyUrl in [
    'https://legal.example.test/tenant-privacy',
    'http://unsafe.example.test/privacy',
  ]) {
    testWidgets(
      'Account opens the consent policy destination for $privacyUrl',
      (tester) async {
        final tenant = await firstRunTenant(
          cpe: false,
          branding: TenantBranding.fromJson({
            'legal_urls': {'privacy': privacyUrl},
          }),
        );
        addTearDown(tenant.close);
        final opened = <String>[];
        const channel = MethodChannel('plugins.flutter.io/url_launcher');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              opened.add((call.arguments as Map)['url'] as String);
              return true;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        await pumpThemed(
          tester,
          BlocProvider<TenantCubit>.value(
            value: tenant,
            child: buildScreenForTest(
              'account',
              lookupAppLocalizations(const Locale('en')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Privacy policy'), 200);
        await tester.ensureVisible(find.text('Privacy policy'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Privacy policy'));
        await tester.pump();
        expect(opened, [
          privacyUrl.startsWith('https:') ? privacyUrl : privacyPolicyUrl,
        ]);
      },
    );
  }
}
