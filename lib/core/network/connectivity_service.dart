import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the device currently has a network connection.
///
/// Note this reports *link* state (Wi-Fi/cellular/ethernet present), not
/// proof the internet is reachable — a captive portal or a dead FWA backhaul
/// still reads as "online". Repositories therefore also surface
/// `NetworkFailure` from real request failures; the offline banner is a
/// hint, not a guarantee.
abstract class ConnectivityService {
  Future<bool> isOnline();

  /// Emits whenever the online/offline state changes.
  Stream<bool> get onlineChanges;
}

class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService([Connectivity? connectivity]) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _online(List<ConnectivityResult> results) =>
      results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);

  @override
  Future<bool> isOnline() async {
    try {
      return _online(await _connectivity.checkConnectivity());
    } catch (_) {
      return true; // unknown: don't claim to be offline
    }
  }

  @override
  Stream<bool> get onlineChanges => _connectivity.onConnectivityChanged.map(_online).distinct();
}

/// Scriptable implementation for tests and demos.
class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this._online = true});

  bool _online;
  final _controller = StreamController<bool>.broadcast();

  void setOnline(bool value) {
    _online = value;
    _controller.add(value);
  }

  @override
  Future<bool> isOnline() async => _online;

  @override
  Stream<bool> get onlineChanges => _controller.stream;
}
