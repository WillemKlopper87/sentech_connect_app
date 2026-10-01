import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/app_version.dart';
import 'package:sentech_connect_app/core/utils/version.dart';

void main() {
  test('compares dotted versions numerically', () {
    expect(isVersionAtLeast('1.0.0', '1.0.0'), isTrue);
    expect(isVersionAtLeast('1.2.10', '1.2.9'), isTrue);
    expect(isVersionAtLeast('1.2.9', '1.2.10'), isFalse);
    expect(isVersionAtLeast('2.0', '1.9.9'), isTrue);
    expect(isVersionAtLeast('1.0.0+7', '1.0.0'), isTrue);
    expect(isVersionAtLeast('1.0.0', '1.0.1-beta'), isFalse);
  });

  test('an unparseable minimum never blocks the app (ruling R-M4-14)', () {
    expect(isVersionAtLeast('1.0.0', ''), isTrue);
    expect(isVersionAtLeast('1.0.0', 'latest'), isTrue);
  });

  test('appVersion matches the pubspec version', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(line.substring('version:'.length).trim().split('+').first, appVersion);
  });
}
