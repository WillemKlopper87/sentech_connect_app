import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/local/app_preferences.dart';

class DataSaverCubit extends Cubit<bool> {
  DataSaverCubit({bool initial = false}) : super(initial);

  Future<void> load() async {
    final saved = await AppPreferences.loadDataSaver();
    if (!isClosed) emit(saved);
  }

  Future<void> set(bool on) async {
    emit(on);
    await AppPreferences.saveDataSaver(on);
  }
}
