import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/new_ticket_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/tickets_text.dart';
import 'package:sentech_connect_app/features/support/presentation/widgets/ticket_status_chip.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// Opens a ticket. Needs a [NewTicketCubit] above it.
///
/// The text lives only in this page's text field, in memory, while the page is
/// open: it is not restored after the app is killed, not put in a route, and
/// cleared when the ticket has been sent.
class NewTicketPage extends StatefulWidget {
  const NewTicketPage({super.key, required this.onOpenTicket, required this.onDone});

  final void Function(String reference) onOpenTicket;
  final VoidCallback onDone;

  @override
  State<NewTicketPage> createState() => _NewTicketPageState();
}

class _NewTicketPageState extends State<NewTicketPage> {
  final _body = TextEditingController();
  String? _category;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _body.dispose();
    super.dispose();
  }

  /// Counts the wait down once a second while sending is held.
  void _syncTicker(bool held) {
    if (held && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!held && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<NewTicketCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.ticketsNewTitle)),
      body: SafeArea(
        child: BlocConsumer<NewTicketCubit, NewTicketState>(
          listener: (context, state) {
            // The ticket was sent: the draft is gone.
            if (state.status == NewTicketStatus.done) _body.clear();
            // The topic the customer picked is no longer offered.
            if (_category != null && state.categoriesStatus == CategoriesStatus.ready && !state.categories.any((c) => c.key == _category)) {
              setState(() => _category = null);
            }
          },
          builder: (context, state) {
            final wait = state.retryAt?.difference(cubit.now());
            final held = wait != null && wait > Duration.zero;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _syncTicker(held);
            });
            if (state.status == NewTicketStatus.done) return _Done(reference: state.reference!, onOpen: widget.onOpenTicket, onDone: widget.onDone);
            if (state.status == NewTicketStatus.unavailable) {
              return Center(
                child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.ticketsUnavailable, textAlign: TextAlign.center)),
              );
            }
            return switch (state.categoriesStatus) {
              CategoriesStatus.loading => const Center(child: CircularProgressIndicator()),
              CategoriesStatus.unavailable => Center(
                child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.ticketsUnavailable, textAlign: TextAlign.center)),
              ),
              CategoriesStatus.error => FailureView(failure: state.failure, onRetry: cubit.loadCategories),
              CategoriesStatus.ready => _form(context, state, held ? wait : null),
            };
          },
        ),
      ),
    );
  }

  Widget _form(BuildContext context, NewTicketState state, Duration? wait) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cubit = context.read<NewTicketCubit>();
    final sending = state.status == NewTicketStatus.submitting;
    final issue = state.issue;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ..._notices(context, state, wait),
        InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.ticketsNewCategoryLabel,
            errorText: issue == NewTicketIssue.noCategory ? ticketIssueMessage(l10n, issue!, ticketBodyMaxLength) : null,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const Key('ticket-category-field'),
              value: _category,
              isExpanded: true,
              hint: Text(l10n.ticketsNewCategoryHint),
              items: [
                for (final category in state.categories) DropdownMenuItem(value: category.key, child: Text(category.name)),
              ],
              onChanged: sending ? null : (value) => setState(() => _category = value),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('ticket-body-field'),
          controller: _body,
          enabled: !sending,
          minLines: 5,
          maxLines: 10,
          maxLength: ticketBodyMaxLength,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          // What the customer writes to support is personal: the keyboard does not learn from it.
          enableIMEPersonalizedLearning: false,
          decoration: InputDecoration(
            labelText: l10n.ticketsNewBodyLabel,
            helperText: l10n.ticketsNewBodyHelper,
            helperMaxLines: 2,
            alignLabelWithHint: true,
            errorText: issue == NewTicketIssue.bodyEmpty || issue == NewTicketIssue.bodyTooLong
                ? ticketIssueMessage(l10n, issue!, ticketBodyMaxLength)
                : null,
            errorMaxLines: 3,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('ticket-send'),
          onPressed: sending || wait != null ? null : () => cubit.submit(categoryKey: _category, body: _body.text),
          child: sending
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.ticketsNewSend),
        ),
        if (state.failure != null && state.notice == NewTicketNotice.none)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(ticketFailureMessage(l10n, state.failure), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
          ),
      ],
    );
  }

  List<Widget> _notices(BuildContext context, NewTicketState state, Duration? wait) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tag = Localizations.localeOf(context).toLanguageTag();
    Widget box(IconData icon, String text, {List<Widget> extra = const []}) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
                ],
              ),
              ...extra,
            ],
          ),
        ),
      ),
    );
    return [
      if (wait != null)
        box(Icons.hourglass_bottom, l10n.ticketsHeldRateLimit(ticketWaitText(l10n, wait)))
      else if (state.notice == NewTicketNotice.unknownOutcome)
        box(Icons.info_outline, l10n.ticketsUnknownOutcome)
      else if (state.notice == NewTicketNotice.checkFirst)
        box(
          Icons.info_outline,
          l10n.ticketsCheckFirst,
          extra: [
            if (state.recent.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l10n.ticketsCheckFirstTitle, style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              for (final ticket in state.recent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(l10n.ticketsReference(ticket.reference), style: theme.textTheme.bodySmall),
                      Text(ticketDate(tag, ticket.createdAt), style: theme.textTheme.bodySmall),
                      TicketStatusChip(status: ticket.status),
                    ],
                  ),
                ),
            ],
          ],
        ),
    ];
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.reference, required this.onOpen, required this.onDone});

  final String reference;
  final void Function(String reference) onOpen;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.check_circle_outline, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(l10n.ticketsNewDoneTitle, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(l10n.ticketsNewDoneBody(reference), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 24),
        FilledButton(key: const Key('ticket-done-view'), onPressed: () => onOpen(reference), child: Text(l10n.ticketsNewDoneView)),
        const SizedBox(height: 8),
        OutlinedButton(key: const Key('ticket-done-close'), onPressed: onDone, child: Text(l10n.ticketsNewDoneClose)),
      ],
    );
  }
}
