import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/subscriber/subscriber_gate.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';

import 'helpers/fixtures.dart';

TenantState _state(Map<String, Object?>? modules) {
  final json = {...fixtureMap('app_config.json')};
  if (modules == null) {
    json.remove('modules');
  } else {
    json['modules'] = modules;
  }
  return TenantState(status: TenantStatus.ready, config: AppConfig.fromJson(json));
}

void main() {
  test('on only when the provider reports subscriber_billing true', () {
    expect(subscriberBillingOn(_state({'subscriber_billing': true})), isTrue);
  });

  test('off when the module is false, missing, or modules are not reported', () {
    expect(subscriberBillingOn(_state({'subscriber_billing': false})), isFalse);
    expect(subscriberBillingOn(_state({'vouchers': true})), isFalse);
    expect(subscriberBillingOn(_state(null)), isFalse);
  });

  test('off before any config is loaded', () {
    expect(subscriberBillingOn(const TenantState()), isFalse);
  });
}
