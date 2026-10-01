import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/app/theme/app_colors.dart';
import 'package:sentech_connect_app/app/theme/app_theme.dart';
import 'package:sentech_connect_app/app/theme/color_contrast.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/features/tenant/presentation/pages/tenant_picker_page.dart';
import 'package:sentech_connect_app/features/tenant/presentation/pages/update_required_page.dart';

const _sentech = Tenant(slug: 'sentech', name: 'Sentech', type: 'operator');
const _acme = Tenant(
  slug: 'acme-wifi',
  name: 'Acme Wi-Fi',
  type: 'reseller',
  branding: TenantBranding(primaryColor: Color(0xFF123456)),
);

class _TwoTenants implements TenantRepository {
  @override
  Future<Either<Failure, List<Tenant>>> listTenants() async => const Right([_sentech, _acme]);

  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async => Right(AppConfig(
        tenant: slug == 'sentech' ? _sentech : _acme,
        minAppVersion: '1.0.0',
        featureFlags: FeatureFlags.demo,
        legal: const LegalVersions(terms: '2026-09-30', privacy: '2026-09-30'),
      ));
}

void main() {
  TenantCubit cubit({String? savedSlug, Future<void> Function()? onChanging}) => TenantCubit(
        repository: _TwoTenants(),
        context: TenantContext(),
        preferences: InMemoryTenantPreferences(slug: savedSlug),
        onTenantChanging: onChanging,
      );

  Future<void> pump(WidgetTester tester, TenantCubit c, Widget page) async {
    await tester.pumpWidget(BlocProvider.value(value: c, child: MaterialApp(home: page)));
    await tester.pumpAndSettle();
  }

  testWidgets('first run: picking a provider selects it without a sign-out prompt', (tester) async {
    final c = cubit();
    addTearDown(c.close);
    await c.bootstrap();
    await pump(tester, c, const TenantPickerPage());

    expect(find.text('Acme Wi-Fi'), findsOneWidget);
    expect(find.text('Reseller'), findsOneWidget);
    await tester.tap(find.text('Acme Wi-Fi'));
    await tester.pumpAndSettle();
    expect(find.text('Change provider?'), findsNothing);
    expect(c.state.config!.tenant.slug, 'acme-wifi');
  });

  testWidgets('switching from a current provider asks first, then signs out', (tester) async {
    var signOuts = 0;
    final c = cubit(savedSlug: 'sentech', onChanging: () async => signOuts++);
    addTearDown(c.close);
    await c.bootstrap();
    await c.openPicker();
    await pump(tester, c, const TenantPickerPage());

    await tester.tap(find.text('Acme Wi-Fi'));
    await tester.pumpAndSettle();
    expect(find.text('Change provider?'), findsOneWidget);
    await tester.tap(find.text('Switch'));
    await tester.pumpAndSettle();
    expect(signOuts, 1);
    expect(c.state.config!.tenant.slug, 'acme-wifi');
  });

  testWidgets('the update gate explains what to do', (tester) async {
    final c = cubit();
    addTearDown(c.close);
    await pump(tester, c, const UpdateRequiredPage());
    expect(find.text('Update required'), findsOneWidget);
  });

  test('tenant primary colour themes the app; defaults stay on brand', () {
    expect(AppTheme.light().colorScheme.primary, AppColors.sentechBlue);
    expect(AppTheme.light().colorScheme.onPrimary, Colors.white);
    expect(AppTheme.dark().colorScheme.onPrimary, AppColors.darkBlue);
    expect(AppTheme.light(primary: const Color(0xFF123456)).colorScheme.primary, const Color(0xFF123456));
    expect(AppTheme.dark(primary: const Color(0xFF123456)).colorScheme.primary, isNot(const Color(0xFF123456)));
  });

  group('server colours are made legible (R-m5)', () {
    test('every light primary reaches 4.5:1 on the page and has legible text on it', () {
      for (final colour in const [
        Color(0xFFFFFF00),
        Color(0xFFFFFFFF),
        Color(0xFF000000),
        Color(0xFF808080),
        Color(0xFF777777),
        Color(0xFFFFEE88),
        Color(0xFF00CC66),
        Color(0xFFFF7700),
      ]) {
        final scheme = AppTheme.light(primary: colour).colorScheme;
        expect(ColorContrast.ratio(scheme.primary, AppColors.lightBg), greaterThanOrEqualTo(4.5), reason: '$colour');
        expect(ColorContrast.ratio(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(4.5), reason: '$colour');
      }
    });

    test('every dark primary reaches 4.5:1 on navy and has legible text on it', () {
      for (final colour in const [
        Color(0xFFFFFF00),
        Color(0xFFFFFFFF),
        Color(0xFF000000),
        Color(0xFF808080),
        Color(0xFF123456),
      ]) {
        final scheme = AppTheme.dark(primary: colour).colorScheme;
        expect(ColorContrast.ratio(scheme.primary, AppColors.darkBlue), greaterThanOrEqualTo(4.5), reason: '$colour');
        expect(ColorContrast.ratio(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(4.5), reason: '$colour');
      }
    });

    test('a colour that is already legible is kept as is', () {
      expect(AppTheme.light(primary: const Color(0xFF123456)).colorScheme.primary, const Color(0xFF123456));
    });
  });

  testWidgets('Android back closes the picker and keeps the current provider', (tester) async {
    final c = cubit(savedSlug: 'sentech');
    addTearDown(c.close);
    await c.bootstrap();
    await c.openPicker();
    await pump(tester, c, const TenantPickerPage());
    expect(c.state.status, TenantStatus.needsSelection);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(c.state.status, TenantStatus.ready);
    expect(c.state.config!.tenant.slug, 'sentech');
  });

  testWidgets('the current provider is marked selected', (tester) async {
    final c = cubit(savedSlug: 'sentech');
    addTearDown(c.close);
    await c.bootstrap();
    await c.openPicker();
    await pump(tester, c, const TenantPickerPage());
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Sentech')).selected, isTrue);
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Acme Wi-Fi')).selected, isFalse);
  });

  group('tenantRedirect', () {
    Uri at(String path) => Uri.parse(path);

    test('waits (no redirect) while the tenant is loading', () {
      expect(tenantRedirect(const TenantState(status: TenantStatus.loading), at('/main')), isNull);
    });

    test('sends everything to the picker when a choice is needed or loading failed', () {
      expect(tenantRedirect(const TenantState(status: TenantStatus.needsSelection), at('/login')), AppRoutes.tenantPicker);
      expect(tenantRedirect(const TenantState(status: TenantStatus.failure), at('/main')), AppRoutes.tenantPicker);
      expect(tenantRedirect(const TenantState(status: TenantStatus.failure), at(AppRoutes.tenantPicker)), isNull);
    });

    test('gates every screen when the app is too old', () {
      expect(tenantRedirect(const TenantState(status: TenantStatus.updateRequired), at('/main')), AppRoutes.updateRequired);
    });

    test('leaves the picker / gate once the tenant is ready', () {
      expect(tenantRedirect(const TenantState(status: TenantStatus.ready), at(AppRoutes.tenantPicker)), AppRoutes.main);
      expect(tenantRedirect(const TenantState(status: TenantStatus.ready), at('/cart')), isNull);
    });
  });
}
