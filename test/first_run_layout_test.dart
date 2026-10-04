import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/auth/presentation/pages/login_page.dart';
import 'package:sentech_connect_app/features/auth/presentation/pages/registration_page.dart';
import 'package:sentech_connect_app/features/privacy/presentation/pages/legal_gate_page.dart';
import 'helpers/first_run_tenant.dart';
import 'helpers/pump_themed.dart';
import 'helpers/test_setup.dart';

void main() {
  setUpAppTests();
  for (final locale in [const Locale('en'), const Locale('zu')]) {
    for (final page in ['login', 'code', 'legal', 'registration']) {
      testWidgets('$page fits 360x690 at 2x in ${locale.languageCode}', (
        tester,
      ) async {
        final tenant = await firstRunTenant(
          cpe: true,
          branding: TenantBranding.fromJson({
            'legal_urls': {
              'terms': 'https://legal.example.test/terms',
              'privacy': 'https://legal.example.test/privacy',
            },
          }),
        );
        final auth = AuthCubit(
          locator(),
          sessionStore: locator(),
          biometrics: MockBiometricAuthenticator(),
          wiper: locator(),
          initial: page == 'legal'
              ? const AuthState(
                  status: AuthStatus.success,
                  user: User(
                    id: 'u1',
                    fullName: 'Name',
                    mobileNumber: '+27821234567',
                  ),
                  legal: LegalStatus.required,
                )
              : const AuthState(),
        );
        addTearDown(tenant.close);
        addTearDown(auth.close);
        await pumpThemed(
          tester,
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: auth),
              BlocProvider.value(value: tenant),
              BlocProvider(create: (_) => LocaleCubit(save: (_) async {})),
            ],
            child: switch (page) {
              'legal' => const LegalGatePage(),
              'registration' => const RegistrationPage(),
              _ => const LoginPage(),
            },
          ),
          size: const Size(360, 690),
          textScale: 2,
          locale: locale,
        );
        await tester.pumpAndSettle();
        if (page == 'code') {
          await tester.enterText(find.byType(TextField), '0821234567');
          await tester.ensureVisible(find.byType(ElevatedButton));
          await tester.tap(find.byType(ElevatedButton));
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
        }
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
