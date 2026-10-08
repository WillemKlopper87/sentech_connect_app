// Copies the platform's apps/api/openapi.json into test/contract/ so the
// contract test runs offline. Usage:
//   dart run tool/sync_openapi.dart ../sentech_connect_platform/apps/api/openapi.json
import 'dart:convert';
import 'dart:io';

enum SyncResult { updated, unchanged }

const defaultTarget = 'test/contract/openapi.json';

SyncResult syncOpenApi({required String sourcePath, required String targetPath}) {
  final decoded = jsonDecode(File(sourcePath).readAsStringSync());
  if (decoded is! Map || decoded['openapi'] is! String || decoded['components'] is! Map) {
    throw const FormatException('Not an OpenAPI document');
  }
  final pretty = '${const JsonEncoder.withIndent('  ').convert(decoded)}\n';
  final target = File(targetPath);
  if (target.existsSync() && target.readAsStringSync() == pretty) return SyncResult.unchanged;
  target
    ..createSync(recursive: true)
    ..writeAsStringSync(pretty);
  return SyncResult.updated;
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/sync_openapi.dart <platform>/apps/api/openapi.json');
    exit(64);
  }
  final result = syncOpenApi(sourcePath: args.single, targetPath: defaultTarget);
  stdout.writeln('${result.name} $defaultTarget');
}
