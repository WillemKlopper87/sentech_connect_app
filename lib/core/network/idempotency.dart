import 'dart:math';

/// `Idempotency-Key` value (server pattern `^[A-Za-z0-9_.:-]{8,128}$`).
/// Generate ONE key per logical operation and reuse it for every retry.
String newIdempotencyKey([Random? random]) => 'app-${_hex(random ?? Random.secure(), 16)}';

/// `X-Request-ID` value (server pattern `^[A-Za-z0-9._-]{1,64}$`).
String newRequestId([Random? random]) => 'app-${_hex(random ?? Random.secure(), 12)}';

String _hex(Random random, int bytes) =>
    List.generate(bytes, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
