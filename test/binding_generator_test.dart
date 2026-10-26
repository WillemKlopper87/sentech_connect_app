import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/utils/binding_generator.dart';

class _ConstantRandom implements Random {
  _ConstantRandom(this.values);
  final List<int> values;
  var _i = 0;

  @override
  int nextInt(int max) => values[_i++ % values.length] % max;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

void main() {
  final shape = RegExp(r'^[A-Za-z0-9_-]{43}$');

  test('32 random bytes become 43 base64url characters, no padding', () {
    final generate = BindingGenerator();
    for (var i = 0; i < 50; i++) {
      final value = generate();
      expect(value, matches(shape));
      expect(value.split('').toSet().length, greaterThanOrEqualTo(8));
    }
  });

  test('two bindings differ (a fresh secret every time)', () {
    final generate = BindingGenerator();
    expect({for (var i = 0; i < 20; i++) generate()}.length, 20);
  });

  test('fits the API pattern ^[A-Za-z0-9_-]{32,128}\$', () {
    expect(BindingGenerator()(), matches(RegExp(r'^[A-Za-z0-9_-]{32,128}$')));
  });

  test('a broken source that gives fewer than 8 distinct characters is retried', () {
    // All-zero bytes encode as "AAAA..." (1 distinct character): never accepted.
    final random = _ConstantRandom([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32]);
    final value = BindingGenerator(random)();
    expect(value.split('').toSet().length, greaterThanOrEqualTo(8));
    expect(value, matches(shape));
  });
}
