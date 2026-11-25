import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/features/credits/data/credits_json.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credit_entry.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credits_summary.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/mission.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/streak.dart';
import 'package:sentech_connect_app/features/credits/domain/repositories/credits_repository.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';

/// The customer's credits routes. Every route answers 409 `feature_disabled`
/// when the provider's `credits` flag is off and 403 `module_not_enabled` when
/// the module is off; a server older than the routes answers 404. All three
/// map to [CreditsNotAvailableFailure], so the screens hide the feature instead
/// of crashing or showing an empty page. `credits_paused` (503) is only ever
/// sent by the two writing routes.
class HttpCreditsRepository implements CreditsRepository {
  HttpCreditsRepository(this._api);

  final ApiClient _api;

  static const creditsPath = '/v1/me/credits';
  static const ledgerPath = '/v1/me/credits/ledger';
  static const redeemPath = '/v1/me/credits/redeem';
  static const streakPath = '/v1/me/streak';
  static const claimPath = '/v1/me/streak/claim';
  static const missionsPath = '/v1/me/missions';
  static const badgesPath = '/v1/me/badges';

  static Failure _unavailable(Failure failure) => switch (failure) {
    NotFoundFailure() || FeatureDisabledFailure() || ModuleDisabledFailure() => const CreditsNotAvailableFailure(),
    _ => failure,
  };

  static Map<String, Object?> _object(Object? data) => Map<String, Object?>.from(data! as Map);

  @override
  Future<Either<Failure, CreditsSummary>> summary() async {
    final result = await _api.get<CreditsSummary>(
      creditsPath,
      scope: await _api.captureScope(),
      decode: (data) => creditsSummaryFromJson(_object(data)),
    );
    return result.mapLeft(_unavailable);
  }

  @override
  Future<Either<Failure, LedgerPage>> ledger({String? cursor}) async {
    final result = await _api.get<LedgerPage>(
      ledgerPath,
      query: {'cursor': ?cursor},
      scope: await _api.captureScope(),
      decode: (data) => ledgerPageFromJson(_object(data)),
    );
    return result.mapLeft(_unavailable);
  }

  @override
  Future<Either<Failure, Pass>> redeem({required int credits, required String idempotencyKey}) async {
    final result = await _api.post<Pass>(
      redeemPath,
      scope: await _api.captureScope(),
      idempotencyKey: idempotencyKey,
      body: {'credits': credits},
      decode: (data) => passFromJson(_object(data)),
    );
    return result.mapLeft(_unavailable);
  }

  @override
  Future<Either<Failure, StreakState>> streak() async {
    final result = await _api.get<StreakState>(
      streakPath,
      scope: await _api.captureScope(),
      decode: (data) => streakStateFromJson(_object(data)),
    );
    return result.mapLeft(_unavailable);
  }

  @override
  Future<Either<Failure, ClaimResult>> claimToday({required String idempotencyKey}) async {
    final result = await _api.post<ClaimResult>(
      claimPath,
      scope: await _api.captureScope(),
      idempotencyKey: idempotencyKey,
      decode: (data) => claimResultFromJson(_object(data)),
    );
    return result.mapLeft(_unavailable);
  }

  @override
  Future<Either<Failure, List<Mission>>> missions() async {
    final result = await _api.get<List<Mission>>(
      missionsPath,
      scope: await _api.captureScope(),
      decode: (data) => [for (final item in _object(data)['items']! as List) missionFromJson(_object(item))],
    );
    return result.mapLeft(_unavailable);
  }

  @override
  Future<Either<Failure, List<CreditBadge>>> badges() async {
    final result = await _api.get<List<CreditBadge>>(
      badgesPath,
      scope: await _api.captureScope(),
      decode: (data) => [for (final item in _object(data)['items']! as List) creditBadgeFromJson(_object(item))],
    );
    return result.mapLeft(_unavailable);
  }
}
