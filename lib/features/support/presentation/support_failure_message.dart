import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/domain/entities/support_message.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';
import 'package:sentech_connect_app/l10n/failure_copy.dart';

/// Customer text for a failed support send. The typed refusals
/// (`support_unavailable`, `support_contact_not_configured`, `invalid_message`,
/// `invalid_contact`, the human-check ones) come from the shared failure copy;
/// offline and rate limits reuse the generic request copy.
String supportFailureMessage(AppLocalizations l10n, Failure? failure) {
  final typed = typedFailureText(l10n, failure);
  if (typed != null) return typed;
  return switch (failure) {
    NetworkFailure() => l10n.accountRequestOffline,
    RateLimitedFailure() => l10n.accountRequestRateLimited,
    _ => l10n.accountRequestFailed,
  };
}

String supportIssueMessage(AppLocalizations l10n, SupportDraftIssue issue) =>
    switch (issue) {
      SupportDraftIssue.messageTooShort => l10n.supportIssueMessageTooShort,
      SupportDraftIssue.messageTooLong => l10n.supportIssueMessageTooLong,
      SupportDraftIssue.contactInvalid => l10n.failureInvalidContact,
      SupportDraftIssue.orderRefInvalid => l10n.supportIssueOrderRef,
    };

String supportTopicLabel(AppLocalizations l10n, SupportTopic topic) =>
    switch (topic) {
      SupportTopic.connecting => l10n.supportTopicConnecting,
      SupportTopic.payment => l10n.supportTopicPayment,
      SupportTopic.pass => l10n.supportTopicPass,
      SupportTopic.account => l10n.supportTopicAccount,
      SupportTopic.other => l10n.supportTopicOther,
    };
