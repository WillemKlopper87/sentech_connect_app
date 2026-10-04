import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/local/app_preferences.dart';

class DataSaverCubit extends Cubit<bool> {
  DataSaverCubit({bool initial = false, Future<void> Function(bool)? save})
    : _save = save ?? AppPreferences.saveDataSaver,
      _savedValue = initial,
      super(initial);

  final Future<void> Function(bool) _save;
  bool _savedValue;
  Future<void> _writes = Future<void>.value();
  int _request = 0;

  Future<void> load() async {
    final saved = await AppPreferences.loadDataSaver();
    if (!isClosed) {
      _savedValue = saved;
      emit(saved);
    }
  }

  Future<void> set(bool on) async {
    final request = ++_request;
    final write = _writes.then((_) => _save(on));
    // Keep later writes moving even if an earlier attempt failed.
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    try {
      await write;
      _savedValue = on;
      if (!isClosed && request == _request) emit(on);
    } catch (_) {
      // A superseded write may have succeeded, even though it did not emit.
      if (!isClosed && request == _request) {
        emit(_savedValue);
        rethrow;
      }
    }
  }
}
