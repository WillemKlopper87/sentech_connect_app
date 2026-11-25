import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/tickets_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/tickets_text.dart';
import 'package:sentech_connect_app/features/support/presentation/widgets/ticket_status_chip.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// The customer's support tickets, newest first. Needs a [TicketsCubit] above it.
/// A ticket is opened by its reference, never an internal id.
class TicketsPage extends StatelessWidget {
  const TicketsPage({super.key, required this.onOpenTicket, required this.onNewTicket});

  final void Function(String reference) onOpenTicket;
  final VoidCallback onNewTicket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.ticketsTitle)),
      body: SafeArea(
        child: BlocBuilder<TicketsCubit, TicketsState>(
          builder: (context, state) => switch (state.status) {
            TicketsStatus.loading => const Center(child: CircularProgressIndicator()),
            TicketsStatus.unavailable => _Message(l10n.ticketsUnavailable),
            TicketsStatus.error => FailureView(failure: state.failure, onRetry: () => context.read<TicketsCubit>().refresh()),
            TicketsStatus.ready => RefreshIndicator(
              onRefresh: () => context.read<TicketsCubit>().refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  FilledButton.icon(
                    key: const Key('tickets-new-button'),
                    onPressed: onNewTicket,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.ticketsNewTitle),
                  ),
                  const SizedBox(height: 12),
                  if (state.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(l10n.ticketsEmpty, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  for (final ticket in state.items) _TicketTile(ticket: ticket, onTap: () => onOpenTicket(ticket.reference)),
                  if (state.moreFailure != null)
                    FailureView(failure: state.moreFailure, compact: true, onRetry: () => context.read<TicketsCubit>().loadMore())
                  else if (state.loadingMore)
                    const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                  else if (state.hasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton(
                        key: const Key('tickets-more'),
                        onPressed: () => context.read<TicketsCubit>().loadMore(),
                        child: Text(l10n.ticketsLoadMore),
                      ),
                    ),
                ],
              ),
            ),
          },
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
    ),
  );
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tag = Localizations.localeOf(context).toLanguageTag();
    final title = ticketCategoryLabel(l10n, ticket);
    final waiting = ticket.awaitingReply && !ticket.isClosed;
    return Semantics(
      container: true,
      button: true,
      label: '$title. ${ticketStatusLabel(l10n, ticket.status)}.${waiting ? ' ${l10n.ticketsAwaitingReply}.' : ''} ${l10n.ticketsReference(ticket.reference)}',
      excludeSemantics: true,
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          key: Key('ticket-${ticket.reference}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      TicketStatusChip(status: ticket.status),
                      if (waiting)
                        Text(
                          l10n.ticketsAwaitingReply,
                          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(l10n.ticketsReference(ticket.reference), style: theme.textTheme.bodySmall),
                  Text(l10n.ticketsOpenedOn(ticketDate(tag, ticket.createdAt)), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
