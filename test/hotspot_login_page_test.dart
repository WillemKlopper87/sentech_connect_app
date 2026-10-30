import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/hotspot_login/domain/entities/login_token.dart';
import 'package:sentech_connect_app/features/hotspot_login/domain/repositories/hotspot_login_repository.dart';
import 'package:sentech_connect_app/features/hotspot_login/presentation/bloc/hotspot_login_cubit.dart';
import 'package:sentech_connect_app/features/hotspot_login/presentation/pages/get_online_page.dart';
import 'package:sentech_connect_app/features/hotspot_login/presentation/widgets/get_online_entry.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant_directory.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/shared/widgets/secure_screen.dart';

import 'helpers/fixtures.dart';
import 'helpers/pump_themed.dart';

final _now = DateTime.utc(2026, 10, 30, 12);

class _Repo implements HotspotLoginRepository {
  _Repo(this.results);
  final List<Either<Failure, LoginToken>> results;
  var calls = 0;

  @override
  Future<Either<Failure, LoginToken>> createLoginToken() async => results[calls++ < results.length ? calls - 1 : results.length - 1];
}

LoginToken _token(int n, {Duration life = const Duration(seconds: 300)}) =>
    LoginToken(username: 'c.user$n', password: 'secret$n', expiresAt: _now.add(life));

class _Tenants implements TenantRepository {
  _Tenants(this.config);
  final AppConfig config;
  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async => Right(config);
  @override
  Future<Either<Failure, TenantDirectory>> listTenants() async => Right(TenantDirectory([config.tenant]));
}

Future<TenantCubit> _tenant({required bool radius}) async {
  final base = fixtureMap('app_config.json');
  final config = AppConfig.fromJson({
    ...base,
    'feature_flags': {...Map<String, Object?>.from(base['feature_flags']! as Map), 'hotspot_radius': radius},
  });
  final cubit = TenantCubit(
    repository: _Tenants(config),
    context: TenantContext(),
    preferences: InMemoryTenantPreferences(slug: 'acme-wifi'),
  );
  await cubit.bootstrap();
  return cubit;
}

Pass _pass({PassStatus status = PassStatus.active, Duration left = const Duration(hours: 2)}) => Pass(
  id: 'p',
  productName: 'Day Pass',
  status: status,
  startsAt: _now.subtract(const Duration(hours: 1)),
  expiresAt: _now.add(left),
  durationMinutes: 180,
  maxDevices: 1,
);

void main() {
  late List<MethodCall> clipboard;
  String? clipboardText;

  setUp(() {
    clipboard = [];
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      clipboard.add(call);
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'] as String?;
      } else if (call.method == 'Clipboard.getData') {
        return {'text': clipboardText};
      }
      return null;
    });
    ScreenSecurity.resetForTest();
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<HotspotLoginCubit> pumpPage(
    WidgetTester tester,
    _Repo repo, {
    UrlOpener? open,
    Duration clipboardDelay = const Duration(seconds: 60),
  }) async {
    var now = _now;
    final cubit = HotspotLoginCubit(repo, now: () => now, autoTick: false);
    addTearDown(cubit.close);
    await pumpThemed(
      tester,
      BlocProvider.value(
        value: cubit,
        child: GetOnlinePage(openUrl: open ?? (_) async => true, clipboardDelay: clipboardDelay),
      ),
    );
    return cubit;
  }

  testWidgets('explains connecting first, then shows masked password with reveal; the screen is capture-protected', (tester) async {
    final cubit = await pumpPage(tester, _Repo([Right(_token(1))]));
    expect(find.textContaining('First connect to your provider'), findsOneWidget);
    expect(find.byType(SecureScreen), findsOneWidget);
    expect(ScreenSecurity.isProtected, isTrue);
    await tester.tap(find.byKey(const Key('hotspot-login-get')));
    await tester.pump();
    await tester.pump();
    expect(find.text('c.user1'), findsOneWidget);
    expect(find.text('secret1'), findsNothing);
    expect(find.text('•' * 10), findsOneWidget);
    await tester.tap(find.byKey(const Key('hotspot-login-reveal')));
    await tester.pump();
    expect(find.text('secret1'), findsOneWidget);
    expect(find.text('Valid for 05:00'), findsOneWidget);
    expect(cubit.state.status, HotspotLoginStatus.ready);
  });

  testWidgets('copying puts the value on the clipboard and clears it after the delay, only if unchanged', (tester) async {
    await pumpPage(tester, _Repo([Right(_token(1))]), clipboardDelay: const Duration(seconds: 60));
    await tester.tap(find.byKey(const Key('hotspot-login-get')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('hotspot-login-copy-password')));
    await tester.pump();
    expect(clipboardText, 'secret1');
    await tester.pump(const Duration(seconds: 59));
    expect(clipboardText, 'secret1');
    await tester.pump(const Duration(seconds: 2));
    expect(clipboardText, '');

    // Something else copied meanwhile is left alone.
    await tester.tap(find.byKey(const Key('hotspot-login-copy-username')));
    await tester.pump();
    expect(clipboardText, 'c.user1');
    clipboardText = 'something the customer copied';
    await tester.pump(const Duration(seconds: 61));
    expect(clipboardText, 'something the customer copied');
  });

  testWidgets('leaving the screen clears a copied secret at once', (tester) async {
    await pumpPage(tester, _Repo([Right(_token(1))]));
    await tester.tap(find.byKey(const Key('hotspot-login-get')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('hotspot-login-copy-password')));
    await tester.pump();
    expect(clipboardText, 'secret1');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(clipboardText, '');
    expect(ScreenSecurity.isProtected, isFalse);
  });

  testWidgets('countdown ends in "Get new login details", which issues another login', (tester) async {
    var now = _now;
    final repo = _Repo([Right(_token(1)), Right(_token(2, life: const Duration(seconds: 900)))]);
    final cubit = HotspotLoginCubit(repo, now: () => now, autoTick: false);
    addTearDown(cubit.close);
    await pumpThemed(tester, BlocProvider.value(value: cubit, child: const GetOnlinePage()));
    await tester.tap(find.byKey(const Key('hotspot-login-get')));
    await tester.pump();
    await tester.pump();
    now = _now.add(const Duration(seconds: 65));
    cubit.tick();
    await tester.pump();
    await tester.pump();
    expect(find.text('Valid for 03:55'), findsOneWidget);
    now = _now.add(const Duration(seconds: 301));
    cubit.tick();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('hotspot-login-expired')), findsOneWidget);
    expect(find.text('secret1'), findsNothing);
    await tester.tap(find.byKey(const Key('hotspot-login-new')));
    await tester.pump();
    await tester.pump();
    expect(find.text('c.user2'), findsOneWidget);
    expect(repo.calls, 2);
  });

  testWidgets('Open Wi-Fi login page opens the plain-HTTP trigger page in the external browser', (tester) async {
    final opened = <Uri>[];
    await pumpPage(
      tester,
      _Repo([Right(_token(1))]),
      open: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    await tester.tap(find.byKey(const Key('hotspot-login-get')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('hotspot-login-portal')));
    await tester.pump();
    expect(opened.single.toString(), 'http://neverssl.com');
    expect(opened.single.scheme, 'http');
  });

  testWidgets('a browser that cannot be opened says so', (tester) async {
    await pumpPage(tester, _Repo([Right(_token(1))]), open: (_) async => false);
    await tester.tap(find.byKey(const Key('hotspot-login-get')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('hotspot-login-portal')));
    await tester.pump();
    expect(find.text('We could not open your browser.'), findsOneWidget);
  });

  group('failure states', () {
    final cases = <(Failure, String)>[
      (const NoActiveEntitlementFailure(), 'You need an active pass to get online.'),
      (
        const ControllerNotSupportedFailure(),
        'One-tap login is not supported at this hotspot. Connect from the Wi-Fi login page instead.',
      ),
      (const RateLimitedFailure(), 'Too many attempts. Please wait and try again.'),
      (const NetworkFailure(), "You're offline. Check your connection and try again."),
    ];
    for (final (failure, text) in cases) {
      testWidgets('${failure.runtimeType} is explained and can be retried', (tester) async {
        final repo = _Repo([Left(failure), Right(_token(1))]);
        await pumpPage(tester, repo);
        await tester.tap(find.byKey(const Key('hotspot-login-get')));
        await tester.pump();
        await tester.pump();
        expect(find.text(text), findsOneWidget);
        expect(find.text('secret1'), findsNothing);
        await tester.tap(find.text('Retry'));
        await tester.pump();
        await tester.pump();
        expect(find.text('c.user1'), findsOneWidget);
      });
    }
  });

  group('entry button', () {
    Future<void> pumpEntry(WidgetTester tester, {required bool? radius, required List<Pass> passes}) async {
      final tenant = radius == null ? null : await _tenant(radius: radius);
      if (tenant != null) addTearDown(tenant.close);
      final entry = Scaffold(body: GetOnlineEntry(passes: passes, now: _now));
      await pumpThemed(tester, tenant == null ? entry : BlocProvider<TenantCubit>.value(value: tenant, child: entry));
    }

    testWidgets('shown with an active pass and the flag on', (tester) async {
      await pumpEntry(tester, radius: true, passes: [_pass()]);
      expect(find.byKey(const Key('get-online-entry')), findsOneWidget);
      expect(find.text('Get online now'), findsOneWidget);
    });

    testWidgets('hidden when the flag is off', (tester) async {
      await pumpEntry(tester, radius: false, passes: [_pass()]);
      expect(find.byKey(const Key('get-online-entry')), findsNothing);
    });

    testWidgets('hidden with no tenant config at all', (tester) async {
      await pumpEntry(tester, radius: null, passes: [_pass()]);
      expect(find.byKey(const Key('get-online-entry')), findsNothing);
    });

    for (final (name, passes) in <(String, List<Pass>)>[
      ('no passes', const []),
      ('suspended', [_pass(status: PassStatus.suspended)]),
      ('expired', [_pass(status: PassStatus.expired)]),
      ('active but past its end', [_pass(left: const Duration(seconds: -1))]),
      ('scheduled', [_pass(status: PassStatus.scheduled)]),
      ('exhausted', [_pass(status: PassStatus.exhausted)]),
    ]) {
      testWidgets('hidden when the customer has $name', (tester) async {
        await pumpEntry(tester, radius: true, passes: passes);
        expect(find.byKey(const Key('get-online-entry')), findsNothing);
      });
    }
  });
}
