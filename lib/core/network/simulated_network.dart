import 'package:sentech_connect_app/core/error/failure.dart';

/// Lets mock repositories behave as if the network were down, so the
/// offline/retry UI can be demoed and tested. Real repositories ignore this
/// and surface `NetworkFailure` from their HTTP client instead.
class SimulatedNetwork {
  bool offline = false;

  /// Non-null while offline; mocks return it as `Left(...)`.
  Failure? get failure => offline ? const NetworkFailure() : null;
}
