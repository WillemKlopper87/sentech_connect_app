import 'package:equatable/equatable.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';

/// The ISP directory (`GET /v1/tenants`): the usable [tenants] plus how many
/// entries were [skipped] because they were malformed. A directory with
/// skipped entries is [isIncomplete]: the customer must choose from what is
/// shown instead of having the only usable entry picked for them.
class TenantDirectory extends Equatable {
  const TenantDirectory(this.tenants, {this.skipped = 0});

  final List<Tenant> tenants;
  final int skipped;

  bool get isIncomplete => skipped > 0;

  @override
  List<Object?> get props => [tenants, skipped];
}
