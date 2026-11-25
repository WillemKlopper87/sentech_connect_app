import 'package:equatable/equatable.dart';

enum IncidentSeverity { info, degraded, outage, unknown }

enum IncidentStatus { investigating, identified, monitoring, resolved, unknown }

class IncidentUpdate extends Equatable {
  const IncidentUpdate({required this.status, required this.body, required this.createdAt});

  final IncidentStatus status;
  final String body;
  final DateTime createdAt;

  @override
  List<Object?> get props => [status, body, createdAt];
}

/// A known network incident from the public incidents route. Every word shown
/// comes from the provider; the app adds no cause and no time to fix.
class Incident extends Equatable {
  const Incident({
    required this.id,
    required this.title,
    required this.severity,
    required this.status,
    required this.body,
    required this.startedAt,
    required this.resolvedAt,
    required this.updates,
  });

  /// Only a stable list key: never shown.
  final String id;
  final String title;
  final IncidentSeverity severity;
  final IncidentStatus status;
  final String body;
  final DateTime startedAt;
  final DateTime? resolvedAt;
  final List<IncidentUpdate> updates;

  /// Anything but `resolved` counts as still open, including a status the app
  /// does not know: the app never claims an incident has ended on a guess.
  bool get isOpen => status != IncidentStatus.resolved;

  @override
  List<Object?> get props => [id, title, severity, status, body, startedAt, resolvedAt, updates];
}
