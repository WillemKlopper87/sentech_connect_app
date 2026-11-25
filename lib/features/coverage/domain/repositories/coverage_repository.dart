import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_check.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_meta.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/geocode_match.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';

/// The customer's public coverage check, address search and waiting list, all
/// against the customer's own provider (tenant). Coordinates, addresses and
/// contact details go to that provider's platform endpoint and nowhere else.
abstract class CoverageRepository {
  /// The server's answer for a point. Typed failures: [CoverageUnavailableFailure]
  /// (older server, no data), [RateLimitedFailure] (with `Retry-After`),
  /// [NetworkFailure] (timeout or no network), [OutsideServiceAreaFailure].
  Future<Either<Failure, CoverageCheck>> check({required double lat, required double lon});

  /// Dataset version, service area, consent versions and attribution. Cached per
  /// session; [refresh] reads it again.
  Future<Either<Failure, CoverageMeta>> meta({bool refresh = false});

  /// Address search through the platform (the address step when it is on, else the older search).
  Future<Either<Failure, AddressSearchResult>> search(String query);

  /// Whether the platform's address step is on (`capabilities.address_lookup`).
  Future<Either<Failure, bool>> addressLookupAvailable();

  /// Joins the waiting list. [idempotencyKey]: one per attempt, reused after an unknown outcome.
  Future<Either<Failure, Unit>> submitLead(NotifyRequest request, {required String idempotencyKey});

  /// Starts leaving the list: a one-time link is sent to the contact. The list is
  /// only left when the contact opens that link; the app never completes it alone.
  Future<Either<Failure, Unit>> requestWithdrawal(WithdrawalRequest request);
}
