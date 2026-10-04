import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/core/local/data_saver.dart';
import 'package:sentech_connect_app/core/notifications/notification_permission_cubit.dart';
import 'package:sentech_connect_app/core/notifications/notification_service.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/privacy/presentation/bloc/privacy_actions_cubit.dart';
import 'package:sentech_connect_app/features/privacy/presentation/pages/data_export_page.dart';
import 'package:sentech_connect_app/features/privacy/presentation/privacy_failure_message.dart';
import 'package:sentech_connect_app/features/privacy/presentation/widgets/legal_reading_links.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/notification_rationale_sheet.dart';
import 'package:sentech_connect_app/shared/widgets/secure_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Profile, appearance, language, notifications and privacy controls. Shows
/// the customer's name and mobile number, so the screen is capture-protected
/// (FLAG_SECURE) while it is visible.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key, this.onChangeProvider, this.providerName});

  final VoidCallback? onChangeProvider;
  final String? providerName;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              NotificationPermissionCubit(locator<NotificationService>()),
        ),
        BlocProvider(
          create: (context) {
            final auth = context.read<AuthCubit>();
            return PrivacyActionsCubit(
              locator(),
              onAccountDeleted: auth.signOutAndWipeEverything,
            );
          },
        ),
      ],
      child: SecureScreen(
        child: _AccountView(
          onChangeProvider: onChangeProvider,
          providerName: providerName,
        ),
      ),
    );
  }
}

class _AccountView extends StatelessWidget {
  const _AccountView({this.onChangeProvider, this.providerName});

  final VoidCallback? onChangeProvider;
  final String? providerName;

  List<(Locale?, String?)> _languages(BuildContext context) => [
    (null, null),
    (const Locale('en'), context.l10n.languageEnglish),
    (const Locale('zu'), context.l10n.languageZulu),
    (const Locale('af'), context.l10n.languageAfrikaans),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final user = context.watch<AuthCubit>().state.user;
    final themeMode = context.watch<ThemeCubit>().state;
    final locale = context.watch<LocaleCubit>().state;
    final heading = theme.textTheme.labelLarge?.copyWith(letterSpacing: 0.6);

    return BlocListener<PrivacyActionsCubit, PrivacyActionsState>(
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (state.status == PrivacyActionStatus.exportRequested) {
          final json = state.receipt?.exportJson;
          if (json != null) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DataExportPage(json: json),
              ),
            );
          } else {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(l10n.accountDownloadDataDone)),
              );
          }
        } else if (state.status == PrivacyActionStatus.failed) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(privacyFailureMessage(l10n, state.failure)),
              ),
            );
        }
        // On `deleted` the auth guard has already sent the user to /login.
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.accountTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.14,
                    ),
                    child: Text(
                      (user?.fullName.isNotEmpty ?? false)
                          ? user!.fullName[0].toUpperCase()
                          : '?',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? l10n.accountNotLoggedIn,
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          user?.mobileNumber ?? '',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(l10n.accountAppearance, style: heading),
              const SizedBox(height: 8),
              _Bordered(
                child: RadioGroup<ThemeMode>(
                  groupValue: themeMode,
                  onChanged: (m) => context.read<ThemeCubit>().setMode(m!),
                  child: Column(
                    children: ThemeMode.values.map((mode) {
                      return RadioListTile<ThemeMode>(
                        value: mode,
                        title: Text(switch (mode) {
                          ThemeMode.system => l10n.accountThemeSystem,
                          ThemeMode.light => l10n.accountThemeLight,
                          ThemeMode.dark => l10n.accountThemeDark,
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(l10n.accountLanguage, style: heading),
              const SizedBox(height: 8),
              _Bordered(
                child: RadioGroup<String>(
                  groupValue: locale?.languageCode ?? '',
                  onChanged: (code) => context.read<LocaleCubit>().setLocale(
                    code == null || code.isEmpty ? null : Locale(code),
                  ),
                  child: Column(
                    children: [
                      for (final (loc, name) in _languages(context))
                        RadioListTile<String>(
                          value: loc?.languageCode ?? '',
                          title: Text(name ?? l10n.accountLanguageSystem),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _Bordered(
                child: SwitchListTile(
                  title: Text(l10n.accountDataSaver),
                  value: context.watch<DataSaverCubit?>()?.state ?? false,
                  onChanged: (on) async {
                    final saver = context.read<DataSaverCubit?>();
                    if (saver == null) return;
                    try {
                      await saver.set(on);
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n.accountDataSaverSaveFailed,
                            ),
                          ),
                        );
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              if (onChangeProvider case final changeProvider?) ...[
                Text(l10n.accountProvider, style: heading),
                const SizedBox(height: 8),
                _Bordered(
                  child: ListTile(
                    minTileHeight: 48,
                    leading: const Icon(Icons.swap_horiz),
                    title: Text(l10n.accountChangeProvider),
                    subtitle: providerName == null ? null : Text(providerName!),
                    onTap: changeProvider,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text(l10n.accountNotifications, style: heading),
              const SizedBox(height: 8),
              const _NotificationsTile(),
              const SizedBox(height: 24),
              Text(l10n.accountPrivacy, style: heading),
              const SizedBox(height: 8),
              _Bordered(
                child: Column(
                  children: [
                    ListTile(
                      minTileHeight: 48,
                      leading: const Icon(Icons.policy_outlined),
                      title: Text(l10n.accountPrivacyPolicy),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () => _openPolicy(context),
                    ),
                    const Divider(height: 1),
                    BlocBuilder<PrivacyActionsCubit, PrivacyActionsState>(
                      builder: (context, state) {
                        final working =
                            state.status == PrivacyActionStatus.working;
                        return Column(
                          children: [
                            ListTile(
                              minTileHeight: 48,
                              leading: const Icon(Icons.download_outlined),
                              title: Text(l10n.accountDownloadData),
                              enabled: !working,
                              onTap: () => context
                                  .read<PrivacyActionsCubit>()
                                  .requestDataExport(),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              minTileHeight: 48,
                              leading: Icon(
                                Icons.delete_forever_outlined,
                                color: theme.colorScheme.error,
                              ),
                              title: Text(
                                l10n.accountDeleteData,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              enabled: !working,
                              onTap: () => _confirmDelete(context),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout, size: 18),
                label: Text(l10n.accountLogOut),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPolicy(BuildContext context) async {
    bool opened;
    try {
      opened = await launchUrl(
        privacyReadingUrl(context),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.accountLinkFailed)));
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountLogOutTitle),
        content: Text(l10n.accountLogOutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.accountLogOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // The router guard moves the user to /login once the state flips.
    await context.read<AuthCubit>().logOut();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountDeleteTitle),
        content: Text(l10n.accountDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.accountDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<PrivacyActionsCubit>().deleteAccount();
  }
}

class _Bordered extends StatelessWidget {
  const _Bordered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: child,
    );
  }
}

class _NotificationsTile extends StatelessWidget {
  const _NotificationsTile();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return BlocBuilder<
      NotificationPermissionCubit,
      NotificationPermissionStatus
    >(
      builder: (context, status) {
        final granted = status == NotificationPermissionStatus.granted;
        final blocked =
            status == NotificationPermissionStatus.permanentlyDenied;
        return _Bordered(
          child: ListTile(
            minTileHeight: 48,
            leading: Icon(
              granted
                  ? Icons.notifications_active
                  : Icons.notifications_off_outlined,
            ),
            title: Text(l10n.accountPushTitle),
            subtitle: Text(
              granted
                  ? l10n.accountPushOn
                  : blocked
                  ? l10n.accountPushBlocked
                  : l10n.accountPushOff,
            ),
            trailing: granted
                ? null
                : TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () async {
                      final cubit = context.read<NotificationPermissionCubit>();
                      if (blocked) {
                        await cubit.requestOrOpenSettings();
                      } else {
                        // Explain first; the system prompt follows the sheet.
                        await showNotificationRationale(context);
                        await cubit.refresh();
                      }
                    },
                    child: Text(
                      blocked
                          ? l10n.accountPushOpenSettings
                          : l10n.accountPushTurnOn,
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
