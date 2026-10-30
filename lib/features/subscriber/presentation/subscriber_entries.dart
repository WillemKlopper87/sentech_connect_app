import 'package:flutter/material.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

/// One row in the Account tab's "Home internet" section. A row exists only
/// once its slice has registered it here, and a banner button or a service
/// detail link to the same route appears at the same moment
/// ([subscriberEntryRegistered]), so a route can never be offered before its
/// page exists.
class SubscriberAccountEntry {
  const SubscriberAccountEntry({required this.route, required this.icon, required this.label});

  final String route;
  final IconData icon;
  final String Function(AppLocalizations l10n) label;
}

/// The rows, in display order. Each later slice adds ONE entry, on its own
/// line, between the marker comments below (keeps merges trivial):
///   S2 invoices: SubscriberAccountEntry(route: AppRoutes.invoices, ...)
///   S4 ID check: SubscriberAccountEntry(route: AppRoutes.kyc, ...)
List<SubscriberAccountEntry> subscriberAccountEntries() => [
  SubscriberAccountEntry(route: AppRoutes.services, icon: Icons.router_outlined, label: (l) => l.servicesTitle),
  // --- S2 (Invoices) adds its entry below this line ---
  SubscriberAccountEntry(route: AppRoutes.invoices, icon: Icons.receipt_long_outlined, label: (l) => l.invoicesTitle),

  // --- S4 (ID check) adds its entry below this line ---
  SubscriberAccountEntry(route: AppRoutes.kyc, icon: Icons.badge_outlined, label: (l) => l.kycTitle),

  // --- end of entries ---
];

/// True once a slice has registered a row for [route].
bool subscriberEntryRegistered(String route) => subscriberAccountEntries().any((e) => e.route == route);
