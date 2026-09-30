import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/notifications/notification_service.dart';

/// Tracks the notification permission for the Account tile and the
/// rationale sheet. Screen-scoped (not app-root): it re-reads the status
/// whenever it is created or [refresh]ed, e.g. after returning from settings.
class NotificationPermissionCubit extends Cubit<NotificationPermissionStatus> {
  NotificationPermissionCubit(this._service) : super(NotificationPermissionStatus.denied) {
    refresh();
  }

  final NotificationService _service;

  Future<void> refresh() async {
    final status = await _service.permissionStatus();
    if (!isClosed) emit(status);
  }

  /// Shows the system prompt, or opens settings if it can no longer be shown.
  Future<void> requestOrOpenSettings() async {
    if (state == NotificationPermissionStatus.permanentlyDenied) {
      await _service.openSystemSettings();
      return;
    }
    final status = await _service.requestPermission();
    if (!isClosed) emit(status);
  }
}
