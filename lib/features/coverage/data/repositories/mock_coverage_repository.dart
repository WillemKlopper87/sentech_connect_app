import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_check.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_meta.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/geocode_match.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';
import 'package:sentech_connect_app/features/coverage/domain/repositories/coverage_repository.dart';

/// The demo flavor's coverage check: fixed, believable v2 answers for three demo
/// places, so every screen state can be shown without a server. It is a demo
/// dataset, not a model of the real one: nothing here predicts coverage, and the
/// real flavor never registers it (`test/locator_test.dart`).
///
/// The three places (search "Lifalethu", "Marula" or "Graskop", or tap the map near them):
///  * eMbalenhle: 5G covered with NO band and no speed (a placeholder ladder) and LTE covered with a band;
///  * Mamelodi: 5G planned, with an expected date;
///  * Graskop: nothing covered, the nearest LTE is a distance band away (an empty answer).
/// Anywhere else inside South Africa is the empty answer too.
class MockCoverageRepository implements CoverageRepository {
  MockCoverageRepository([SimulatedNetwork? network, this.latency = const Duration(milliseconds: 700)])
    : _network = network ?? SimulatedNetwork();

  final SimulatedNetwork _network;
  final Duration latency;

  /// Idempotency keys already used, with a fingerprint of the request (never the request itself),
  /// so a retry with the same key is the same lead and a different request under a key is refused.
  final _usedKeys = <String, int>{};

  static const embalenhle = GeocodeMatch(
    label: '12 Lifalethu Avenue, eMbalenhle, Secunda',
    lat: -26.514,
    lon: 29.103,
    precision: MatchPrecision.address,
  );
  static const mamelodi = GeocodeMatch(
    label: '3 Marula Street, Mamelodi, Pretoria',
    lat: -25.700,
    lon: 28.350,
    precision: MatchPrecision.address,
  );
  static const graskop = GeocodeMatch(
    label: 'R532, Graskop',
    lat: -24.940,
    lon: 30.840,
    precision: MatchPrecision.street,
  );
  static const places = [embalenhle, mamelodi, graskop];

  /// How close (degrees, about 2 km) a tap must be to a demo place to get its answer.
  static const _near = 0.02;

  static const _demoMeta = CoverageMeta(
    datasetVersion: 1,
    bounds: GeoBounds(west: 16.0, south: -35.5, east: 33.5, north: -22.0),
    waitlistConsentVersion: '2026-10-01',
    coverageArrivedConsentVersion: '2026-11-18',
    attribution: 'Coverage: demo data (estimate)',
    minZoom: 5,
    maxZoom: 14,
  );

  static CoverageOption _option(
    CoverageTechnology technology,
    OptionKind kind, {
    OptionBand? band,
    SpeedRange? typical,
    SpeedRange? busy,
    DateTime? expected,
    CoverageConfidence confidence = CoverageConfidence.medium,
    bool notify = false,
    bool nearBoundary = false,
  }) => CoverageOption(
    technology: technology,
    technologyRaw: technology == CoverageTechnology.fiveG ? '5g' : 'lte',
    kind: kind,
    band: band,
    typicalDown: typical,
    busyHourDown: busy,
    confidence: confidence,
    nearBoundary: nearBoundary,
    notifyAvailable: notify,
    expectedDate: expected,
    measureDirection: MeasureDirection.downlink,
    measureLabelKey: 'coverage.measure.downlink',
    sourceKey: 'coverage.source.isp_planning',
    datasetVersion: 1,
    releaseLabel: 'Demo data',
    releaseDate: DateTime.utc(2026, 11, 1),
  );

  static const _estimate = ['coverage.estimate'];

  static CoverageCheck _answerFor(double lat, double lon) {
    bool near(GeocodeMatch place) => (lat - place.lat).abs() <= _near && (lon - place.lon).abs() <= _near;
    if (near(embalenhle)) {
      return CoverageCheck(
        status: CoverageAnswer.covered,
        tenant: 'demo',
        shapeVersion: 2,
        options: [
          // A placeholder ladder: covered and predicted, but no band and no figure.
          _option(CoverageTechnology.fiveG, OptionKind.covered, confidence: CoverageConfidence.high),
          _option(
            CoverageTechnology.lte,
            OptionKind.covered,
            band: const OptionBand(key: 'basic', rank: 1, notify: true),
            typical: const SpeedRange(5, 20),
            busy: const SpeedRange(2, 8),
            notify: true,
            nearBoundary: true,
          ),
        ],
        primaryIndex: 0,
        disclaimerKeys: const ['coverage.estimate', 'coverage.indoor', 'commerce.cooling_off'],
        waitlistAvailable: false,
        datasetVersion: 1,
      );
    }
    if (near(mamelodi)) {
      return CoverageCheck(
        status: CoverageAnswer.planned,
        tenant: 'demo',
        shapeVersion: 2,
        options: [
          _option(
            CoverageTechnology.fiveG,
            OptionKind.planned,
            expected: DateTime.utc(2027, 3, 1),
            confidence: CoverageConfidence.low,
            notify: true,
          ),
        ],
        primaryIndex: 0,
        disclaimerKeys: const ['coverage.estimate', 'coverage.planned_date'],
        waitlistAvailable: true,
        datasetVersion: 1,
      );
    }
    return CoverageCheck(
      status: CoverageAnswer.notCovered,
      tenant: 'demo',
      shapeVersion: 2,
      options: const [],
      nearest: const CoverageNearest(
        technology: CoverageTechnology.lte,
        technologyRaw: 'lte',
        distance: DistanceBand.from5To20Km,
      ),
      disclaimerKeys: _estimate,
      waitlistAvailable: true,
      datasetVersion: 1,
    );
  }

  @override
  Future<Either<Failure, CoverageCheck>> check({required double lat, required double lon}) async {
    await Future<void>.delayed(latency);
    if (_network.failure case final failure?) return Left(failure);
    return Right(_answerFor(lat, lon));
  }

  @override
  Future<Either<Failure, CoverageMeta>> meta({bool refresh = false}) async {
    if (_network.failure case final failure?) return Left(failure);
    return const Right(_demoMeta);
  }

  @override
  Future<Either<Failure, bool>> addressLookupAvailable() async => const Right(true);

  @override
  Future<Either<Failure, AddressSearchResult>> search(String query) async {
    await Future<void>.delayed(latency ~/ 3);
    if (_network.failure case final failure?) return Left(failure);
    final needle = query.toLowerCase();
    final found = [
      for (final place in places)
        if (place.label.toLowerCase().split(RegExp(r'[ ,]+')).any((word) => word.length >= 3 && needle.contains(word)) ||
            place.label.toLowerCase().contains(needle))
          place,
    ];
    return Right(
      AddressSearchResult(
        matches: found,
        matched: found.isEmpty ? null : found.first.precision,
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> submitLead(NotifyRequest request, {required String idempotencyKey}) async {
    await Future<void>.delayed(latency);
    if (_network.failure case final failure?) return Left(failure);
    // The same as the server: a key is for one request. Only a fingerprint is kept, never the contact.
    final fingerprint = Object.hash(request.contactType, request.contactValue, request.addressText, request.arrivalConsentGranted);
    final used = _usedKeys[idempotencyKey];
    if (used != null && used != fingerprint) {
      return const Left(ValidationFailure('That request key was already used for something else.', 'idempotency_key_reused', false));
    }
    _usedKeys[idempotencyKey] = fingerprint;
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> requestWithdrawal(WithdrawalRequest request) async {
    await Future<void>.delayed(latency);
    if (_network.failure case final failure?) return Left(failure);
    return const Right(unit);
  }
}
