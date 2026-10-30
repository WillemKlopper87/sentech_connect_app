import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/features/subscriber/subscriber_gate.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// The Shop tab's "Monthly plans" card. Absent unless the provider has the
/// `subscriber_billing` module on (and with no tenant loaded, as in tests).
class MonthlyPlansCard extends StatelessWidget {
  const MonthlyPlansCard({super.key});

  @override
  Widget build(BuildContext context) {
    final on = context.select<TenantCubit?, bool>((c) => c != null && subscriberBillingOn(c.state));
    if (!on) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          key: const Key('shop-monthly-plans'),
          minTileHeight: 64,
          leading: const Icon(Icons.wifi_outlined),
          title: Text(l10n.plansTitle, style: theme.textTheme.titleMedium),
          subtitle: Text(l10n.plansShopCardSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.plans),
        ),
      ),
    );
  }
}
