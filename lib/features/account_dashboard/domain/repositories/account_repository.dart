import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/account_dashboard/domain/entities/account_summary.dart';

/// Real implementation combines BSS billing/subscription data with
/// CPE telemetry — the latter needs a TR-069/CWMP or vendor-specific
/// API not yet named by Sentech (see docs/prompt-critique.md, Module F).
abstract class AccountRepository {
  Future<Either<Failure, AccountSummary>> getSummary();
}
