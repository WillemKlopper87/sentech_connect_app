import 'package:flutter/material.dart';

/// A short plain-words notice on the Rewards pages (frozen wallet, pause,
/// monthly limit, credits about to expire). [warning] colours it as a problem
/// the customer cannot fix in the app; otherwise it is neutral information.
class CreditsNotice extends StatelessWidget {
  const CreditsNotice({super.key, required this.text, this.warning = false, this.icon});

  final String text;
  final bool warning;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = warning ? scheme.errorContainer : scheme.secondaryContainer;
    final foreground = warning ? scheme.onErrorContainer : scheme.onSecondaryContainer;
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? (warning ? Icons.info_outline : Icons.schedule), color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centred text for a page whose feature is not available (or has nothing to show).
class CreditsMessage extends StatelessWidget {
  const CreditsMessage(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(text, textAlign: TextAlign.center)));
}
