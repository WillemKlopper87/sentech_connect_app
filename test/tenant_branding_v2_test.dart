import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';

void main() {
  test('reads v2 colours, alt text and every legal link', () {
    final b = TenantBranding.fromJson({
      'primary_color': '#123456', 'secondary_color': '#00AA55', 'accent_color': '#ff8800',
      'logo_alt': '  Acme WiFi logo ', 'app_display_name': 'Acme WiFi',
      'legal_urls': {'terms': 'https://a.example/t', 'cooling-off': 'https://a.example/c',
        'service-charter': 'https://a.example/s', 'complaints': 'https://a.example/k',
        'paia': 'https://a.example/p'},
    });
    expect(b.secondaryColor, const Color(0xFF00AA55));
    expect(b.accentColor, const Color(0xFFFF8800));
    expect(b.logoAlt, 'Acme WiFi logo');
    expect(b.appDisplayName, 'Acme WiFi');
    expect(b.complaintsUrl, Uri.parse('https://a.example/k'));
    expect(b.paiaUrl, Uri.parse('https://a.example/p'));
  });

  test('branding cannot smuggle code or unsafe links', () {
    final b = TenantBranding.fromJson({
      'secondary_color': 'red; background:url(x)', 'accent_color': '#12345',
      'logo_url': 'data:image/png;base64,AAAA',
      'logo_alt': 'x' * 121, 'app_display_name': '\u202Eevil',
      'legal_urls': {'complaints': 'javascript:alert(1)', 'paia': 'http://a.example/p',
        'cooling-off': 'https://user:pw@a.example/c'},
    });
    expect(b.secondaryColor, isNull);
    expect(b.accentColor, isNull);
    expect(b.logoUrl, isNull);
    expect(b.logoAlt, isNull);
    expect(b.appDisplayName, 'evil');
    expect(b.complaintsUrl, isNull);
    expect(b.paiaUrl, isNull);
    expect(b.coolingOffUrl, isNull);
  });

  test('round-trips through toJson for the offline cache', () {
    final b = TenantBranding.fromJson({'secondary_color': '#00aa55', 'logo_alt': 'Logo',
      'legal_urls': {'complaints': 'https://a.example/k'}});
    expect(TenantBranding.fromJson(b.toJson()), b);
  });
}
