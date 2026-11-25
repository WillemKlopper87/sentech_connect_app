// Compares the app's saved platform contract with a newer platform OpenAPI
// file and says what the app would feel. Usage:
//   dart run tool/check_contract_drift.dart <platform openapi.json>
//       [--snapshot test/contract/openapi.json]
//       [--manifest test/contract/used_operations.json] [--json]
//
// Exit codes: 0 no BREAKING finding, 1 BREAKING, 64 usage or input error.
// Dependency-free (dart:convert, dart:io). Output is sorted and deterministic.
//
// What "the app reads" means here: for a used operation (the manifest), every
// field of its 2xx JSON response is treated as read (conservative), and every
// parameter and request-body field as sent. See docs/BACKEND_CONTRACT_SYNC.md,
// "Checking for drift", for the limits.
import 'dart:convert';
import 'dart:io';

const defaultSnapshot = 'test/contract/openapi.json';
const defaultManifest = 'test/contract/used_operations.json';

const usage =
    'usage: dart run tool/check_contract_drift.dart <platform openapi.json> '
    '[--snapshot $defaultSnapshot] [--manifest $defaultManifest] [--json]';

/// Path prefixes that are never customer-facing for the app.
const nonCustomerPrefixes = [
  '/v1/admin',
  '/v1/platform',
  '/v1/payments', // gateway server-to-server notifications
  '/v1/pay', // hosted payment hand-off pages
  '/v1/webhooks',
];

const _methods = ['get', 'put', 'post', 'delete', 'options', 'head', 'patch', 'trace'];

class DriftReport {
  final breaking = <String>[];
  final risk = <String>[];
  final additive = <String>[];
  final newCustomerRoutes = <String>[];
  int usedOperations = 0;

  Map<String, Object?> toJson() => {
    'breaking': breaking,
    'risk': risk,
    'additive': additive,
    'newCustomerRoutes': newCustomerRoutes,
    'usedOperations': usedOperations,
  };
}

class _Node {
  _Node({required this.required});
  final types = <String>{};
  Set<String>? enums;
  bool required;
}

/// Flattens a schema into dotted paths (`items[].name`, `m{}`) with the types,
/// enum values and required flag at each path. `$ref`, allOf, anyOf and oneOf
/// are resolved; a `$ref` already being expanded is not entered again.
class _Flattener {
  _Flattener(this.doc);
  final Map doc;

  Map<String, _Node> flatten(Object? schema, [String root = '']) {
    final out = <String, _Node>{};
    _walk(schema, root, out, const {}, required: false, inChoice: false, depth: 0);
    return out;
  }

  Object? _resolve(String ref) {
    if (!ref.startsWith('#/')) return null;
    Object? node = doc;
    for (final part in ref.substring(2).split('/')) {
      if (node is! Map) return null;
      node = node[part.replaceAll('~1', '/').replaceAll('~0', '~')];
    }
    return node;
  }

  _Node _touch(Map<String, _Node> out, String path, bool required) {
    final node = out.putIfAbsent(path, () => _Node(required: required));
    node.required = node.required || required;
    return node;
  }

  void _walk(
    Object? s,
    String path,
    Map<String, _Node> out,
    Set<String> stack, {
    required bool required,
    required bool inChoice,
    required int depth,
  }) {
    if (s is! Map || depth > 64) return;
    final ref = s[r'$ref'];
    if (ref is String) {
      if (stack.contains(ref)) {
        if (path.isNotEmpty) _touch(out, path, required).types.add('object');
        return;
      }
      _walk(_resolve(ref), path, out, {...stack, ref}, required: required, inChoice: inChoice, depth: depth + 1);
      return;
    }
    final node = path.isEmpty ? null : _touch(out, path, required);
    final type = s['type'];
    if (node != null) {
      if (type is String) node.types.add(type);
      if (type is List) node.types.addAll(type.whereType<String>());
      if (s['nullable'] == true) node.types.add('null');
      final values = <Object?>[
        if (s['enum'] is List) ...(s['enum'] as List),
        if (s.containsKey('const')) s['const'],
      ];
      if (values.isNotEmpty) {
        (node.enums ??= <String>{}).addAll(values.map((v) => jsonEncode(v)));
        if (values.contains(null)) node.types.add('null');
      }
    }
    for (final key in const ['allOf']) {
      for (final sub in (s[key] as List? ?? const [])) {
        _walk(sub, path, out, stack, required: required, inChoice: inChoice, depth: depth + 1);
      }
    }
    for (final key in const ['anyOf', 'oneOf']) {
      for (final sub in (s[key] as List? ?? const [])) {
        _walk(sub, path, out, stack, required: required, inChoice: true, depth: depth + 1);
      }
    }
    final props = s['properties'];
    if (props is Map) {
      node?.types.add('object');
      final req = (s['required'] as List? ?? const []).whereType<String>().toSet();
      for (final name in props.keys.cast<String>()) {
        _walk(
          props[name],
          path.isEmpty ? name : '$path.$name',
          out,
          stack,
          required: req.contains(name) && !inChoice,
          inChoice: false,
          depth: depth + 1,
        );
      }
    }
    final items = s['items'];
    if (items is Map) {
      node?.types.add('array');
      _walk(items, '$path[]', out, stack, required: false, inChoice: false, depth: depth + 1);
    }
    final extra = s['additionalProperties'];
    if (extra is Map) {
      _walk(extra, '$path{}', out, stack, required: false, inChoice: false, depth: depth + 1);
    }
  }
}

/// The parent paths of [path], outermost first.
List<String> _ancestors(String path) {
  final result = <String>[];
  for (var i = 1; i < path.length; i++) {
    if (path[i] == '.' || path[i] == '[' || path[i] == '{') result.add(path.substring(0, i));
  }
  return result;
}

/// Keeps only the topmost paths (drops a path whose ancestor is also listed).
List<String> _topmost(Iterable<String> paths) {
  final set = paths.toSet();
  return [for (final p in set) if (!_ancestors(p).any(set.contains)) p]..sort();
}

String _types(Set<String> t) => (t.toList()..sort()).join('|');

Map? _jsonSchema(Object? holder) {
  final content = (holder is Map ? holder['content'] : null);
  if (content is! Map) return null;
  final json = content['application/json'] ?? content.entries.where((e) => '${e.key}'.contains('json')).firstOrNull?.value;
  return json is Map && json['schema'] is Map ? json['schema'] as Map : null;
}

class _Doc {
  _Doc(this.doc) : flattener = _Flattener(doc);
  final Map doc;
  final _Flattener flattener;

  Map get paths => doc['paths'] as Map? ?? const {};

  Map? operation(String path, String method) {
    final item = paths[path];
    if (item is! Map) return null;
    final op = item[method];
    return op is Map ? op : null;
  }

  Map? _ref(Object? node) {
    if (node is Map && node[r'$ref'] is String) {
      final r = flattener._resolve(node[r'$ref'] as String);
      return r is Map ? r : null;
    }
    return node is Map ? node : null;
  }

  /// `in:name` -> parameter (path-level and operation-level, refs resolved).
  Map<String, Map> parameters(String path, String method) {
    final out = <String, Map>{};
    final lists = [(paths[path] as Map?)?['parameters'], operation(path, method)?['parameters']];
    for (final list in lists) {
      for (final raw in (list as List? ?? const [])) {
        final p = _ref(raw);
        if (p == null) continue;
        out['${p['in']}:${p['name']}'] = p;
      }
    }
    return out;
  }

  Map<String, _Node> requestBody(String path, String method) {
    final body = _ref(operation(path, method)?['requestBody']);
    final schema = _jsonSchema(body);
    return schema == null ? {} : flattener.flatten(schema, '\u0000');
  }

  bool requestBodyRequired(String path, String method) =>
      _ref(operation(path, method)?['requestBody'])?['required'] == true;

  Map<String, _Node> response(String path, String method) {
    final out = <String, _Node>{};
    final responses = operation(path, method)?['responses'];
    if (responses is! Map) return out;
    for (final code in (responses.keys.map((k) => '$k').toList()..sort())) {
      if (!code.startsWith('2')) continue;
      final schema = _jsonSchema(_ref(responses[code]));
      if (schema != null) out.addAll(flattener.flatten(schema, '\u0000'));
    }
    return out;
  }

  Map<String, _Node> paramSchema(Map p) => flattener.flatten(p['schema'], 'value');
}

String _show(String path) => path.replaceAll('\u0000', '').replaceFirst(RegExp(r'^[.]'), '');

String _label(String path) => _show(path).isEmpty ? '(body)' : _show(path);

DriftReport checkDrift({required Map snapshot, required Map platform, required Map manifest}) {
  final report = DriftReport();
  final snap = _Doc(snapshot);
  final plat = _Doc(platform);
  final operations = [
    for (final o in (manifest['operations'] as List? ?? const []))
      (method: '${(o as Map)['method']}'.toLowerCase(), path: '${o['path']}'),
  ];
  report.usedOperations = operations.length;
  final used = {for (final o in operations) '${o.method} ${o.path}'};

  for (final o in operations) {
    final name = '${o.method.toUpperCase()} ${o.path}';
    if (plat.operation(o.path, o.method) == null) {
      report.breaking.add('$name: operation removed from the platform');
      continue;
    }
    if (snap.operation(o.path, o.method) == null) continue; // new to the snapshot: nothing to compare

    // Parameters.
    final sp = snap.parameters(o.path, o.method);
    final pp = plat.parameters(o.path, o.method);
    for (final key in pp.keys) {
      final isRequired = pp[key]!['required'] == true;
      final was = sp[key];
      if (was == null) {
        (isRequired ? report.breaking : report.additive).add(
          isRequired ? '$name: new required parameter $key' : '$name: new optional parameter $key',
        );
      } else {
        if (isRequired && was['required'] != true) report.breaking.add('$name: parameter $key became required');
        _compareValues(
          snap.paramSchema(was),
          plat.paramSchema(pp[key]!),
          request: true,
          label: 'parameter $key',
          name: name,
          report: report,
          fieldsToo: false,
        );
      }
    }

    // Request body.
    final sb = snap.requestBody(o.path, o.method);
    final pb = plat.requestBody(o.path, o.method);
    if (plat.requestBodyRequired(o.path, o.method) && !snap.requestBodyRequired(o.path, o.method)) {
      report.breaking.add('$name: the request body became required');
    }
    for (final path in _topmost([for (final k in pb.keys) if (!sb.containsKey(k)) k])) {
      final node = pb[path]!;
      final ancestorsOptionalAndNew = _ancestors(path).any((a) => !sb.containsKey(a) && pb[a]?.required != true);
      if (node.required && !ancestorsOptionalAndNew) {
        report.breaking.add('$name: new required request field ${_label(path)}');
      } else {
        report.additive.add('$name: new optional request field ${_label(path)}');
      }
    }
    for (final path in sb.keys.where(pb.containsKey)) {
      if (pb[path]!.required && !sb[path]!.required) {
        report.breaking.add('$name: request field ${_label(path)} became required');
      }
    }
    for (final path in _topmost([for (final k in sb.keys) if (!pb.containsKey(k)) k])) {
      report.risk.add(
        '$name: request field ${_label(path)} removed from the schema '
        '(a body that forbids extra fields would now reject it)',
      );
    }
    _compareValues(sb, pb, request: true, label: null, name: name, report: report);

    // Response.
    final sr = snap.response(o.path, o.method);
    final pr = plat.response(o.path, o.method);
    for (final path in _topmost([for (final k in sr.keys) if (!pr.containsKey(k)) k])) {
      report.breaking.add('$name: response field removed: ${_label(path)}');
    }
    for (final path in _topmost([for (final k in pr.keys) if (!sr.containsKey(k)) k])) {
      report.additive.add('$name: new response field ${_label(path)}');
    }
    _compareValues(sr, pr, request: false, label: null, name: name, report: report);
  }

  // New customer-facing routes the app does not use.
  final snapOps = <String>{};
  for (final p in snap.paths.keys.cast<String>()) {
    for (final m in _methods) {
      if (snap.operation(p, m) != null) snapOps.add('$m $p');
    }
  }
  final fresh = <(String, String)>[];
  for (final p in plat.paths.keys.cast<String>()) {
    if (!_customerFacing(p)) continue;
    for (final m in _methods) {
      final key = '$m $p';
      if (plat.operation(p, m) != null && !snapOps.contains(key) && !used.contains(key)) fresh.add((p, m));
    }
  }
  fresh.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  report.newCustomerRoutes.addAll([for (final (p, m) in fresh) '${m.toUpperCase()} $p']);

  for (final list in [report.breaking, report.risk, report.additive]) {
    final unique = list.toSet().toList()..sort();
    list
      ..clear()
      ..addAll(unique);
  }
  return report;
}

bool _customerFacing(String path) {
  if (!path.startsWith('/v1/')) return false;
  return !nonCustomerPrefixes.any((p) => path == p || path.startsWith('$p/'));
}

/// Type and enum differences between two flattened schemas.
void _compareValues(
  Map<String, _Node> before,
  Map<String, _Node> after, {
  required bool request,
  required String? label,
  required String name,
  required DriftReport report,
  bool fieldsToo = true,
}) {
  for (final path in (before.keys.where(after.containsKey).toList()..sort())) {
    final b = before[path]!;
    final a = after[path]!;
    final what = label ?? (request ? 'request field ${_label(path)}' : 'response field ${_label(path)}');
    if (b.types.isNotEmpty && _types(b.types) != _types(a.types)) {
      report.breaking.add('$name: $what type changed: ${_types(b.types)} -> ${_types(a.types).isEmpty ? '(untyped)' : _types(a.types)}');
    }
    final be = b.enums;
    final ae = a.enums;
    if (be == null || ae == null) continue;
    final removed = (be.difference(ae).toList()..sort());
    final added = (ae.difference(be).toList()..sort());
    if (request) {
      for (final v in removed) {
        report.breaking.add('$name: request enum value removed: $what $v');
      }
      for (final v in added) {
        report.additive.add('$name: new request enum value: $what $v');
      }
    } else {
      for (final v in added) {
        report.risk.add('$name: new response enum value: $what $v');
      }
    }
  }
}

String formatReport(DriftReport r, {required String snapshotPath, required String platformPath}) {
  final b = StringBuffer()
    ..writeln('Contract drift report')
    ..writeln('  snapshot: $snapshotPath')
    ..writeln('  platform: $platformPath')
    ..writeln('  used operations checked: ${r.usedOperations}')
    ..writeln();
  void block(String title, List<String> items, {String? note}) {
    b.writeln('$title (${items.length})');
    if (note != null) b.writeln('  note: $note');
    if (items.isEmpty) b.writeln('  none');
    for (final i in items) {
      b.writeln('  - $i');
    }
    b.writeln();
  }

  block('BREAKING', r.breaking, note: 'the app would fail or send a request the platform refuses.');
  block(
    'RISK',
    r.risk,
    note: 'an enum value the app may not know. The app\'s parsers are mostly lenient (an unknown value maps to a '
        '"unknown" case), so this is not breaking; check any parser that decodes the field strictly.',
  );
  block('ADDITIVE', r.additive, note: 'new optional parameters, fields and values on operations the app uses.');
  block(
    'NEW CUSTOMER-FACING ROUTES',
    r.newCustomerRoutes,
    note: 'not in the snapshot and not used by the app (admin, platform and gateway paths are never listed).',
  );
  b.write('Result: ${r.breaking.isEmpty ? 'no BREAKING changes' : '${r.breaking.length} BREAKING change(s)'}');
  b.writeln(
    ', ${r.risk.length} risk, ${r.additive.length} additive, ${r.newCustomerRoutes.length} new customer-facing route(s).',
  );
  return b.toString();
}

Map _readOpenApi(String path, String what) {
  final file = File(path);
  if (!file.existsSync()) throw FormatException('$what file not found: $path');
  final Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (e) {
    throw FormatException('$what is not valid JSON ($path): ${e.message}');
  }
  if (decoded is! Map || decoded['openapi'] is! String || decoded['paths'] is! Map) {
    throw FormatException('$what is not an OpenAPI document: $path');
  }
  return decoded;
}

/// Runs the check; returns the exit code (0, 1 or 64).
int runDriftCheck(List<String> args, {required StringSink out, required StringSink err}) {
  String? platformPath;
  var snapshotPath = defaultSnapshot;
  var manifestPath = defaultManifest;
  var asJson = false;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--json') {
      asJson = true;
    } else if (a == '--snapshot' || a == '--manifest') {
      if (i + 1 >= args.length) {
        err.writeln('$a needs a value\n$usage');
        return 64;
      }
      if (a == '--snapshot') {
        snapshotPath = args[++i];
      } else {
        manifestPath = args[++i];
      }
    } else if (a.startsWith('-')) {
      err.writeln('unknown option $a\n$usage');
      return 64;
    } else if (platformPath == null) {
      platformPath = a;
    } else {
      err.writeln('unexpected argument $a\n$usage');
      return 64;
    }
  }
  if (platformPath == null) {
    err.writeln(usage);
    return 64;
  }
  final Map platform, snapshot, manifest;
  try {
    platform = _readOpenApi(platformPath, 'platform');
    snapshot = _readOpenApi(snapshotPath, 'snapshot');
    final file = File(manifestPath);
    if (!file.existsSync()) throw FormatException('manifest file not found: $manifestPath');
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map || decoded['operations'] is! List) {
      throw FormatException('manifest has no "operations" list: $manifestPath');
    }
    manifest = decoded;
  } on FormatException catch (e) {
    err.writeln('error: ${e.message}');
    return 64;
  }
  final report = checkDrift(snapshot: snapshot, platform: platform, manifest: manifest);
  if (asJson) {
    out.writeln(const JsonEncoder.withIndent('  ').convert(report.toJson()));
  } else {
    out.write(formatReport(report, snapshotPath: snapshotPath, platformPath: platformPath));
  }
  return report.breaking.isEmpty ? 0 : 1;
}

void main(List<String> args) {
  exitCode = runDriftCheck(args, out: stdout, err: stderr);
}
