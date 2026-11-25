import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/features/coverage/data/repositories/mock_coverage_repository.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_check.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';

T _ok<T>(Either<Failure, T> either) => either.getOrElse((f) => throw StateError(f.message));

void main() {
  final repo = MockCoverageRepository(null, Duration.zero);

  test('demo_mock_covers_covered_planned_and_empty', () async {
    final covered = _ok(await repo.check(lat: MockCoverageRepository.embalenhle.lat, lon: MockCoverageRepository.embalenhle.lon));
    expect(covered.status, CoverageAnswer.covered);
    expect(covered.options, hasLength(2));
    // The placeholder case: 5G covered with no band and no figure; LTE with a band and figures.
    final fiveG = covered.options.firstWhere((o) => o.technology == CoverageTechnology.fiveG);
    expect(fiveG.band, isNull);
    expect(fiveG.hasFigures, isFalse);
    final lte = covered.options.firstWhere((o) => o.technology == CoverageTechnology.lte);
    expect(lte.band!.key, 'basic');
    expect(lte.hasFigures, isTrue);
    expect(lte.measureLabelKey, 'coverage.measure.downlink');

    final planned = _ok(await repo.check(lat: MockCoverageRepository.mamelodi.lat, lon: MockCoverageRepository.mamelodi.lon));
    expect(planned.options.single.kind, OptionKind.planned);
    expect(planned.options.single.expectedDate, isNotNull);
    expect(planned.options.single.notifyAvailable, isTrue);

    final empty = _ok(await repo.check(lat: -30.0, lon: 25.0));
    expect(empty.options, isEmpty);
    expect(empty.nearest, isNotNull);
    expect(empty.datasetVersion, isNotNull, reason: 'a dataset is active in the demo: an empty answer is "no coverage", not "unavailable"');
  });

  test('the demo search finds the demo places and nothing else', () async {
    expect(_ok(await repo.search('Lifalethu')).matches.single.label, contains('eMbalenhle'));
    expect(_ok(await repo.search('marula street')).matches.single.label, contains('Mamelodi'));
    expect(_ok(await repo.search('Nowhere at all')).matches, isEmpty);
  });

  test('the demo meta carries the consent versions and the service area', () async {
    final meta = _ok(await repo.meta());
    expect(meta.canOfferNotify, isTrue);
    expect(meta.bounds!.contains(lat: -26.2, lon: 28.0), isTrue);
    expect(meta.datasetVersion, 1);
  });

  test('the demo honours the same idempotency rule as the server and never keeps a contact', () async {
    const request = NotifyRequest(
      contactType: ContactKind.phone,
      contactValue: '0821234567',
      addressText: '1 Main Street',
      lat: -26.1,
      lon: 28.1,
      technologyInterest: TechnologyInterest.any,
      waitlistConsentVersion: '2026-10-01',
      arrivalConsentGranted: false,
      arrivalConsentVersion: '2026-11-18',
    );
    expect((await repo.submitLead(request, idempotencyKey: 'key-1')).isRight(), isTrue);
    expect((await repo.submitLead(request, idempotencyKey: 'key-1')).isRight(), isTrue, reason: 'the same request is the same lead');
    const other = NotifyRequest(
      contactType: ContactKind.phone,
      contactValue: '0830000000',
      addressText: '1 Main Street',
      lat: -26.1,
      lon: 28.1,
      technologyInterest: TechnologyInterest.any,
      waitlistConsentVersion: '2026-10-01',
      arrivalConsentGranted: false,
      arrivalConsentVersion: '2026-11-18',
    );
    final refused = (await repo.submitLead(other, idempotencyKey: 'key-1')).match((f) => f, (_) => null);
    expect(refused, isA<ValidationFailure>());
    expect((refused! as ValidationFailure).code, 'idempotency_key_reused');
  });

  test('offline, the demo answers the network failure like the real client', () async {
    final network = SimulatedNetwork()..offline = true;
    final offline = MockCoverageRepository(network, Duration.zero);
    expect((await offline.check(lat: -26.1, lon: 28.1)).match((f) => f, (_) => null), isA<NetworkFailure>());
    expect((await offline.search('Lifalethu')).match((f) => f, (_) => null), isA<NetworkFailure>());
    expect((await offline.meta()).match((f) => f, (_) => null), isA<NetworkFailure>());
  });
}
