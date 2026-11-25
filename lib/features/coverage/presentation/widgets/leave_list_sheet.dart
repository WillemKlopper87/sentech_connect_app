import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';
import 'package:sentech_connect_app/features/coverage/domain/repositories/coverage_repository.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/withdrawal_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/coverage_text.dart';
import 'package:sentech_connect_app/features/coverage/presentation/widgets/contact_input.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// Starts leaving the waiting list. The platform sends a one-time link to the contact; the
/// contact is removed only when that link is opened and confirmed on the website, so this
/// sheet never says the contact was removed, and it does not say whether the contact was on
/// the list (the platform does not either). Needs a [CoverageRepository] above it.
class LeaveListSheet extends StatelessWidget {
  const LeaveListSheet({super.key});

  static Future<void> show(BuildContext context) {
    final repository = context.read<CoverageRepository>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => RepositoryProvider<CoverageRepository>.value(value: repository, child: const LeaveListSheet()),
    );
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => WithdrawalCubit(context.read<CoverageRepository>()),
    child: const _LeaveForm(),
  );
}

class _LeaveForm extends StatefulWidget {
  const _LeaveForm();

  @override
  State<_LeaveForm> createState() => _LeaveFormState();
}

class _LeaveFormState extends State<_LeaveForm> {
  final _contact = TextEditingController();
  var _kind = ContactKind.phone;
  var _touched = false;

  @override
  void dispose() {
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return BlocBuilder<WithdrawalCubit, WithdrawalState>(
      builder: (context, state) {
        final bottom = MediaQuery.viewInsetsOf(context).bottom;
        if (state.status == WithdrawalStatus.requested) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.mark_email_read_outlined, size: 36, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(l10n.coverageLeaveRequested, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(l10n.coverageNotifyDone)),
              ],
            ),
          );
        }
        final submitting = state.status == WithdrawalStatus.submitting;
        final failure = state.failure;
        final canSend = !submitting && isPlausibleContact(_kind, _contact.text);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text(l10n.coverageLeaveTitle, style: theme.textTheme.titleLarge)),
              const SizedBox(height: 8),
              Text(l10n.coverageLeaveIntro),
              const SizedBox(height: 16),
              ContactInput(
                fieldKey: const ValueKey('leave-contact'),
                controller: _contact,
                kind: _kind,
                showError: _touched,
                onKindChanged: (kind) => setState(() {
                  _kind = kind;
                  _contact.clear();
                  _touched = false;
                }),
                onChanged: () => setState(() => _touched = true),
              ),
              if (failure != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(coverageFailureText(l10n, failure), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: canSend
                    ? () => context.read<WithdrawalCubit>().request(WithdrawalRequest(contactType: _kind, contactValue: _contact.text.trim()))
                    : null,
                child: submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.coverageLeaveSend),
              ),
            ],
          ),
        );
      },
    );
  }
}
