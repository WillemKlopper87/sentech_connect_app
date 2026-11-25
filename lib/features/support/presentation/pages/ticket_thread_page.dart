import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/ticket_thread_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/tickets_text.dart';
import 'package:sentech_connect_app/features/support/presentation/widgets/ticket_status_chip.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// One ticket with its messages, a reply box and a "mark as solved" action.
/// Needs a [TicketThreadCubit] above it. Only what the server returns is shown:
/// no internal notes (the customer route never sends them), no staff names, no
/// response-time promise. The thread is read on open and on pull to refresh.
///
/// The reply text lives only in this page's text field (memory) and is cleared
/// once the reply has been sent.
class TicketThreadPage extends StatefulWidget {
  const TicketThreadPage({super.key, required this.onNewTicket});

  final VoidCallback onNewTicket;

  @override
  State<TicketThreadPage> createState() => _TicketThreadPageState();
}

class _TicketThreadPageState extends State<TicketThreadPage> {
  final _reply = TextEditingController();
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _reply.dispose();
    super.dispose();
  }

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

  Future<void> _confirmSolved(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<TicketThreadCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.ticketsMarkSolvedTitle),
        content: Text(l10n.ticketsMarkSolvedBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.commonCancel)),
          FilledButton(
            key: const Key('ticket-mark-solved-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.ticketsMarkSolved),
          ),
        ],
      ),
    );
    if (ok == true) unawaited(cubit.closeTicket());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<TicketThreadCubit, ThreadState>(
      listenWhen: (previous, current) => previous.replyStatus != ReplyStatus.sent && current.replyStatus == ReplyStatus.sent,
      // The reply was sent: the draft is gone.
      listener: (context, state) => _reply.clear(),
      builder: (context, state) {
        final thread = state.thread;
        final title = thread == null ? l10n.ticketsTitle : ticketCategoryLabel(l10n, thread);
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(child: _body(context, state)),
        );
      },
    );
  }

  Widget _body(BuildContext context, ThreadState state) {
    final l10n = context.l10n;
    final cubit = context.read<TicketThreadCubit>();
    switch (state.status) {
      case ThreadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case ThreadStatus.unavailable:
        return _Message(l10n.ticketsUnavailable);
      case ThreadStatus.notFound:
        return _Message(l10n.failureTicketNotFound);
      case ThreadStatus.error:
        return FailureView(failure: state.failure, onRetry: cubit.load);
      case ThreadStatus.ready:
        break;
    }
    final thread = state.thread!;
    final wait = state.retryAt?.difference(cubit.now());
    final held = wait != null && wait > Duration.zero;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTicker(held);
    });
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: cubit.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              children: [
                _Header(thread: thread, state: state, onMarkSolved: () => _confirmSolved(context)),
                const SizedBox(height: 12),
                for (final message in thread.messages) _MessageBubble(message: message),
              ],
            ),
          ),
        ),
        _Composer(
          thread: thread,
          state: state,
          wait: held ? wait : null,
          controller: _reply,
          onNewTicket: widget.onNewTicket,
        ),
      ],
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

class _Header extends StatelessWidget {
  const _Header({required this.thread, required this.state, required this.onMarkSolved});

  final TicketThread thread;
  final ThreadState state;
  final VoidCallback onMarkSolved;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tag = Localizations.localeOf(context).toLanguageTag();
    final waiting = thread.awaitingReply && !thread.isClosed;
    final canSolve = !thread.isClosed && !thread.isResolved;
    final closeFailure = state.closeFailure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TicketStatusChip(status: thread.status),
            if (waiting)
              Text(l10n.ticketsAwaitingReply, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        Text(l10n.ticketsReference(thread.reference), style: theme.textTheme.bodySmall),
        Text(l10n.ticketsOpenedOn(ticketDate(tag, thread.createdAt)), style: theme.textTheme.bodySmall),
        if (canSolve) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('ticket-mark-solved'),
            onPressed: state.closing ? null : onMarkSolved,
            child: state.closing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.ticketsMarkSolved),
          ),
        ],
        if (closeFailure != null) ...[
          const SizedBox(height: 8),
          Text(ticketFailureMessage(l10n, closeFailure), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
          if (closeFailure is TicketChangedFailure || closeFailure is TicketAlreadyResolvedFailure || closeFailure is TicketClosedFailure)
            Text(l10n.ticketsChangedNotice, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final TicketMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tag = Localizations.localeOf(context).toLanguageTag();
    final mine = message.author == TicketAuthor.you;
    final author = ticketAuthorLabel(l10n, message.author);
    final body = message.body ?? l10n.ticketsMessageRemoved;
    return Semantics(
      container: true,
      label: '$author, ${ticketDateTime(tag, message.createdAt)}. $body',
      excludeSemantics: true,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: mine ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(mine ? Icons.person_outline : Icons.support_agent_outlined, size: 16),
                  Text(author, style: theme.textTheme.labelLarge),
                  Text(ticketDateTime(tag, message.createdAt), style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: message.body == null ? theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic) : theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.thread,
    required this.state,
    required this.wait,
    required this.controller,
    required this.onNewTicket,
  });

  final TicketThread thread;
  final ThreadState state;
  final Duration? wait;
  final TextEditingController controller;
  final VoidCallback onNewTicket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cubit = context.read<TicketThreadCubit>();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.45;
    if (thread.isClosed) {
      return Material(
        elevation: 2,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.notice == ReplyNotice.closed) ...[Text(l10n.ticketsClosedRefused, style: theme.textTheme.bodyMedium), const SizedBox(height: 8)],
                Text(l10n.ticketsClosedNote, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                FilledButton(key: const Key('ticket-thread-new'), onPressed: onNewTicket, child: Text(l10n.ticketsNewTitle)),
              ],
            ),
          ),
        ),
      );
    }
    final sending = state.replyStatus == ReplyStatus.sending;
    final notice = switch (state.notice) {
      _ when wait != null => l10n.ticketsHeldRateLimit(ticketWaitText(l10n, wait!)),
      ReplyNotice.unknownOutcome => l10n.ticketsUnknownOutcome,
      ReplyNotice.checkFirst => l10n.ticketsReplyCheckFirst,
      _ => null,
    };
    final failure = state.replyFailure;
    final showFailure = failure != null && state.notice == ReplyNotice.none;
    return Material(
      elevation: 2,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (thread.isResolved) ...[Text(l10n.ticketsResolvedNote, style: theme.textTheme.bodyMedium), const SizedBox(height: 8)],
              if (notice != null) ...[Text(notice, style: theme.textTheme.bodyMedium), const SizedBox(height: 8)],
              if (showFailure) ...[
                Text(ticketFailureMessage(l10n, failure), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
                const SizedBox(height: 8),
              ],
              TextField(
                key: const Key('ticket-reply-field'),
                controller: controller,
                enabled: !sending,
                minLines: 1,
                maxLines: 5,
                maxLength: ticketBodyMaxLength,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                // What the customer writes to support is personal: the keyboard does not learn from it.
                enableIMEPersonalizedLearning: false,
                decoration: InputDecoration(labelText: l10n.ticketsReplyHint),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('ticket-reply-send'),
                onPressed: sending || wait != null ? null : () => cubit.reply(controller.text),
                child: sending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.ticketsReplySend),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
