import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/coverage/data/coverage_json.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_check.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_meta.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/geocode_match.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';
import 'package:sentech_connect_app/features/coverage/domain/repositories/coverage_repository.dart';

import '../helpers/fixtures.dart';

CoverageCheck checkFixture([String name = 'coverage_check_two_options.json']) => coverageCheckFromJson(fixtureMap(name));

CoverageMeta metaFixture() => coverageMetaFromJson(fixtureMap('coverage_meta.json'));

/// A scriptable [CoverageRepository]. Every call is recorded; an answer is
/// immediate, or held on a [Completer] so a test can answer requests out of
/// order.
class FakeCoverageRepository implements CoverageRepository {
  Either<Failure, CoverageMeta> metaResult = Right(metaFixture());
  Either<Failure, CoverageCheck> checkResult = Right(checkFixture());
  Either<Failure, AddressSearchResult> searchResult = Right(
    const AddressSearchResult(
      matches: [GeocodeMatch(label: '12 Lifalethu Avenue, eMbalenhle', lat: -26.514, lon: 29.103, precision: MatchPrecision.address)],
      matched: MatchPrecision.address,
    ),
  );
  Either<Failure, bool> addressLookupResult = const Right(true);

  /// The answers submitLead gives, one per call; the last repeats.
  final leadResults = <Either<Failure, Unit>>[const Right(unit)];
  Either<Failure, Unit> withdrawalResult = const Right(unit);

  /// When non-empty, each call takes the next completer and waits for it.
  final checkGates = <Completer<Either<Failure, CoverageCheck>>>[];
  final searchGates = <Completer<Either<Failure, AddressSearchResult>>>[];
  Completer<void>? leadGate;
  Completer<void>? withdrawalGate;

  final checkCalls = <({double lat, double lon})>[];
  final searchCalls = <String>[];
  final leadCalls = <({NotifyRequest request, String key})>[];
  final withdrawalCalls = <WithdrawalRequest>[];
  int metaCalls = 0;
  int metaRefreshes = 0;

  @override
  Future<Either<Failure, CoverageCheck>> check({required double lat, required double lon}) {
    checkCalls.add((lat: lat, lon: lon));
    if (checkGates.isNotEmpty) return checkGates.removeAt(0).future;
    return Future.value(checkResult);
  }

  @override
  Future<Either<Failure, CoverageMeta>> meta({bool refresh = false}) async {
    metaCalls++;
    if (refresh) metaRefreshes++;
    return metaResult;
  }

  @override
  Future<Either<Failure, AddressSearchResult>> search(String query) {
    searchCalls.add(query);
    if (searchGates.isNotEmpty) return searchGates.removeAt(0).future;
    return Future.value(searchResult);
  }

  @override
  Future<Either<Failure, bool>> addressLookupAvailable() async => addressLookupResult;

  @override
  Future<Either<Failure, Unit>> submitLead(NotifyRequest request, {required String idempotencyKey}) async {
    leadCalls.add((request: request, key: idempotencyKey));
    await leadGate?.future;
    final index = leadCalls.length - 1;
    return leadResults[index < leadResults.length ? index : leadResults.length - 1];
  }

  @override
  Future<Either<Failure, Unit>> requestWithdrawal(WithdrawalRequest request) async {
    withdrawalCalls.add(request);
    await withdrawalGate?.future;
    return withdrawalResult;
  }
}
