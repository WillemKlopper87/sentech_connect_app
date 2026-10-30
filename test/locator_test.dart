import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_catalog_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/catalog_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/http_auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_invoice_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_kyc_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/invoice_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/kyc_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';
import 'package:sentech_connect_app/features/support/data/repositories/http_support_message_repository.dart';
import 'package:sentech_connect_app/features/support/data/repositories/mock_support_message_repository.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_message_repository.dart';
import 'package:sentech_connect_app/features/tenant/data/repositories/http_tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/data/repositories/mock_tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/voucher_scanner/data/repositories/http_voucher_repository.dart';
import 'package:sentech_connect_app/features/voucher_scanner/data/repositories/mock_voucher_repository.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/repositories/voucher_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/data/repositories/http_wifi_hotspots_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/wifi_hotspots_repository.dart';

import 'helpers/test_setup.dart';

/// Every `register...<Interface>(...)` call (lazy/eager singleton, factory,
/// closure or instance, arrow or block closure, `const`, named constructors)
/// -> the implementation class it builds. A registration this pattern cannot
/// read FAILS the test instead of being silently ignored, so a new style of
/// registration means extending [_registration] here, never a hole.
final _registration = RegExp(
  r'\bregister\w*<(\w+)>\(\s*(?:\(\)\s*(?:async\s*)?(?:=>|\{\s*return)\s*)?(?:(?:const|new)\s+)?(\w+)',
);
final _anyRegistration = RegExp(r'\bregister\w*\s*[<(]');

Map<String, String> parseRegistrations(String source) {
  final matches = _registration.allMatches(source).toList();
  expect(
    matches.length,
    _anyRegistration.allMatches(source).length,
    reason:
        'a registration in locator.dart is not readable by the allow-list test (extend _registration)',
  );
  return {for (final m in matches) m.group(1)!: m.group(2)!};
}

void main() {
  final prod = AppEnvironment.resolve(
    flavor: 'prod',
    apiBaseUrl: 'https://api.example.test',
    isDebug: false,
  );

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await locator.reset();
  });

  test('demo wires mocks and never creates an API client', () {
    setupLocator();
    registerTestFakes();
    expect(locator<TenantRepository>(), isA<MockTenantRepository>());
    expect(locator.isRegistered<ApiClient>(), isFalse);
  });

  test('prod wires the API client and HTTP repositories', () {
    setupLocator(environment: prod);
    registerTestFakes();
    expect(locator<ApiClient>(), isA<ApiClient>());
    expect(locator<TenantRepository>(), isA<HttpTenantRepository>());
    expect(locator<AuthRepository>(), isA<HttpAuthRepository>());
    expect(locator<CatalogRepository>(), isA<HttpCatalogRepository>());
    expect(locator<CheckoutRepository>(), isA<HttpCheckoutRepository>());
    expect(locator<VoucherRepository>(), isA<HttpVoucherRepository>());
    expect(locator<WifiHotspotsRepository>(), isA<HttpWifiHotspotsRepository>());
  });

  test('prod sends real support messages', () {
    setupLocator(environment: prod);
    registerTestFakes();
    expect(locator<SupportMessageRepository>(), isA<HttpSupportMessageRepository>());
  });

  test('demo sends no real support message', () {
    setupLocator();
    registerTestFakes();
    expect(locator<SupportMessageRepository>(), isA<MockSupportMessageRepository>());
  });

  test('prod reads real subscriber plans, account and services', () {
    setupLocator(environment: prod);
    registerTestFakes();
    expect(locator<SubscriberPlansRepository>(), isA<HttpSubscriberPlansRepository>());
    expect(locator<SubscriberRepository>(), isA<HttpSubscriberRepository>());
  });

  test('demo serves mock subscriber data and they are not in stillMockInProd', () {
    setupLocator();
    registerTestFakes();
    expect(locator<SubscriberPlansRepository>(), isA<MockSubscriberPlansRepository>());
    expect(locator<SubscriberRepository>(), isA<MockSubscriberRepository>());
    expect(stillMockInProd, isNot(contains(SubscriberPlansRepository)));
    expect(stillMockInProd, isNot(contains(SubscriberRepository)));
    expect(locator<InvoiceRepository>(), isA<MockInvoiceRepository>());
    expect(locator<KycRepository>(), isA<MockKycRepository>());
  });

  test('the invented account/router mock is gone: no AccountRepository anywhere', () {
    final names = stillMockInProd.map((t) => t.toString());
    expect(names, isNot(contains('AccountRepository')));
    expect(File('lib/app/locator.dart').readAsStringSync(), isNot(contains('AccountRepository')));
  });

  test('demo keeps the mock voucher service', () {
    setupLocator();
    registerTestFakes();
    expect(locator<VoucherRepository>(), isA<MockVoucherRepository>());
  });

  test('repositories without a backend stay mock in prod (and are listed)', () {
    setupLocator(environment: prod);
    registerTestFakes();
    expect(stillMockInProd, isNotEmpty);
    for (final type in stillMockInProd) {
      final instance = locator.get<Object>(type: type);
      expect(
        instance.runtimeType.toString(),
        startsWith('Mock'),
        reason: '$type',
      );
    }
  });

  test('demo has no API client or token store either', () {
    setupLocator();
    registerTestFakes();
    expect(locator.isRegistered<ApiClient>(), isFalse);
    expect(locator.isRegistered<TokenStore>(), isFalse);
  });

  test(
    'prod flavor without an API base URL throws instead of registering mocks',
    () {
      expect(
        () => setupLocator(
          environment: const AppEnvironment(flavor: AppFlavor.prod),
        ),
        throwsA(isA<InvalidEnvironment>()),
      );
      // Nothing half-registered.
      expect(locator.isRegistered<AppEnvironment>(), isFalse);
      expect(locator.isRegistered<TenantRepository>(), isFalse);
    },
  );

  group('registration parsing (the allow-list must not be bypassable by style)', () {
    const supported = '''
      locator.registerLazySingleton<A>(() => MockA(locator()));
      locator.registerLazySingleton<B>(
        () => MockB(
          locator(),
        ),
      );
      locator.registerLazySingleton<C>(() =>
          MockC());
      locator.registerLazySingleton<D>(() => const MockD());
      locator.registerLazySingleton<E>(() => MockE.named(locator()));
      locator.registerFactory<F>(() => MockF());
      locator.registerSingleton<G>(MockG(locator()));
      locator.registerSingleton<H>(const MockH());
      locator.registerLazySingleton<I>(() { return MockI(); });
      locator.registerLazySingleton<J>(() async => LocalJ());
    ''';

    test(
      'reads lazy singletons, factories and instances in every common form',
      () {
        expect(parseRegistrations(supported), {
          'A': 'MockA',
          'B': 'MockB',
          'C': 'MockC',
          'D': 'MockD',
          'E': 'MockE',
          'F': 'MockF',
          'G': 'MockG',
          'H': 'MockH',
          'I': 'MockI',
          'J': 'LocalJ',
        });
      },
    );

    test(
      'a registration without an explicit interface type is flagged, not skipped',
      () {
        expect(
          () => parseRegistrations(
            'locator.registerLazySingleton(() => MockX());',
          ),
          throwsA(isA<TestFailure>()),
        );
      },
    );

    test(
      'an unsupported shape (generic factory with parameters) is flagged, not skipped',
      () {
        expect(
          () => parseRegistrations(
            'locator.registerFactoryParam<K, String, void>((p, _) => MockK(p));',
          ),
          throwsA(isA<TestFailure>()),
        );
      },
    );

    test(
      'a swap to an Http implementation with multi-line arguments stays trivial',
      () {
        expect(
          parseRegistrations('''
          locator.registerLazySingleton<AuthRepository>(
            () => HttpAuthRepository(locator(), tokens: locator(), tenant: locator()),
          );
        '''),
          {'AuthRepository': 'HttpAuthRepository'},
        );
      },
    );

    test('the real locator source is fully readable', () {
      final source = File('lib/app/locator.dart').readAsStringSync();
      expect(parseRegistrations(source).length, greaterThan(15));
    });
  });

  group('prod allow-list of mocks', () {
    // The (interface, implementation) pairs registered for prod, read from
    // the source so a newly added Mock*/Local* registration cannot slip past.
    Map<String, String> prodRegistrations() {
      final source = File(
        'lib/app/locator.dart',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      final stillMockStart = source.indexOf(
        'void _registerStillMockRepositories',
      );
      final demoStart = source.indexOf('void _registerDemoRepositories');
      final prodStart = source.indexOf('void _registerProdRepositories');
      expect(stillMockStart, greaterThan(0));
      expect(demoStart, greaterThan(stillMockStart));
      expect(prodStart, greaterThan(demoStart));
      final relevant =
          source.substring(stillMockStart, demoStart) +
          source.substring(prodStart);
      return parseRegistrations(relevant);
    }

    bool isMockLike(String implementation) =>
        implementation.startsWith('Mock') || implementation.startsWith('Local');

    test(
      'every Mock*/Local* repository registered in prod is on an explicit list',
      () {
        final allowed = {
          ...stillMockInProd,
          ...mockUntilLaterTasks,
        }.map((t) => t.toString()).toSet();
        final registrations = prodRegistrations();
        expect(registrations.length, greaterThan(10));
        final unlisted = [
          for (final e in registrations.entries)
            if (isMockLike(e.value) && !allowed.contains(e.key))
              '${e.key} -> ${e.value}',
        ];
        expect(
          unlisted,
          isEmpty,
          reason: 'mock in prod but not in stillMockInProd/mockUntilLaterTasks',
        );
      },
    );

    test(
      'every listed type really is still a mock in prod (stale entries fail)',
      () {
        setupLocator(environment: prod);
        registerTestFakes();
        for (final type in [...stillMockInProd, ...mockUntilLaterTasks]) {
          final name = locator.get<Object>(type: type).runtimeType.toString();
          expect(
            name.startsWith('Mock') || name.startsWith('Local'),
            isTrue,
            reason: '$type is now $name: remove it from the list',
          );
        }
      },
    );

    test('the two lists do not overlap', () {
      expect(
        stillMockInProd.toSet().intersection(mockUntilLaterTasks.toSet()),
        isEmpty,
      );
    });

    test('tenant is real (on neither list) in prod', () {
      expect([
        ...stillMockInProd,
        ...mockUntilLaterTasks,
      ], isNot(contains(TenantRepository)));
      setupLocator(environment: prod);
      registerTestFakes();
      expect(locator<TenantRepository>(), isA<HttpTenantRepository>());
    });
  });
}
