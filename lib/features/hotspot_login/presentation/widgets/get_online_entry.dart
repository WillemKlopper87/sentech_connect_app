import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// Whether one-tap login can be offered: the tenant has hotspot RADIUS login
/// on and the customer has a pass that is running now (active, not past its
/// end; suspended, scheduled, expired and used-up passes do not qualify).
bool canGetOnline({
  required bool flagOn,
  required Iterable<Pass> passes,
  required DateTime now,
}) =>
    flagOn &&
    passes.any(
      (p) => p.status == PassStatus.active && p.expiresAt.isAfter(now),
    );

/// "Get online now" button for My passes and the Home pass card. Renders
/// nothing unless [canGetOnline]. Reads the flag from the tenant config.
class GetOnlineEntry extends StatelessWidget {
  const GetOnlineEntry({super.key, required this.passes, required this.now});

  final List<Pass> passes;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final flagOn =
        context.watch<TenantCubit?>()?.state.featureFlags.hotspotRadius ??
        false;
    if (!canGetOnline(flagOn: flagOn, passes: passes, now: now)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const Key('get-online-entry'),
          onPressed: () => context.push(AppRoutes.getOnline),
          icon: const Icon(Icons.wifi),
          label: Text(context.l10n.hotspotLoginTitle),
        ),
      ),
    );
  }
}
