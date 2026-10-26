import 'package:flutter/material.dart';
import 'package:sentech_connect_app/core/security/human_check_provider.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_check_controller.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_provider.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// Opens the Quick check sheet for a running [check]. Completes when the sheet
/// is gone. Closing it by the Cancel button, the back button, the scrim or a
/// swipe all cancel the check; the customer is never held in it.
Future<void> showHumanCheckSheet(BuildContext context, TurnstileCheckController check) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => HumanCheckSheet(check: check),
  );
}

/// "Quick check: confirm you are a person". Shows the widget view, a status
/// line (a live region for screen readers), Retry once it failed, and Cancel
/// always.
class HumanCheckSheet extends StatefulWidget {
  const HumanCheckSheet({super.key, required this.check});

  final TurnstileCheckController check;

  @override
  State<HumanCheckSheet> createState() => _HumanCheckSheetState();
}

class _HumanCheckSheetState extends State<HumanCheckSheet> {
  @override
  void initState() {
    super.initState();
    // Done (token or cancel): close the sheet.
    widget.check.result.then((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: ValueListenableBuilder<TurnstileCheckState>(
        valueListenable: widget.check,
        builder: (context, state, _) {
          final failed = state.phase == TurnstilePhase.failed;
          final status = switch (state.phase) {
            TurnstilePhase.failed => switch (state.failure) {
                TurnstileFailure.network || null => l10n.humanCheckFailedNetwork,
                TurnstileFailure.widget => l10n.humanCheckFailedWidget,
                TurnstileFailure.timeout => l10n.humanCheckFailedTimeout,
              },
            TurnstilePhase.challenge => l10n.humanCheckChallenge,
            _ => l10n.humanCheckLoading,
          };
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(l10n.humanCheckTitle, style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: 8),
              Text(l10n.humanCheckBody, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!failed) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                    ] else ...[
                      Icon(Icons.error_outline, size: 20, color: theme.colorScheme.error),
                      const SizedBox(width: 12),
                    ],
                    Expanded(child: Text(status, key: const Key('humanCheckStatus'))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Kept mounted (hidden) while failed: Retry resets this same view.
              Visibility(
                visible: !failed,
                maintainState: true,
                child: Semantics(
                  container: true,
                  label: l10n.humanCheckWidgetLabel,
                  child: SizedBox(
                    height: 110,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: widget.check.buildView(context),
                    ),
                  ),
                ),
              ),
              if (failed) ...[
                Text(l10n.humanCheckHelp, style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    key: const Key('humanCheckCancel'),
                    onPressed: widget.check.cancel,
                    child: Text(l10n.humanCheckCancel),
                  ),
                  if (failed)
                    FilledButton(
                      key: const Key('humanCheckRetry'),
                      onPressed: widget.check.retry,
                      child: Text(l10n.humanCheckRetry),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Presents the Quick check over the app's root navigator (the one the
/// router builds with [navigatorKey]), so any screen can trigger it from a
/// repository call without holding a `BuildContext`.
class NavigatorHumanCheckPresenter implements HumanCheckPresenter {
  NavigatorHumanCheckPresenter(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Future<void> present(TurnstileCheckController check) async {
    final context = navigatorKey.currentState?.overlay?.context;
    if (context == null || !context.mounted) throw const HumanCheckUnavailable();
    await showHumanCheckSheet(context, check);
  }
}
