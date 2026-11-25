import 'package:flutter/material.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';
import 'package:sentech_connect_app/features/support/presentation/tickets_text.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// A ticket's status as an icon AND words, so it is never told by colour alone.
class TicketStatusChip extends StatelessWidget {
  const TicketStatusChip({super.key, required this.status});

  final TicketStatus status;

  static IconData iconFor(TicketStatus status) => switch (status) {
    TicketStatus.newTicket => Icons.inbox_outlined,
    TicketStatus.open => Icons.forum_outlined,
    TicketStatus.pendingCustomer => Icons.reply,
    TicketStatus.onHold => Icons.pause_circle_outline,
    TicketStatus.resolved => Icons.check_circle_outline,
    TicketStatus.closed => Icons.lock_outline,
    TicketStatus.unknown => Icons.help_outline,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = ticketStatusLabel(context.l10n, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(status), size: 16, color: theme.colorScheme.onSurface),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: theme.textTheme.labelMedium)),
        ],
      ),
    );
  }
}
