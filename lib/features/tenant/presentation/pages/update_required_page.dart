import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// Shown instead of every screen when app-config's min_app_version is newer
/// than this build. "Retry" re-reads the config (the minimum may be lowered).
class UpdateRequiredPage extends StatelessWidget {
  const UpdateRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(l10n.updateRequiredTitle, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(l10n.updateRequiredBody, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                OutlinedButton(onPressed: context.read<TenantCubit>().retry, child: Text(l10n.commonRetry)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
