import 'package:flutter/material.dart';
import 'package:sentech_connect_app/app/theme/app_colors.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// A paid pass and the steps to use it; payment does not prove connection.
/// [networkName] must be a verified WiFi name, never a tenant display name.
class PassReadyView extends StatelessWidget {
  const PassReadyView({
    super.key,
    required this.title,
    this.networkName,
    required this.detail,
    required this.onDone,
    this.onFindWifi,
    this.onViewPasses,
    this.celebrate = true,
  });

  final String title;
  final String? networkName;
  final String detail;
  final VoidCallback onDone;
  final VoidCallback? onFindWifi;
  final VoidCallback? onViewPasses;

  /// Reserved for Task 11. This view currently has no animation or haptics.
  final bool celebrate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final name = networkName?.trim();
    final hasName = name != null && name.isNotEmpty;
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(fontSize: 15);
    const buttonStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

    Widget step(int number, IconData icon, String text) => Padding(
      key: Key('connect-step-$number'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: bodyStyle)),
        ],
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      Icons.check,
                      color: theme.colorScheme.primary,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.brightness == Brightness.light
                        ? AppColors.darkBlue
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  hasName
                      ? l10n.passReadyConnectNamed(name)
                      : l10n.passReadyConnect,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                step(1, Icons.wifi, l10n.passReadyTurnOnWifi),
                step(
                  2,
                  Icons.list,
                  hasName
                      ? l10n.passReadyChooseNamed(name)
                      : l10n.passReadyChooseNetwork,
                ),
                step(3, Icons.login, l10n.passReadySignInStep),
                const SizedBox(height: 20),
                Text(detail, textAlign: TextAlign.center, style: bodyStyle),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(textStyle: buttonStyle),
                  onPressed: onDone,
                  child: Text(l10n.passReadyDone, textAlign: TextAlign.center),
                ),
                if (onFindWifi != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(textStyle: buttonStyle),
                    onPressed: onFindWifi,
                    child: Text(
                      l10n.passReadyFindWifi,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                if (onViewPasses != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(textStyle: buttonStyle),
                    onPressed: onViewPasses,
                    child: Text(
                      l10n.confirmationViewPasses,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
