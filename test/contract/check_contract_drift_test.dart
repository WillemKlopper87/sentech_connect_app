import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_contract_drift.dart';

const dir = 'test/contract/drift_fixtures';

class Run {
  Run(this.code, this.out, this.err);
  final int code;
  final String out;
  final String err;
}

Run drift(String platform, {List<String> extra = const []}) {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = runDriftCheck(
    [platform, '--snapshot', '$dir/base.json', '--manifest', '$dir/manifest.json', ...extra],
    out: out,
    err: err,
  );
  return Run(code, out.toString(), err.toString());
}

Run fixture(String name, {List<String> extra = const []}) => drift('$dir/$name.json', extra: extra);

/// The text of one report section (from its heading to the next heading).
String section(String report, String heading) {
  final start = report.indexOf(heading);
  if (start < 0) return '';
  final rest = report.substring(start + heading.length);
  final next = RegExp(r'\n(BREAKING|RISK|ADDITIVE|NEW CUSTOMER)').firstMatch(rest);
  return next == null ? rest : rest.substring(0, next.start);
}

void main() {
  test('unchanged platform: no findings, exit 0', () {
    final r = fixture('unchanged');
    expect(r.code, 0);
    expect(section(r.out, 'BREAKING'), contains('none'));
  });

  test('removed operation is BREAKING, exit 1', () {
    final r = fixture('removed_operation');
    expect(r.code, 1);
    expect(section(r.out, 'BREAKING'), allOf(contains('GET /v1/me/old'), contains('removed')));
  });

  test('a new required parameter is BREAKING', () {
    final r = fixture('new_required_param');
    expect(r.code, 1);
    expect(section(r.out, 'BREAKING'), allOf(contains('GET /v1/me/thing'), contains('region'), contains('required parameter')));
  });

  test('a new required request-body field is BREAKING', () {
    final r = fixture('new_required_body_field');
    expect(r.code, 1);
    expect(section(r.out, 'BREAKING'), allOf(contains('POST /v1/me/thing'), contains('plan'), contains('required request field')));
  });

  test('a removed response field is BREAKING (nested too)', () {
    final r = fixture('removed_response_field');
    expect(r.code, 1);
    expect(section(r.out, 'BREAKING'), allOf(contains('GET /v1/me/thing'), contains('name'), contains('response field removed')));
    final n = fixture('removed_nested_field');
    expect(n.code, 1);
    expect(section(n.out, 'BREAKING'), contains('inner.code'));
  });

  test('a changed response type is BREAKING', () {
    final r = fixture('changed_type');
    expect(r.code, 1);
    expect(section(r.out, 'BREAKING'), allOf(contains('count'), contains('integer'), contains('string')));
  });

  test('a removed request enum value is BREAKING', () {
    final r = fixture('removed_request_enum');
    expect(r.code, 1);
    expect(section(r.out, 'BREAKING'), allOf(contains('kind'), contains('"y"'), contains('request enum value removed')));
  });

  test('an added response enum value is RISK, not BREAKING, exit 0', () {
    final r = fixture('added_response_enum');
    expect(r.code, 0);
    expect(section(r.out, 'BREAKING'), contains('none'));
    expect(section(r.out, 'RISK'), allOf(contains('status'), contains('"c"')));
    expect(r.out, contains('lenient'));
  });

  test('new optional fields, params and request enum values are ADDITIVE, exit 0', () {
    final r = fixture('new_optional_field');
    expect(r.code, 0);
    expect(section(r.out, 'ADDITIVE'), allOf(contains('extra'), contains('"z"'), contains('query:q')));
    expect(section(r.out, 'BREAKING'), contains('none'));
  });

  test('new customer-facing routes are reported', () {
    final r = fixture('new_customer_route');
    expect(r.code, 0);
    expect(
      section(r.out, 'NEW CUSTOMER-FACING ROUTES'),
      allOf(contains('GET /v1/me/new'), contains('GET /v1/public/y'), contains('GET /v1/geocode/z')),
    );
  });

  test('new admin, platform and gateway routes are never listed', () {
    final r = fixture('new_admin_route');
    expect(r.code, 0);
    expect(r.out, isNot(contains('/v1/admin/new')));
    expect(r.out, isNot(contains('/v1/platform/p')));
    expect(r.out, isNot(contains('notify')));
    expect(section(r.out, 'NEW CUSTOMER-FACING ROUTES'), contains('none'));
  });

  test('a self-referencing schema does not recurse forever', () {
    final r = fixture('recursive_schema');
    expect(r.code, 0);
    expect(section(r.out, 'ADDITIVE'), contains('tree'));
  });

  test('--json prints the same findings as machine-readable output', () {
    final r = fixture('removed_operation', extra: ['--json']);
    expect(r.code, 1);
    final j = jsonDecode(r.out) as Map;
    expect((j['breaking'] as List).single, contains('GET /v1/me/old'));
    expect(j['risk'], isEmpty);
    expect(j['additive'], isEmpty);
    expect(j['newCustomerRoutes'], isEmpty);
  });

  test('output is deterministic and sorted', () {
    final r = fixture('new_customer_route').out;
    expect(r, fixture('new_customer_route').out);
    expect(r.indexOf('/v1/geocode/z') < r.indexOf('/v1/me/new'), isTrue);
  });

  group('usage errors exit 64', () {
    test('no arguments', () {
      final out = StringBuffer(), err = StringBuffer();
      expect(runDriftCheck([], out: out, err: err), 64);
      expect(err.toString(), contains('usage'));
    });
    test('missing platform file', () {
      final r = drift('$dir/does_not_exist.json');
      expect(r.code, 64);
      expect(r.err, contains('does_not_exist.json'));
    });
    test('not JSON / not OpenAPI', () {
      final tmp = Directory.systemTemp.createTempSync('drift');
      addTearDown(() => tmp.deleteSync(recursive: true));
      File('${tmp.path}/a.json').writeAsStringSync('nope');
      File('${tmp.path}/b.json').writeAsStringSync('{"hello":1}');
      expect(drift('${tmp.path}/a.json').code, 64);
      expect(drift('${tmp.path}/b.json').code, 64);
    });
    test('unknown option', () {
      expect(fixture('unchanged', extra: ['--nope']).code, 64);
    });
  });

  group('the saved snapshot', () {
    test('against itself reports no BREAKING and no new routes', () {
      final out = StringBuffer(), err = StringBuffer();
      final code = runDriftCheck(['test/contract/openapi.json'], out: out, err: err);
      expect(code, 0, reason: out.toString() + err.toString());
      expect(section(out.toString(), 'BREAKING'), contains('none'));
      expect(section(out.toString(), 'NEW CUSTOMER-FACING ROUTES'), contains('none'));
    });

    final older = File(r'C:\tmp\g6\apps\api\openapi.json');
    test(
      'against another platform copy does not crash (skipped when the file is absent)',
      () {
        final out = StringBuffer(), err = StringBuffer();
        final code = runDriftCheck([older.path], out: out, err: err);
        expect(code, anyOf(0, 1), reason: err.toString());
      },
      skip: older.existsSync() ? false : 'older platform copy not present',
    );
  });
}
