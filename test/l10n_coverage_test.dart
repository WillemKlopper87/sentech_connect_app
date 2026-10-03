import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/l10n_coverage.dart';

void main() {
  late Directory directory;
  void arb(String locale, Map<String, Object?> values) => File(
    '${directory.path}/app_$locale.arb',
  ).writeAsStringSync(jsonEncode(values));
  setUp(() {
    directory = Directory.systemTemp.createTempSync('l10n-coverage-');
    arb('en', {
      '@@locale': 'en',
      'a': 'Hello',
      'b': 'Retry',
      'c': 'Help',
      '@a': {'description': 'Greeting'},
    });
    arb('zu', {'a': 'Sawubona', 'b': 'Retry', 'c': 'Help'});
    arb('af', {'a': 'Hallo', 'b': 'Probeer weer', 'c': 'Help'});
  });
  tearDown(() => directory.deleteSync(recursive: true));
  CoverageResult run(List<String> args) =>
      checkCoverage(args, arbDirectory: directory);

  test('default reports both locales and counts English fallbacks honestly', () {
    final result = run([]);
    expect(result.exitCode, 0);
    expect(result.lines, [
      'zu: 3 keys, 1 translated (33.33%), 2 identical to English, 0 missing or invalid',
      'af: 3 keys, 2 translated (66.67%), 1 identical to English, 0 missing or invalid',
    ]);
  });
  test('requested locale reports only that locale', () {
    expect(run(['--locale=zu']).lines, hasLength(1));
    expect(run(['--locale=af']).lines.single, startsWith('af:'));
  });
  test('threshold uses the unrounded percentage', () {
    expect(run(['--locale=af', '--fail-under=66.67']).exitCode, 1);
    expect(run(['--locale=af', '--fail-under=66.66']).exitCode, 0);
    expect(run(['--fail-under=50']).exitCode, 1);
    expect(run(['--fail-under=0']).exitCode, 0);
  });
  test('missing, null, non-string and blank values are never translated', () {
    arb('zu', {'a': null, 'b': 12});
    final result = run(['--locale=zu']);
    expect(result.exitCode, 1);
    expect(
      result.lines.single,
      contains(
        '0 translated (0.00%), 0 identical to English, 3 missing or invalid',
      ),
    );
    expect(result.errors.join(), contains('a, b, c'));
    arb('zu', {'a': '  ', 'b': 'Retry', 'c': 'Help'});
    expect(run(['--locale=zu']).exitCode, 1);
  });
  test(
    'invalid and duplicate arguments fail clearly without a coverage claim',
    () {
      for (final args in [
        ['--locale=en'],
        ['--locale=xx'],
        ['--locale=../en'],
        ['--locale='],
        ['--fail-under=no'],
        ['--fail-under=-1'],
        ['--fail-under=101'],
        ['--fail-under=NaN'],
        ['--fail-under=Infinity'],
        ['--unknown'],
        ['--locale=zu', '--locale=af'],
        ['--fail-under=0', '--fail-under=1'],
      ]) {
        final result = run(args);
        expect(result.exitCode, 2, reason: '$args');
        expect(result.lines, isEmpty);
        expect(result.errors, isNotEmpty);
      }
    },
  );
  test('missing or malformed catalogue fails clearly', () {
    File('${directory.path}/app_zu.arb').deleteSync();
    expect(run(['--locale=zu']).exitCode, 2);
    File('${directory.path}/app_zu.arb').writeAsStringSync('[]');
    expect(run(['--locale=zu']).exitCode, 2);
    File('${directory.path}/app_zu.arb').writeAsStringSync('{');
    expect(run(['--locale=zu']).exitCode, 2);
  });
  test('invalid or empty English catalogue cannot inflate coverage', () {
    arb('en', {'a': null});
    expect(run([]).exitCode, 2);
    arb('en', {'@@locale': 'en'});
    expect(run([]).exitCode, 2);
  });
}
