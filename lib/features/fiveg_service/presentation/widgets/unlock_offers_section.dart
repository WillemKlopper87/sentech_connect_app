import 'package:flutter/material.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/entities/fiveg_usage.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/usage_levels.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/service_format.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// The paid unlocks for this month. Each row shows the data added, the price
/// with VAT included, and the last day it counts. An empty list says so.
class UnlockOffersSection extends StatelessWidget {
  const UnlockOffersSection({super.key, required this.offers, required this.onBuy});

  final List<UnlockOffer> offers;
  final void Function(UnlockOffer offer) onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.fivegUnlockHeading, style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(l10n.fivegUnlockIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        if (offers.isEmpty)
          Text(l10n.fivegNoOffers, style: theme.textTheme.bodyMedium)
        else
          for (final offer in offers) ...[
            _OfferRow(offer: offer, onBuy: () => onBuy(offer)),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.offer, required this.onBuy});

  final UnlockOffer offer;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final size = formatDataSize(offer.addedMb);
    final price = formatRands(offer.priceCents);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.fivegOfferAdds(size), style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(l10n.fivegPriceInclVat(price), style: theme.textTheme.bodyMedium),
                Text(
                  l10n.fivegValidUntil(formatApiDay(context, offer.validUntil)),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            label: l10n.fivegBuyLabel(size, price),
            excludeSemantics: true,
            button: true,
            child: FilledButton(
              onPressed: onBuy,
              child: Text(l10n.fivegBuy),
            ),
          ),
        ],
      ),
    );
  }
}

/// An unlock that was created but not paid yet: continue paying it.
class PendingUnlockCard extends StatelessWidget {
  const PendingUnlockCard({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.onSurface, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.hourglass_bottom, color: theme.colorScheme.onSurface),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.fivegPendingTitle, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 6),
          Text(l10n.fivegPendingBody, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          FilledButton(onPressed: onContinue, child: Text(l10n.fivegContinuePayment)),
        ],
      ),
    );
  }
}
