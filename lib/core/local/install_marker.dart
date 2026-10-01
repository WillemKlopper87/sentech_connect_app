import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Proof that THIS installation of the app ran before. SharedPreferences are
/// removed on uninstall while the iOS Keychain can survive it, so a session
/// found in secure storage with no marker belongs to a previous installation
/// and must not be resumed (see `restoreAuthState`).
abstract class InstallMarker {
  Future<bool> exists();

  Future<void> create();
}

class SharedPrefsInstallMarker implements InstallMarker {
  static const _key = 'install_id';

  @override
  Future<bool> exists() async => (await SharedPreferences.getInstance()).containsKey(_key);

  @override
  Future<void> create() async {
    final random = Random.secure();
    final id = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await (await SharedPreferences.getInstance()).setString(_key, id);
  }
}

class InMemoryInstallMarker implements InstallMarker {
  InMemoryInstallMarker({this.present = false});

  bool present;

  @override
  Future<bool> exists() async => present;

  @override
  Future<void> create() async => present = true;
}
