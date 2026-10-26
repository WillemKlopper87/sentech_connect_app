import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/core/local/data_saver.dart';
import 'package:sentech_connect_app/core/notifications/notification_permission_cubit.dart';
import 'package:sentech_connect_app/core/notifications/notification_service.dart';
import 'package:sentech_connect_app/features/passes/domain/usage_alert_scheduler.dart';
import 'package:sentech_connect_app/features/account/presentation/widgets/delete_account_dialog.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/privacy/presentation/bloc/privacy_actions_cubit.dart';
import 'package:sentech_connect_app/features/privacy/presentation/pages/data_export_page.dart';
import 'package:sentech_connect_app/features/privacy/presentation/privacy_failure_message.dart';
import 'package:sentech_connect_app/features/privacy/presentation/widgets/legal_reading_links.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/actions/support_actions.dart';
import 'package:sentech_connect_app/shared/widgets/notification_rationale_sheet.dart';
import 'package:sentech_connect_app/shared/widgets/secure_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Profile, appearance, language, notifications and privacy controls. Shows
/// the customer's name and mobile number, so the screen is capture-protected
/// (FLAG_SECURE) while it is visible.
class AccountPage extends StatelessWidget {
  const AccountPage({
    super.key,
    this.onChangeProvider,
    this.providerName,
    this.onOpenPasses,
  });

  final VoidCallback? onChangeProvider;
  final String? providerName;

  /// Opens the customer passes. The row is hidden without it.
  final VoidCallback? onOpenPasses;

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
          onOpenPasses: onOpenPasses,
        ),
      ),
    );
  }
}

class _AccountView extends StatelessWidget {
  const _AccountView({
    this.onChangeProvider,
    this.providerName,
    this.onOpenPasses,
  });

  final VoidCallback? onChangeProvider;
  final String? providerName;
  final VoidCallback? onOpenPasses;

  /// Language codes, empty meaning "match the device".
  String _languageName(BuildContext context, String code) => switch (code) {
    'en' => context.l10n.languageEnglish,
    'zu' => context.l10n.languageZulu,
    'af' => context.l10n.languageAfrikaans,
    _ => context.l10n.accountLanguageSystem,
  };

  String _themeName(BuildContext context, ThemeMode mode) => switch (mode) {
    ThemeMode.system => context.l10n.accountThemeSystem,
    ThemeMode.light => context.l10n.accountThemeLight,
    ThemeMode.dark => context.l10n.accountThemeDark,
  };

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
        } else if (state.status == PrivacyActionStatus.failed &&
            state.action == PrivacyAction.export) {
          // Delete failures are shown inside the delete dialog.
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
              _Bordered(
                child: Column(
                  children: [
                    if (onOpenPasses case final openPasses?) ...[
                      ListTile(
                        minTileHeight: 48,
                        leading: const Icon(Icons.confirmation_number_outlined),
                        title: Text(l10n.passesTitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: openPasses,
                      ),
                      const Divider(height: 1),
                    ],
                    ListTile(
                      minTileHeight: 48,
                      leading: const Icon(Icons.language),
                      title: Text(l10n.accountLanguage),
                      subtitle: Text(
                        _languageName(context, locale?.languageCode ?? ''),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showChoiceSheet<String>(
                        context,
                        title: l10n.accountLanguage,
                        selected: locale?.languageCode ?? '',
                        options: [
                          for (final code in const ['', 'en', 'zu', 'af'])
                            (code, _languageName(context, code)),
                        ],
                        onSelected: (code) => context
                            .read<LocaleCubit>()
                            .setLocale(code.isEmpty ? null : Locale(code)),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      minTileHeight: 48,
                      leading: const Icon(Icons.brightness_6_outlined),
                      title: Text(l10n.accountAppearance),
                      subtitle: Text(_themeName(context, themeMode)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showChoiceSheet<ThemeMode>(
                        context,
                        title: l10n.accountAppearance,
                        selected: themeMode,
                        options: [
                          for (final mode in ThemeMode.values)
                            (mode, _themeName(context, mode)),
                        ],
                        onSelected: context.read<ThemeCubit>().setMode,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              const _UsageAlertsTile(),
              const SizedBox(height: 8),
              const _NotificationsTile(),
              _ContactProviderRow(providerName: providerName),
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
              if (onChangeProvider case final changeProvider?) ...[
                const SizedBox(height: 16),
                _Bordered(
                  child: ListTile(
                    minTileHeight: 48,
                    leading: const Icon(Icons.swap_horiz),
                    title: Text(l10n.accountSwitchProvider),
                    subtitle: providerName == null ? null : Text(providerName!),
                    onTap: changeProvider,
                  ),
                ),
              ],
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

  /// Two steps (confirm, then the SMS code); see [showDeleteAccountDialog].
  Future<void> _confirmDelete(BuildContext context) => showDeleteAccountDialog(context);
}

/// A bottom sheet with one radio per option. Choosing one applies it and closes the sheet.
Future<void> _showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required T selected,
  required List<(T, String)> options,
  required ValueChanged<T> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetTitle(title),
            RadioGroup<T>(
              groupValue: selected,
              onChanged: (value) {
                if (value == null) return;
                onSelected(value);
                Navigator.pop(sheetContext);
              },
              child: Column(
                children: [
                  for (final (value, label) in options)
                    RadioListTile<T>(value: value, title: Text(label)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
    child: Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

/// "Contact {provider}": one row, shown only when the provider published at
/// least one usable channel. Every channel was validated when the config was
/// read, so nothing unusable can reach a link here.
class _ContactProviderRow extends StatelessWidget {
  const _ContactProviderRow({this.providerName});

  final String? providerName;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TenantCubit?>();
    if (cubit == null) return const SizedBox.shrink();
    return BlocBuilder<TenantCubit, TenantState>(
      builder: (context, state) {
        final config = state.config;
        final email = config?.support.email;
        final phone = config?.support.phone;
        final whatsApp = supportWhatsAppUri(
          config?.tenant.branding.whatsAppNumber,
        );
        if (email == null && phone == null && whatsApp == null) {
          return const SizedBox.shrink();
        }
        final name = providerName ?? config?.tenant.name ?? '';
        final label = context.l10n.accountContactProvider(name);
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _Bordered(
            child: ListTile(
              minTileHeight: 48,
              leading: const Icon(Icons.support_agent_outlined),
              title: Text(label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showContactSheet(
                context,
                title: label,
                email: email,
                phone: phone,
                whatsApp: whatsApp,
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _showContactSheet(
  BuildContext context, {
  required String title,
  String? email,
  String? phone,
  Uri? whatsApp,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final failed = context.l10n.accountLinkFailed;
  final whatsAppLabel = context.l10n.supportWhatsApp;
  Widget action(
    BuildContext sheetContext, {
    required IconData icon,
    required String text,
    required Uri uri,
    LaunchMode mode = LaunchMode.platformDefault,
  }) => ListTile(
    minTileHeight: 48,
    leading: Icon(icon),
    title: Text(text),
    onTap: () async {
      Navigator.pop(sheetContext);
      bool opened;
      try {
        opened = await launchUrl(uri, mode: mode);
      } catch (_) {
        opened = false;
      }
      if (!opened) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failed)));
      }
    },
  );

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetTitle(title),
            if (email != null)
              action(
                sheetContext,
                icon: Icons.mail_outline,
                text: email,
                uri: Uri(scheme: 'mailto', path: email),
              ),
            if (phone != null)
              action(
                sheetContext,
                icon: Icons.call_outlined,
                text: phone,
                uri: Uri(scheme: 'tel', path: phone.replaceAll(' ', '')),
              ),
            if (whatsApp != null)
              action(
                sheetContext,
                icon: Icons.chat_outlined,
                text: whatsAppLabel,
                uri: whatsApp,
                mode: LaunchMode.externalApplication,
              ),
          ],
        ),
      ),
    ),
  );
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

class _UsageAlertsTile extends StatefulWidget {
  const _UsageAlertsTile();
  @override
  State<_UsageAlertsTile> createState() => _UsageAlertsTileState();
}

class _UsageAlertsTileState extends State<_UsageAlertsTile> {
  bool enabled = false;
  UsageAlertCoordinator? get coordinator =>
      locator.isRegistered<UsageAlertCoordinator>()
      ? locator<UsageAlertCoordinator>()
      : null;

  @override
  void initState() {
    super.initState();
    coordinator?.isEnabled().then((value) {
      if (mounted) setState(() => enabled = value);
    });
  }

  Future<void> _change(bool value) async {
    final alerts = coordinator;
    if (alerts == null || !alerts.isAvailable) return;
    if (value) {
      final permission = await showNotificationRationale(context);
      if (permission != NotificationPermissionStatus.granted || !mounted) {
        return;
      }
    }
    await alerts.setEnabled(value);
    final saved = await alerts.isEnabled();
    if (mounted) setState(() => enabled = saved);
  }

  @override
  Widget build(BuildContext context) => _Bordered(
    child: SwitchListTile(
      title: Text(context.l10n.accountUsageAlerts),
      subtitle: coordinator?.isAvailable == true
          ? null
          : Text(context.l10n.accountUsageAlertsUnavailable),
      value: enabled && coordinator?.isAvailable == true,
      onChanged: coordinator?.isAvailable == true ? _change : null,
    ),
  );
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
