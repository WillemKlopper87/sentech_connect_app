import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/features/tenant/presentation/widgets/tenant_logo.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// The ISP drop-down of spec §12, as a full screen. The router shows it
/// whenever `TenantCubit` needs a choice (or could not load the directory).
class TenantPickerPage extends StatelessWidget {
  const TenantPickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<TenantCubit, TenantState>(
      builder: (context, state) {
        final cubit = context.read<TenantCubit>();
        final current = state.config?.tenant.slug;
        // Android back closes the picker (keeping the current provider) when
        // there is one; with no provider chosen yet it leaves the app.
        return PopScope(
          canPop: current == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) cubit.cancelPicker();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.tenantPickerTitle),
              automaticallyImplyLeading: false,
              actions: [
                if (current != null)
                  IconButton(tooltip: l10n.commonCancel, icon: const Icon(Icons.close), onPressed: cubit.cancelPicker),
              ],
            ),
            body: switch (state.status) {
              TenantStatus.initial || TenantStatus.loading => const Center(child: CircularProgressIndicator()),
              TenantStatus.failure when state.tenants.isEmpty => FailureView(
                failure: state.failure,
                onRetry: cubit.retry,
              ),
              _ => ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  if (state.status == TenantStatus.failure) ...[
                    FailureView(failure: state.failure, onRetry: cubit.retry, compact: true),
                    const SizedBox(height: 16),
                  ],
                  Text(l10n.tenantPickerSubtitle, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  for (final tenant in state.tenants) ...[
                    Card(
                      child: ListTile(
                        minTileHeight: 64,
                        selected: tenant.slug == current,
                        leading: SizedBox(
                          width: 48,
                          child: Center(child: TenantLogo(tenant: tenant, decorative: true)),
                        ),
                        title: Text(tenant.name),
                        subtitle: Text(tenant.isReseller ? l10n.tenantTypeReseller : l10n.tenantTypeOperator),
                        trailing: Icon(tenant.slug == current ? Icons.check_circle : Icons.chevron_right),
                        onTap: () => _choose(context, tenant, current),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            },
          ),
        );
      },
    );
  }

  Future<void> _choose(BuildContext context, Tenant tenant, String? current) async {
    final cubit = context.read<TenantCubit>();
    if (current != null && current != tenant.slug) {
      final l10n = context.l10n;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.tenantChangeTitle),
          content: Text(l10n.tenantChangeBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.commonCancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.tenantChangeConfirm)),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await cubit.select(tenant);
  }
}
