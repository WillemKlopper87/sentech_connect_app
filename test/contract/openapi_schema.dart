import 'dart:convert';
import 'dart:io';

/// The JSON Schema subset FastAPI emits: $ref, anyOf, type, enum, const,
/// properties, required, items, additionalProperties.
class OpenApiSnapshot {
  OpenApiSnapshot._(this._schemas);

  factory OpenApiSnapshot.load([String path = 'test/contract/openapi.json']) {
    final doc = jsonDecode(File(path).readAsStringSync()) as Map;
    return OpenApiSnapshot._(Map<String, Object?>.from((doc['components'] as Map)['schemas'] as Map));
  }

  final Map<String, Object?> _schemas;

  late final Map<String, Object?> _paths = Map<String, Object?>.from(
    (jsonDecode(File('test/contract/openapi.json').readAsStringSync()) as Map)['paths'] as Map,
  );

  /// Every path in the snapshot.
  Iterable<String> get pathKeys => _paths.keys;

  /// The operation object of [method] on [path].
  Map<String, Object?> path(String path, String method) {
    final item = _paths[path];
    if (item is! Map || item[method] is! Map) throw ArgumentError('No $method $path in the snapshot');
    return Map<String, Object?>.from(item[method] as Map);
  }

  static String? _refName(Object? node) {
    if (node is! Map) return null;
    final ref = node[r'$ref'];
    if (ref is String) return ref.split('/').last;
    for (final option in (node['anyOf'] as List? ?? const [])) {
      final name = _refName(option);
      if (name != null) return name;
    }
    return null;
  }

  /// The schema name of the JSON body an operation answers with for [status].
  String? responseSchemaName(Map<String, Object?> operation, String status) {
    final response = (operation['responses'] as Map?)?[status] as Map?;
    final content = response?['content'] as Map?;
    return _refName(((content?.values.firstOrNull) as Map?)?['schema']);
  }

  /// The schema name of an operation's JSON request body.
  String? requestBodySchemaName(Map<String, Object?> operation) {
    final content = (operation['requestBody'] as Map?)?['content'] as Map?;
    return _refName(((content?.values.firstOrNull) as Map?)?['schema']);
  }

  Map<String, Object?> schema(String name) {
    final s = _schemas[name];
    if (s is! Map) throw ArgumentError('No schema $name in the snapshot');
    return Map<String, Object?>.from(s);
  }

  Set<String> properties(String name) =>
      Map<String, Object?>.from(schema(name)['properties'] as Map? ?? const {}).keys.toSet();

  List<String> validate(Object? value, Map<String, Object?> s, [String at = r'$']) {
    final ref = s[r'$ref'];
    if (ref is String) return validate(value, schema(ref.split('/').last), at);
    final anyOf = s['anyOf'];
    if (anyOf is List) {
      final ok = anyOf.any((o) => validate(value, Map<String, Object?>.from(o as Map), at).isEmpty);
      return ok ? const [] : ['$at: matches no anyOf option'];
    }
    final errors = <String>[];
    final allowed = s['enum'];
    if (allowed is List && !allowed.contains(value)) errors.add('$at: $value not in $allowed');
    if (s.containsKey('const') && value != s['const']) errors.add('$at: expected ${s['const']}');
    final type = s['type'];
    final typeOk = switch (type) {
      'null' => value == null,
      'string' => value is String,
      'integer' => value is int,
      'number' => value is num,
      'boolean' => value is bool,
      'array' => value is List,
      'object' => value is Map,
      _ => true,
    };
    if (!typeOk) return [...errors, '$at: expected $type'];
    final items = s['items'];
    if (value is List && items is Map) {
      for (var i = 0; i < value.length; i++) {
        errors.addAll(validate(value[i], Map<String, Object?>.from(items), '$at[$i]'));
      }
    }
    if (value is Map && (s.containsKey('properties') || s.containsKey('additionalProperties'))) {
      final props = Map<String, Object?>.from(s['properties'] as Map? ?? const {});
      for (final key in (s['required'] as List? ?? const [])) {
        if (!value.containsKey(key)) errors.add('$at.$key: required but missing');
      }
      final extra = s['additionalProperties'];
      for (final MapEntry(:key, value: v) in value.entries) {
        final sub = props[key] ?? (extra is Map ? extra : null);
        if (sub is Map) {
          errors.addAll(validate(v, Map<String, Object?>.from(sub), '$at.$key'));
        } else if (extra == false) {
          errors.add('$at.$key: not in schema');
        }
      }
    }
    return errors;
  }
}
