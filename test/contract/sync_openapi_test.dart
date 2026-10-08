import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/sync_openapi.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('openapi'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File write(String name, Object json) =>
      File('${tmp.path}/$name')..writeAsStringSync(jsonEncode(json));

  test('copies a valid document pretty-printed, then reports unchanged', () {
    final src = write('src.json', {'openapi': '3.1.0', 'components': {'schemas': {}}, 'paths': {}});
    final target = '${tmp.path}/out/openapi.json';
    expect(syncOpenApi(sourcePath: src.path, targetPath: target), SyncResult.updated);
    expect(File(target).readAsStringSync(), contains('\n  "openapi": "3.1.0"'));
    expect(syncOpenApi(sourcePath: src.path, targetPath: target), SyncResult.unchanged);
  });

  test('refuses a file that is not an OpenAPI document', () {
    final src = write('bad.json', {'hello': 'world'});
    expect(() => syncOpenApi(sourcePath: src.path, targetPath: '${tmp.path}/o.json'),
        throwsFormatException);
    expect(File('${tmp.path}/o.json').existsSync(), isFalse);
  });

  test('a missing source file is a FileSystemException', () {
    expect(
        () => syncOpenApi(
            sourcePath: '${tmp.path}/nope.json', targetPath: '${tmp.path}/o.json'),
        throwsA(isA<FileSystemException>()));
  });
}
