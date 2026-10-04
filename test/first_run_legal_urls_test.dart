import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'helpers/first_run_tenant.dart';

void main() {
  test('public Terms/privacy URLs survive app config cache serialization', () {
    final branding = TenantBranding.fromJson({
      'legal_urls': {
        'terms': 'https://legal.example.test/terms?v=2',
        'privacy': 'https://legal.example.test/privacy',
        'unknown': 'https://legal.example.test/other',
      },
    });
    expect(
      branding.termsUrl,
      Uri.parse('https://legal.example.test/terms?v=2'),
    );
    expect(
      branding.privacyUrl,
      Uri.parse('https://legal.example.test/privacy'),
    );
    final config = FirstRunTenantRepository(
      cpe: false,
      branding: branding,
    ).config;
    final restored = AppConfig.fromJson(
      jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
    );
    expect(restored, config);
    expect(branding.toJson()['legal_urls'], {
      'terms': 'https://legal.example.test/terms?v=2',
      'privacy': 'https://legal.example.test/privacy',
    });
  });

  for (final value in [
    null,
    42,
    '',
    'http://legal.example.test/t',
    'javascript:alert(1)',
    'https:///terms',
    'https://user:password@legal.example.test/t',
    'https://legal.example.test/has space',
    'https://legal.example.test/${'a' * 500}',
  ]) {
    test('invalid optional legal URL is ignored: $value', () {
      final branding = TenantBranding.fromJson({
        'legal_urls': {'terms': value, 'privacy': value},
      });
      expect(branding.termsUrl, isNull);
      expect(branding.privacyUrl, isNull);
      expect(branding.toJson().containsKey('legal_urls'), isFalse);
    });
  }
  test('missing or malformed legal URLs do not manufacture a destination', () {
    for (final json in <Map<String, Object?>>[
      {},
      {'legal_urls': null},
      {'legal_urls': 'https://legal.example.test'},
      {'legal_urls': []},
    ]) {
      expect(TenantBranding.fromJson(json), const TenantBranding());
    }
  });
}
