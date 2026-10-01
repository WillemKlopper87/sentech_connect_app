import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/features/tenant/data/repositories/http_tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/data/repositories/mock_tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';

import 'helpers/test_setup.dart';

void main() {
  final prod = AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: 'https://api.example.test', isDebug: false);

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
  });

  test('repositories without a backend stay mock in prod (and are listed)', () {
    setupLocator(environment: prod);
    registerTestFakes();
    expect(stillMockInProd, isNotEmpty);
    for (final type in stillMockInProd) {
      final instance = locator.get<Object>(type: type);
      expect(instance.runtimeType.toString(), startsWith('Mock'), reason: '$type');
    }
  });

  test('demo has no API client or token store either', () {
    setupLocator();
    registerTestFakes();
    expect(locator.isRegistered<ApiClient>(), isFalse);
    expect(locator.isRegistered<TokenStore>(), isFalse);
  });

  test('prod flavor without an API base URL throws instead of registering mocks', () {
    expect(
      () => setupLocator(environment: const AppEnvironment(flavor: AppFlavor.prod)),
      throwsA(isA<InvalidEnvironment>()),
    );
    // Nothing half-registered.
    expect(locator.isRegistered<AppEnvironment>(), isFalse);
    expect(locator.isRegistered<TenantRepository>(), isFalse);
  });

  group('prod allow-list of mocks', () {
    // The (interface, implementation) pairs registered for prod, read from
    // the source so a newly added Mock*/Local* registration cannot slip past.
    Map<String, String> prodRegistrations() {
      final source = File('lib/app/locator.dart').readAsStringSync().replaceAll('\r\n', '\n');
      final stillMockStart = source.indexOf('void _registerStillMockRepositories');
      final demoStart = source.indexOf('void _registerDemoRepositories');
      final prodStart = source.indexOf('void _registerProdRepositories');
      expect(stillMockStart, greaterThan(0));
      expect(demoStart, greaterThan(stillMockStart));
      expect(prodStart, greaterThan(demoStart));
      final relevant = source.substring(stillMockStart, demoStart) + source.substring(prodStart);
      final pattern = RegExp(r'registerLazySingleton<(\w+)>\(\s*\(\) => (\w+)\(');
      return {for (final m in pattern.allMatches(relevant)) m.group(1)!: m.group(2)!};
    }

    bool isMockLike(String implementation) => implementation.startsWith('Mock') || implementation.startsWith('Local');

    test('every Mock*/Local* repository registered in prod is on an explicit list', () {
      final allowed = {...stillMockInProd, ...mockUntilLaterTasks}.map((t) => t.toString()).toSet();
      final registrations = prodRegistrations();
      expect(registrations.length, greaterThan(10));
      final unlisted = [
        for (final e in registrations.entries)
          if (isMockLike(e.value) && !allowed.contains(e.key)) '${e.key} -> ${e.value}',
      ];
      expect(unlisted, isEmpty, reason: 'mock in prod but not in stillMockInProd/mockUntilLaterTasks');
    });

    test('every listed type really is still a mock in prod (stale entries fail)', () {
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
    });

    test('the two lists do not overlap', () {
      expect(stillMockInProd.toSet().intersection(mockUntilLaterTasks.toSet()), isEmpty);
    });

    test('tenant is real (on neither list) in prod', () {
      expect([...stillMockInProd, ...mockUntilLaterTasks], isNot(contains(TenantRepository)));
      setupLocator(environment: prod);
      registerTestFakes();
      expect(locator<TenantRepository>(), isA<HttpTenantRepository>());
    });
  });
}
