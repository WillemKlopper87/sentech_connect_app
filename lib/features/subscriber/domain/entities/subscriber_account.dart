import 'package:equatable/equatable.dart';

enum SubscriberAccountKind { individual, business }

enum SubscriberAccountStatus { active, closed }

/// How many services the account has in each state (`service_counts`).
class ServiceCounts extends Equatable {
  const ServiceCounts({this.pending = 0, this.active = 0, this.suspended = 0, this.cancelled = 0});

  final int pending;
  final int active;
  final int suspended;
  final int cancelled;

  int get total => pending + active + suspended + cancelled;

  @override
  List<Object?> get props => [pending, active, suspended, cancelled];
}

/// The contact profile held on the subscriber account (`AccountProfileOut`).
class SubscriberProfile extends Equatable {
  const SubscriberProfile({required this.displayName, required this.language, this.email, this.phoneE164});

  final String displayName;
  final String? email;
  final String? phoneE164;

  /// `en`, `zu` or `af`.
  final String language;

  @override
  List<Object?> get props => [displayName, email, phoneE164, language];
}

/// The signed-in customer's subscriber account (`GET /v1/me/subscriber`).
/// A customer who never signed up has none: the repository answers `null`.
class SubscriberAccount extends Equatable {
  const SubscriberAccount({
    required this.id,
    required this.accountNo,
    required this.kind,
    required this.status,
    required this.serviceCounts,
    this.profile,
  });

  final String id;
  final String accountNo;
  final SubscriberAccountKind kind;
  final SubscriberAccountStatus status;
  final ServiceCounts serviceCounts;
  final SubscriberProfile? profile;

  bool get isClosed => status == SubscriberAccountStatus.closed;

  @override
  List<Object?> get props => [id, accountNo, kind, status, serviceCounts, profile];
}
