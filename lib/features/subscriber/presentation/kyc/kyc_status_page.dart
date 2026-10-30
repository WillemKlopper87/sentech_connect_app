import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/kyc/kyc_validators.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/kyc/kyc_labels.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/kyc/kyc_status_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';
import 'package:sentech_connect_app/shared/widgets/secure_screen.dart';

/// "ID check": none / pending / verified / rejected, with the one action each
/// state allows. Shows the ID type and last four characters, so it is
/// capture-protected (FLAG_SECURE) while visible. Needs a [KycStatusCubit]
/// above it; [onOpenForm] opens the form and completes when it is closed, after
/// which the status is read again.
class KycStatusPage extends StatelessWidget {
  const KycStatusPage({super.key, required this.onOpenForm});

  final Future<void> Function() onOpenForm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.kycTitle)),
        body: SafeArea(
          child: BlocBuilder<KycStatusCubit, KycStatusState>(
            builder: (context, state) {
              final cubit = context.read<KycStatusCubit>();
              Future<void> open() async {
                await onOpenForm();
                if (context.mounted) await cubit.load();
              }

              return switch (state.load) {
                KycStatusLoad.loading => const Center(child: CircularProgressIndicator()),
                KycStatusLoad.failure when state.noAccount => _Message(
                  key: const Key('kyc-no-account'),
                  icon: Icons.info_outline,
                  title: l10n.kycNoAccount,
                ),
                KycStatusLoad.failure => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: FailureView(failure: state.failure, onRetry: cubit.load)),
                ),
                KycStatusLoad.loaded => RefreshIndicator(
                  onRefresh: cubit.load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [_StatusBody(record: state.record, onOpenForm: open)],
                  ),
                ),
              };
            },
          ),
        ),
      ),
    );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({required this.record, required this.onOpenForm});

  final KycRecord? record;
  final VoidCallback onOpenForm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final record = this.record;
    final (icon, color, title, body, action, actionLabel) = switch (record?.status) {
      null => (Icons.badge_outlined, theme.colorScheme.primary, l10n.kycNoneTitle, l10n.kycNoneBody, true, l10n.kycStart),
      KycStatus.pending => (
        Icons.hourglass_top,
        theme.colorScheme.primary,
        l10n.kycPendingTitle,
        l10n.kycPendingBody,
        false,
        '',
      ),
      KycStatus.verified => (
        Icons.verified_outlined,
        theme.colorScheme.primary,
        l10n.kycVerifiedTitle,
        l10n.kycVerifiedBody,
        false,
        '',
      ),
      KycStatus.rejected => (
        Icons.error_outline,
        theme.colorScheme.error,
        l10n.kycRejectedTitle,
        l10n.kycRejectedBody,
        true,
        l10n.kycSubmitAgain,
      ),
    };
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    String date(DateTime instant) => DateFormat.yMMMd(localeTag).format(KycValidators.sastDate(instant));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 48, color: color),
        const SizedBox(height: 12),
        Text(title, key: const Key('kyc-status-title'), textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        if (record != null) ...[
          const SizedBox(height: 20),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.kycEndingIn(kycIdTypeLabel(l10n, record.idType), record.idNumberLast4),
                    key: const Key('kyc-status-id'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.verifiedAt != null
                        ? l10n.kycVerifiedOn(date(record.verifiedAt!))
                        : l10n.kycSentOn(date(record.consentAt)),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (action) ...[
          const SizedBox(height: 24),
          FilledButton(key: const Key('kyc-start'), onPressed: onOpenForm, child: Text(actionLabel)),
        ],
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
