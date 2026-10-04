import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sentech_connect_app/l10n/demo_copy.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/promotions/domain/entities/promotion.dart';
import 'package:sentech_connect_app/features/promotions/presentation/bloc/promotions_cubit.dart';

class PromotionsPage extends StatelessWidget {
  const PromotionsPage({super.key, this.showPoints = false});

  final bool showPoints;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.promotionsTitle)),
      body: BlocBuilder<PromotionsCubit, PromotionsState>(
        builder: (context, state) {
          if (state.status == PromotionsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              if (showPoints)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.promotionsPoints(
                                state.loyaltyPoints.toString(),
                              ),
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              context.l10n.promotionsYourSentechLoyaltyBalance,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (showPoints) const SizedBox(height: 20),
              Text(
                context.l10n.promotionsCurrentOffers,
                style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0.6),
              ),
              const SizedBox(height: 10),
              if (state.promotions.isEmpty) ...[
                const Icon(Icons.local_offer_outlined, size: 48),
                const SizedBox(height: 12),
                Text(
                  state.status == PromotionsStatus.failure
                      ? context.l10n.promotionsUnavailable
                      : context.l10n.promotionsEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
              for (final promo in state.promotions) ...[
                _PromoCard(promo: localizeDemoPromotion(promo, context.l10n)),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.promo});

  final Promotion promo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAA61A),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  promo.badge,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF003A70),
                  ),
                ),
              ),
              Text(
                promo.expiresAt == null
                    ? context.l10n.promotionsOngoing
                    : context.l10n.promotionsExpires(
                        DateFormat.MMMd(
                          Localizations.localeOf(context).toString(),
                        ).format(promo.expiresAt!.toLocal()),
                      ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(promo.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            promo.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
