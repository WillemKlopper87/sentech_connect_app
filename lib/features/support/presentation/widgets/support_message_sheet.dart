import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/domain/entities/support_message.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/support_message_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/support_failure_message.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the "message support" form as a bottom sheet. [fallbackEmail] is the
/// address the "Email us instead" button opens, and only when the provider has
/// no support inbox on the platform (`support_contact_not_configured`).
Future<void> showSupportMessageSheet(
  BuildContext context, {
  SupportTopic topic = SupportTopic.connecting,
  String? fallbackEmail,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BlocProvider(
      create: (_) => SupportMessageCubit(locator()),
      child: SupportMessageForm(
        initialTopic: topic,
        fallbackEmail: fallbackEmail,
      ),
    ),
  );
}

/// The form itself; needs a [SupportMessageCubit] above it.
class SupportMessageForm extends StatefulWidget {
  const SupportMessageForm({
    super.key,
    this.initialTopic = SupportTopic.connecting,
    this.fallbackEmail,
    this.openEmail,
  });

  final SupportTopic initialTopic;
  final String? fallbackEmail;

  /// Test seam for the email fallback; defaults to `launchUrl`.
  final Future<bool> Function(Uri uri)? openEmail;

  @override
  State<SupportMessageForm> createState() => _SupportMessageFormState();
}

class _SupportMessageFormState extends State<SupportMessageForm> {
  late SupportTopic _topic = widget.initialTopic;
  SupportContactKind _kind = SupportContactKind.email;
  final _contact = TextEditingController();
  final _message = TextEditingController();
  final _orderRef = TextEditingController();

  @override
  void dispose() {
    _contact.dispose();
    _message.dispose();
    _orderRef.dispose();
    super.dispose();
  }

  SupportMessageDraft get _draft => SupportMessageDraft(
    topic: _topic,
    contactKind: _kind,
    contact: _contact.text,
    message: _message.text,
    orderRef: _orderRef.text,
  );

  Future<void> _emailInstead() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri(
      scheme: 'mailto',
      path: widget.fallbackEmail,
      query:
          'subject=${Uri.encodeComponent(l10n.supportEmailSubject(supportTopicLabel(l10n, _topic)))}'
          '&body=${Uri.encodeComponent(_message.text.trim())}',
    );
    bool opened;
    try {
      opened = await (widget.openEmail ?? launchUrl)(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.supportTicketNoEmail)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return BlocBuilder<SupportMessageCubit, SupportMessageState>(
      builder: (context, state) {
        if (state.status == SupportSendStatus.sent) {
          return _Sent(reference: state.receipt!.reference);
        }
        final sending = state.status == SupportSendStatus.sending;
        final failure = state.failure;
        final errorText = state.issue != null
            ? supportIssueMessage(l10n, state.issue!)
            : failure != null
            ? supportFailureMessage(l10n, failure)
            : null;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.supportComposeTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<SupportTopic>(
                initialValue: _topic,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.supportTopicLabel),
                items: [
                  for (final t in SupportTopic.values)
                    DropdownMenuItem(
                      value: t,
                      child: Text(supportTopicLabel(l10n, t)),
                    ),
                ],
                onChanged: sending ? null : (t) => setState(() => _topic = t!),
              ),
              const SizedBox(height: 12),
              SegmentedButton<SupportContactKind>(
                segments: [
                  ButtonSegment(
                    value: SupportContactKind.email,
                    label: Text(l10n.supportContactKindEmail),
                  ),
                  ButtonSegment(
                    value: SupportContactKind.phone,
                    label: Text(l10n.supportContactKindPhone),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: sending
                    ? null
                    : (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('support-contact'),
                controller: _contact,
                enabled: !sending,
                keyboardType: _kind == SupportContactKind.email
                    ? TextInputType.emailAddress
                    : TextInputType.phone,
                autofillHints: [
                  _kind == SupportContactKind.email
                      ? AutofillHints.email
                      : AutofillHints.telephoneNumber,
                ],
                decoration: InputDecoration(
                  labelText: _kind == SupportContactKind.email
                      ? l10n.supportContactEmailLabel
                      : l10n.supportContactPhoneLabel,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('support-message'),
                controller: _message,
                enabled: !sending,
                minLines: 4,
                maxLines: 6,
                maxLength: SupportMessageDraft.maxMessage,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.supportMessageLabel,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                key: const Key('support-order-ref'),
                controller: _orderRef,
                enabled: !sending,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: l10n.supportOrderRefLabel,
                  counterText: '',
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    errorText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
              if (failure is SupportContactNotConfiguredFailure &&
                  widget.fallbackEmail != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _emailInstead,
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: Text(l10n.supportEmailInstead),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: sending
                    ? null
                    : () => context.read<SupportMessageCubit>().send(_draft),
                child: sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.supportSendMessage),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Sent extends StatelessWidget {
  const _Sent({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.supportSentTitle,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(l10n.supportSentBody, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          SelectableText(
            l10n.supportSentReference(reference),
            key: const Key('support-reference'),
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l10n.supportDone),
          ),
        ],
      ),
    );
  }
}
