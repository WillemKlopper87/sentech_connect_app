import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/app/theme/app_theme.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/voucher_scanner/data/repositories/http_voucher_repository.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/repositories/voucher_repository.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/pages/voucher_result_sheet.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/pages/voucher_scanner_page.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/first_run_tenant.dart';
import 'helpers/test_setup.dart';

void main() {
  setUpAppTests();

  for (final signOut in [true, false]) {
    for (final inEntry in [true, false]) {
      testWidgets(
        '${signOut ? 'signout' : 'tenant picker'} removes ${inEntry ? 'entry text' : 'uncertain retry'}',
        (tester) async {
          final harness = ApiHarness();
          await harness.signIn();
          harness.adapter.on(
            'POST',
            HttpVoucherRepository.path,
            (_) => const FakeReply.error(DioExceptionType.connectionError),
          );
          final vouchers = HttpVoucherRepository(harness.api);
          locator.registerSingleton<VoucherRepository>(vouchers);
          final tenant = await firstRunTenant(cpe: false);
          final auth = AuthCubit(
            locator(),
            sessionStore: locator(),
            biometrics: locator(),
            wiper: locator(),
            initial: const AuthState(
              status: AuthStatus.success,
              user: User(id: 'usr', fullName: 'Lindiwe', mobileNumber: '081'),
            ),
          );
          final router = AppRouter(
            auth,
            tenantCubit: tenant,
            initialLocation: AppRoutes.main,
          );
          addTearDown(() async {
            router.dispose();
            await auth.close();
            await tenant.close();
          });
          await tester.pumpWidget(
            MultiBlocProvider(
              providers: [
                BlocProvider.value(value: auth),
                BlocProvider.value(value: tenant),
                BlocProvider(create: (_) => CartCubit()),
                BlocProvider(create: (_) => ThemeCubit()),
                BlocProvider(create: (_) => LocaleCubit()),
              ],
              child: MaterialApp.router(
                theme: AppTheme.light(),
                routerConfig: router.router,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Scan'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Type the code instead'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'abcd2345efgq');
          final fieldController = tester
              .widget<TextField>(find.byType(TextField))
              .controller!;
          if (!inEntry) {
            await tester.testTextInput.receiveAction(TextInputAction.done);
            await tester.pumpAndSettle();
            expect(vouchers.heldCodeForTest, 'ABCD2345EFGQ');
            expect(find.text("You're offline"), findsOneWidget);
          }
          if (signOut) {
            await auth.logOut();
          } else {
            await tenant.openPicker();
          }
          await tester.pumpAndSettle();
          expect(
            router.router.state.uri.path,
            signOut ? AppRoutes.login : AppRoutes.tenantPicker,
          );
          expect(vouchers.heldCodeForTest, isNull);
          expect(find.byType(VoucherScannerPage), findsNothing);
          expect(find.byType(VoucherResultSheet), findsNothing);
          expect(find.text('ABCD-2345-EFGQ'), findsNothing);
          // The disposed field has been emptied before its controller closes.
          if (inEntry) expect(fieldController.text, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
