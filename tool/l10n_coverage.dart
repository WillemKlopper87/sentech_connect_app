import 'dart:convert';
import 'dart:io';

class CoverageResult {
  const CoverageResult(this.exitCode, this.lines, this.errors);
  final int exitCode;
  final List<String> lines;
  final List<String> errors;
}

/// Coverage means different from English, not linguistic validation. Identical
/// brands and legitimate shared words are deliberately counted as identical.
CoverageResult checkCoverage(List<String> args, {Directory? arbDirectory}) {
  var locales = ['zu', 'af'];
  var threshold = 0.0;
  final seen = <String>{};
  for (final arg in args) {
    final parts = arg.split('=');
    if (parts.length != 2 || !seen.add(parts.first)) {
      return CoverageResult(2, const [], [
        'Invalid or duplicate argument: $arg',
      ]);
    }
    switch (parts.first) {
      case '--locale':
        if (!['zu', 'af'].contains(parts.last)) {
          return CoverageResult(2, const [], [
            'Unsupported locale: ${parts.last}. Use zu or af.',
          ]);
        }
        locales = [parts.last];
      case '--fail-under':
        final value = double.tryParse(parts.last);
        if (value == null || !value.isFinite || value < 0 || value > 100) {
          return CoverageResult(2, const [], [
            'Invalid threshold: ${parts.last}. Use 0 to 100.',
          ]);
        }
        threshold = value;
      default:
        return CoverageResult(2, const [], ['Unknown argument: $arg']);
    }
  }
  Map<String, dynamic> read(String locale) {
    final file = File(
      '${(arbDirectory ?? Directory('lib/l10n')).path}/app_$locale.arb',
    );
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('${file.path} must contain a JSON object.');
    }
    return decoded;
  }

  try {
    final english = read('en');
    final keys = english.keys.where((key) => !key.startsWith('@')).toList()
      ..sort();
    bool valid(Object? value) => value is String && value.trim().isNotEmpty;
    if (keys.isEmpty || keys.any((key) => !valid(english[key]))) {
      return const CoverageResult(2, [], [
        'English catalogue has missing or invalid messages.',
      ]);
    }
    // Read all requested inputs before publishing any coverage claim.
    final catalogues = {for (final locale in locales) locale: read(locale)};
    final lines = <String>[];
    final errors = <String>[];
    var failed = false;
    for (final locale in locales) {
      final other = catalogues[locale]!;
      final missing = keys.where((key) => !valid(other[key])).toList();
      final identical = keys
          .where((key) => valid(other[key]) && other[key] == english[key])
          .length;
      final translated = keys.length - identical - missing.length;
      final percentage = translated * 100 / keys.length;
      lines.add(
        '$locale: ${keys.length} keys, $translated translated (${percentage.toStringAsFixed(2)}%), '
        '$identical identical to English, ${missing.length} missing or invalid',
      );
      if (missing.isNotEmpty) {
        errors.add('$locale missing or invalid keys: ${missing.join(', ')}');
      }
      if (missing.isNotEmpty || percentage < threshold) failed = true;
    }
    return CoverageResult(failed ? 1 : 0, lines, errors);
  } on FileSystemException catch (error) {
    return CoverageResult(2, const [], [
      'Cannot read catalogue: ${error.path}',
    ]);
  } on FormatException catch (error) {
    return CoverageResult(2, const [], ['Invalid catalogue: ${error.message}']);
  }
}

void main(List<String> args) {
  final result = checkCoverage(args);
  result.lines.forEach(stdout.writeln);
  result.errors.forEach(stderr.writeln);
  exitCode = result.exitCode;
}
