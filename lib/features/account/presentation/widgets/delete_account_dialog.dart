import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/privacy/presentation/bloc/privacy_actions_cubit.dart';
import 'package:sentech_connect_app/features/privacy/presentation/privacy_failure_message.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// Deleting the account in two steps: confirm (we SMS a code to the number on
/// the account), then enter that code. Nothing is deleted, here or on the
/// phone, until the server accepted the code.
///
/// Uses the [PrivacyActionsCubit] of [context]. Resolves when the dialog is
/// closed (cancelled, or after the account was deleted).
Future<void> showDeleteAccountDialog(BuildContext context) async {
  final cubit = context.read<PrivacyActionsCubit>();
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider.value(value: cubit, child: const _DeleteAccountDialog()),
  );
  if (!cubit.isClosed) cubit.cancelDelete();
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final deleted = await context.read<PrivacyActionsCubit>().deleteAccount(_code.text);
    // The account page that owns the cubit is already gone once the wipe has
    // signed the customer out; this dialog sits above it and closes itself.
    if (deleted && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cubit = context.read<PrivacyActionsCubit>();
    return BlocBuilder<PrivacyActionsCubit, PrivacyActionsState>(
      builder: (context, state) {
        final working = state.working;
        final codeStep = state.deleteChallenge != null;
        final blocked = state.deleteBlocked;
        final deleteFailure = switch (state.action) {
          PrivacyAction.deleteCode || PrivacyAction.delete => state.failure,
          _ => null,
        };
        final error = deleteFailure == null ? null : privacyFailureMessage(l10n, deleteFailure);
        final reference = state.deleteChallenge?.reference;
        final resendLabel = state.resendIn > 0 ? l10n.otpResendIn(state.resendIn) : l10n.otpResend;

        if (blocked) {
          // Retrying cannot help (no phone on the account, or an active service).
          return AlertDialog(
            title: Text(l10n.accountDeleteTitle),
            content: Text(error ?? l10n.accountRequestFailed),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.accountDeleteClose)),
            ],
          );
        }

        return AlertDialog(
          title: Text(codeStep ? l10n.accountDeleteCodeTitle : l10n.accountDeleteTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(codeStep ? l10n.accountDeleteCodeBody : l10n.accountDeleteBody),
                if (codeStep) ...[
                  if (reference != null && reference.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.otpUseSmsReference(reference),
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    enabled: !working && !state.locked,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    autofocus: true,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.done,
                    onSubmitted: working || state.locked ? null : (_) => _delete(),
                    decoration: InputDecoration(
                      labelText: l10n.otpCodeHint,
                      border: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.outline)),
                      errorText: error,
                      errorMaxLines: 3,
                    ),
                  ),
                ] else if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error, style: TextStyle(color: theme.colorScheme.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: working ? null : () => Navigator.pop(context),
              child: Text(l10n.commonCancel),
            ),
            if (codeStep)
              TextButton(
                onPressed: working || state.resendIn > 0 ? null : cubit.requestDeleteCode,
                child: Text(resendLabel),
              ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
              onPressed: working || state.locked
                  ? null
                  : (codeStep ? _delete : cubit.requestDeleteCode),
              child: working
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(codeStep ? l10n.accountDeleteConfirm : l10n.accountDeleteSendCode),
            ),
          ],
        );
      },
    );
  }
}
