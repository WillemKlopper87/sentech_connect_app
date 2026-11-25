import 'package:flutter/material.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// The "Rewards" card on My passes. Shown only when the caller passes
/// [onOpen], which the router does only when the provider has the `credits`
/// module and flag on (see `creditsOn`). It makes no request: the Rewards home
/// reads the wallet itself.
class RewardsEntryCard extends StatelessWidget {
  const RewardsEntryCard({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        key: const Key('rewards-entry-card'),
        minTileHeight: 64,
        leading: const Icon(Icons.card_giftcard_outlined),
        title: Text(l10n.creditsTitle),
        subtitle: Text(l10n.creditsEntrySubtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onOpen,
      ),
    );
  }
}
