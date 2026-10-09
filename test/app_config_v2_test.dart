import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';

import 'helpers/fixtures.dart';

Map<String, Object?> v2([Map<String, Object?> extra = const {}]) =>
    {...fixtureMap('app_config.json'), ...extra};

/// What an API older than v2 sends: the fixture without the v2 members.
Map<String, Object?> v1() => fixtureMap('app_config.json')
  ..remove('modules')
  ..remove('collection_mode_public');

void main() {
  test('the current API shape: modules and buy in app are read exactly as sent', () {
    final c = AppConfig.fromJson(v2());
    expect(c.modules.reported, isTrue);
    expect(c.isModuleOn(AppModuleKeys.vouchers), isTrue);
    expect(c.isModuleOn(AppModuleKeys.subscriberBilling), isTrue);
    expect(c.isModuleOn(AppModuleKeys.tickets), isFalse);
    expect(c.isModuleOn(AppModuleKeys.credits), isFalse);
    expect(c.isModuleOn(AppModuleKeys.wifiAware), isFalse);
    expect(c.buyInApp, isTrue);
  });

  test('v1 server: modules not reported, vouchers follows the flag, buy in app on', () {
    final c = AppConfig.fromJson(v1());
    expect(c.modules.reported, isFalse);
    expect(c.isModuleOn(AppModuleKeys.vouchers), isTrue);
    expect(c.isModuleOn(AppModuleKeys.credits), isFalse);
    expect(c.buyInApp, isTrue);
    expect(c.support.email, 'help@acme.example');
  });

  test('v2 server: modules win over flags; unknown and non-bool entries are off', () {
    final c = AppConfig.fromJson(v2({
      'modules': {'vouchers': false, 'credits': true, 'zones': 'yes'},
      'collection_mode_public': {'buy_in_app': false},
    }));
    expect(c.modules.reported, isTrue);
    expect(c.isModuleOn(AppModuleKeys.vouchers), isFalse);
    expect(c.isModuleOn(AppModuleKeys.credits), isTrue);
    expect(c.isModuleOn('zones'), isFalse);
    expect(c.buyInApp, isFalse);
  });

  test('invalid support channels are dropped, not shown', () {
    final c = AppConfig.fromJson(v2({'support': {'email': 'javascript:alert(1)', 'phone': '<b>1</b>'}}));
    expect(c.support.email, isNull);
    expect(c.support.phone, isNull);
  });

  test('the offline cache round-trips every v2 field', () {
    final c = AppConfig.fromJson(v2({
      'modules': {'vouchers': true, 'tickets': false},
      'collection_mode_public': {'buy_in_app': false},
    }));
    final back = AppConfig.fromJson(
        Map<String, Object?>.from(jsonDecode(jsonEncode(c.toJson())) as Map));
    expect(back, c);
    expect(back.featureFlags.vouchers, isTrue);
  });

  test('without(key) turns one module off and keeps the rest', () {
    final m = AppModules.fromJson({'vouchers': true, 'credits': true}).without('vouchers');
    expect(m.isOn('vouchers'), isFalse);
    expect(m.isOn('credits'), isTrue);
  });
}
