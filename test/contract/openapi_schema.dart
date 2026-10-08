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
