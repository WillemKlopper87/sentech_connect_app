import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sentech_connect_app/features/subscriber/subscriber_gate.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/subscriber_entries.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// The Account tab's "Home internet" section: one row per registered entry
/// (see [subscriberAccountEntries]). Absent unless the provider has the
/// `subscriber_billing` module on; with no tenant loaded (tests) it is absent
/// too.
class HomeInternetSection extends StatelessWidget {
  const HomeInternetSection({super.key});

  @override
  Widget build(BuildContext context) {
    final on = context.select<TenantCubit?, bool>((c) => c != null && subscriberBillingOn(c.state));
    if (!on) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final entries = subscriberAccountEntries();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.servicesHomeInternetHeading, style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0.6)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    minTileHeight: 48,
                    leading: Icon(entries[i].icon),
                    title: Text(entries[i].label(l10n)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(entries[i].route),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
