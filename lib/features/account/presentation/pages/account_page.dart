import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.onLoggedOut});

  final VoidCallback onLoggedOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthCubit>().state.user;
    final themeMode = context.watch<ThemeCubit>().state;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.14),
                  child: Text(
                    (user?.fullName.isNotEmpty ?? false) ? user!.fullName[0].toUpperCase() : '?',
                    style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.fullName ?? 'Not logged in', style: theme.textTheme.titleLarge),
                      Text(
                        user?.mobileNumber ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text('APPEARANCE', style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0.6)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: RadioGroup<ThemeMode>(
                groupValue: themeMode,
                onChanged: (m) => context.read<ThemeCubit>().setMode(m!),
                child: Column(
                  children: ThemeMode.values.map((mode) {
                    return RadioListTile<ThemeMode>(
                      value: mode,
                      title: Text(switch (mode) {
                        ThemeMode.system => 'Match device setting',
                        ThemeMode.light => 'Light',
                        ThemeMode.dark => 'Dark',
                      }),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Log out'),
              style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can log back in at any time.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed == true) onLoggedOut();
  }
}
