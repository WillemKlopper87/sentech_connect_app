import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// A plain API date (see `parseApiDate`) as a short date. The fields are
/// formatted as stored; no time zone conversion happens.
String formatApiDay(BuildContext context, DateTime day) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(day);

/// 10000 -> "10", 7500 -> "7.5".
String formatMbps(int kbps) => kbps % 1000 == 0 ? '${kbps ~/ 1000}' : (kbps / 1000).toStringAsFixed(1);

String serviceKindLabel(BuildContext context, SubscriberPlanKind kind) => switch (kind) {
  SubscriberPlanKind.recurringHotspot => context.l10n.serviceKindHotspot,
  SubscriberPlanKind.fixedWireless => context.l10n.serviceKindFixedWireless,
};

String serviceStatusLabel(BuildContext context, ServiceStatus status) => switch (status) {
  ServiceStatus.pending => context.l10n.serviceStatusPending,
  ServiceStatus.active => context.l10n.serviceStatusActive,
  ServiceStatus.suspended => context.l10n.serviceStatusSuspended,
  ServiceStatus.cancelled => context.l10n.serviceStatusCancelled,
};
