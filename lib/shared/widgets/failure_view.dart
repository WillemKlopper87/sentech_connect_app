import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:sentech_connect_app/l10n/failure_copy.dart';
import 'package:sentech_connect_app/core/error/failure.dart';

/// Friendly message + retry for a failed load/submit. Offline failures get
/// their own wording so the customer knows the fix is their connection, not
/// something they did.
class FailureView extends StatelessWidget {
  const FailureView({
    super.key,
    required this.failure,
    required this.onRetry,
    this.compact = false,
  });

  final Failure? failure;
  final VoidCallback onRetry;

  /// Inline (inside a scroll view / above a button) rather than centred.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offline = failure is NetworkFailure;
    final message = offline
        ? context.l10n.failureYouReOfflineCheckYourConnection
        : (failure == null
              ? context.l10n.failureSomethingWentWrongPleaseTryAgain
              : localizedFailureText(context.l10n, failure!.message));
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      children: [
        Icon(
          offline ? Icons.wifi_off : Icons.error_outline,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(context.l10n.commonRetry),
        ),
      ],
    );
    return compact
        ? content
        : Center(
            child: Padding(padding: const EdgeInsets.all(24), child: content),
          );
  }
}
