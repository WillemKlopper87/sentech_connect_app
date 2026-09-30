import 'package:flutter/material.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/notifications/notification_service.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// Explains WHY the app wants to send notifications before the Android 13+
/// system prompt appears (a prompt with no context is far more likely to be
/// denied — and after two denials Android stops showing it at all). Returns
/// the resulting permission status, or null if the customer chose "Not now".
Future<NotificationPermissionStatus?> showNotificationRationale(
  BuildContext context, {
  NotificationService? service,
}) async {
  final notifications = service ?? locator<NotificationService>();
  // Already decided: nothing to explain.
  final current = await notifications.permissionStatus();
  if (current == NotificationPermissionStatus.granted || !context.mounted) return current;

  final allow = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.notifications_active_outlined, size: 36, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(l10n.notifRationaleTitle, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(l10n.notifRationaleBody, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 18),
              ElevatedButton(onPressed: () => Navigator.pop(sheetContext, true), child: Text(l10n.notifRationaleAllow)),
              TextButton(onPressed: () => Navigator.pop(sheetContext, false), child: Text(l10n.notifRationaleLater)),
            ],
          ),
        ),
      );
    },
  );
  if (allow != true) return null;
  if (current == NotificationPermissionStatus.permanentlyDenied) {
    await notifications.openSystemSettings();
    return current;
  }
  return notifications.requestPermission();
}
