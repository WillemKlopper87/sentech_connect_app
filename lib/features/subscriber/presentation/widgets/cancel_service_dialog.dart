import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/kyc/kyc_validators.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/service_actions.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/cancel_service_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/service_format.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/subscriber_failure_text.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// Asks for confirmation and a reason, then schedules the end of [service].
/// Returns the service as the platform now has it, or null when the customer
/// kept it (or the dialog was dismissed).
Future<SubscriberService?> showCancelServiceDialog(
  BuildContext context, {
  required SubscriberRepository repository,
  required SubscriberService service,
  DateTime Function()? clock,
}) {
  final today = KycValidators.sastDate((clock ?? DateTime.now)());
  return showDialog<SubscriberService>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider(
      create: (_) => CancelServiceCubit(repository, service),
      child: CancelServiceDialog(endsOn: cancellationEndDate(service, today)),
    ),
  );
}

String _reasonLabel(AppLocalizations l10n, CancelReason reason) => switch (reason) {
  CancelReason.moving => l10n.cancelReasonMoving,
  CancelReason.tooExpensive => l10n.cancelReasonExpensive,
  CancelReason.notReliable => l10n.cancelReasonUnreliable,
  CancelReason.other => l10n.cancelReasonOther,
};

/// The confirm dialog. Needs a [CancelServiceCubit] above it.
class CancelServiceDialog extends StatefulWidget {
  const CancelServiceDialog({super.key, required this.endsOn});

  /// The day the service will end (see [cancellationEndDate]).
  final DateTime endsOn;

  @override
  State<CancelServiceDialog> createState() => _CancelServiceDialogState();
}

class _CancelServiceDialogState extends State<CancelServiceDialog> {
  CancelReason? _reason;
  final _detail = TextEditingController();

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return BlocConsumer<CancelServiceCubit, CancelServiceState>(
      listenWhen: (a, b) => a.status != b.status && b.status == CancelServiceStatus.done,
      listener: (context, state) => Navigator.of(context).pop(state.service),
      builder: (context, state) {
        final busy = state.status == CancelServiceStatus.submitting;
        final failure = state.failure;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(l10n.cancelDialogTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.cancelDialogBody(formatApiDay(context, widget.endsOn)), key: const Key('cancel-body')),
                  const SizedBox(height: 8),
                  Text(l10n.cancelDialogNoUndo, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 16),
                  Text(l10n.cancelReasonLabel, style: theme.textTheme.titleSmall),
                  RadioGroup<CancelReason>(
                    groupValue: _reason,
                    onChanged: (value) {
                      if (!busy) setState(() => _reason = value);
                    },
                    child: Column(
                      children: [
                        for (final reason in CancelReason.values)
                          RadioListTile<CancelReason>(
                            key: Key('cancel-reason-${reason.name}'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: reason,
                            title: Text(_reasonLabel(l10n, reason)),
                          ),
                      ],
                    ),
                  ),
                  TextField(
                    key: const Key('cancel-detail'),
                    controller: _detail,
                    enabled: !busy,
                    maxLength: 120,
                    decoration: InputDecoration(labelText: l10n.cancelReasonDetailLabel),
                  ),
                  if (state.reasonMissing && _reason == null)
                    Text(l10n.cancelReasonRequired, key: const Key('cancel-reason-required'), style: TextStyle(color: theme.colorScheme.error)),
                  if (failure != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        subscriberFailureText(l10n, failure),
                        key: const Key('cancel-failure'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                key: const Key('cancel-keep'),
                onPressed: busy ? null : () => Navigator.of(context).pop(),
                child: Text(l10n.cancelKeep),
              ),
              FilledButton(
                key: const Key('cancel-confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: busy ? null : () => context.read<CancelServiceCubit>().submit(_reason, _detail.text),
                child: Text(busy ? l10n.cancelSubmitting : l10n.cancelConfirm),
              ),
            ],
          ),
        );
      },
    );
  }
}
