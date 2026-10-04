import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/local/app_preferences.dart';

class DataSaverCubit extends Cubit<bool> {
  DataSaverCubit({bool initial = false, Future<void> Function(bool)? save})
    : _save = save ?? AppPreferences.saveDataSaver,
      super(initial);

  final Future<void> Function(bool) _save;
  Future<void> _writes = Future<void>.value();
  int _request = 0;

  Future<void> load() async {
    final saved = await AppPreferences.loadDataSaver();
    if (!isClosed) emit(saved);
  }

  Future<void> set(bool on) async {
    final request = ++_request;
    final write = _writes.then((_) => _save(on));
    // Keep later writes moving even if an earlier attempt failed.
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    try {
      await write;
      if (!isClosed && request == _request) emit(on);
    } catch (_) {
      // Only the latest live choice needs a retry message. The saved state
      // remains visible because we do not emit before persistence succeeds.
      if (!isClosed && request == _request) rethrow;
    }
  }
}
