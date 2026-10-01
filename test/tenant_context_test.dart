import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';

void main() {
  // One slug rule for directory entries and for the context that puts the
  // slug into request bodies and query strings.
  final samples = [
    'sentech',
    'acme-wifi',
    'a1',
    'x' * 40,
    'x' * 41,
    'a',
    '',
    'Sentech',
    'has space',
    'a_b',
    'a/b',
    'a?x=1',
    'ünï',
    'a\nb',
    'ab\n',
  ];
  for (final slug in samples) {
    test('TenantContext agrees with Tenant.slugPattern on ${slug.codeUnits.length} units "${slug.replaceAll('\n', r'\n')}"', () {
      if (Tenant.slugPattern.hasMatch(slug)) {
        expect(TenantContext(slug: slug).slug, slug);
        expect((TenantContext()..slug = slug).slug, slug);
      } else {
        expect(() => TenantContext(slug: slug), throwsArgumentError);
        expect(() => TenantContext().slug = slug, throwsArgumentError);
      }
    });
  }

  test('a rejected slug leaves the previous one in place', () {
    final context = TenantContext(slug: 'acme-wifi');
    expect(() => context.slug = 'Bad Slug', throwsArgumentError);
    expect(context.slug, 'acme-wifi');
  });
}
