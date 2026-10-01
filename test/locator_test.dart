import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
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
}
