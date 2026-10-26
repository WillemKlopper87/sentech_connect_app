import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';

enum UsageAlertKind { eighty, full, expiryOneHour }

class UsageAlert {
  const UsageAlert({
    required this.id,
    required this.passId,
    required this.kind,
  });
  final String id;
  final String passId;
  final UsageAlertKind kind;
}

class UsageAlertPolicy {
  static List<UsageAlert> due(
    Pass p, {
    required DateTime now,
    required Set<String> alreadySent,
  }) {
    // Only a running pass is alerted about. A suspended one (the provider
    // paused the service) gets no 80%, full or expiry alert: the customer cannot
    // use it, and the fix is with the provider, not a top-up.
    final local = now.toUtc().add(const Duration(hours: 2));
    if (local.hour >= 21 ||
        local.hour < 7 ||
        p.status != PassStatus.active ||
        p.startsAt.isAfter(now) ||
        !p.expiresAt.isAfter(now)) {
      return [];
    }
    final result = <UsageAlert>[];
    final cap = p.dataMb;
    if (cap != null && cap > 0) {
      final used = p.usedBytes / (cap * 1024 * 1024);
      if (used >= 1) {
        if (!alreadySent.contains('${p.id}:100')) {
          result.add(
            UsageAlert(
              id: '${p.id}:100',
              passId: p.id,
              kind: UsageAlertKind.full,
            ),
          );
        }
      } else if (used >= .8 && !alreadySent.contains('${p.id}:80')) {
        result.add(
          UsageAlert(
            id: '${p.id}:80',
            passId: p.id,
            kind: UsageAlertKind.eighty,
          ),
        );
      }
    }
    if (p.expiresAt.difference(now) <= const Duration(hours: 1) &&
        !alreadySent.contains('${p.id}:expiry1h')) {
      result.add(
        UsageAlert(
          id: '${p.id}:expiry1h',
          passId: p.id,
          kind: UsageAlertKind.expiryOneHour,
        ),
      );
    }
    return result;
  }
}
