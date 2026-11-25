import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/coverage/domain/device_location.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_check.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/geocode_match.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/address_search_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/coverage_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/location_cubit.dart';

import 'fake_coverage_repository.dart';

const _settle = Duration(milliseconds: 60);

Future<void> _wait([Duration d = _settle]) => Future<void>.delayed(d);

class _FakeLocation implements DeviceLocationService {
  DeviceLocationResult result = const LocationFound(lat: -26.514, lon: 29.103);
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<DeviceLocationResult> current() async {
    calls++;
    await gate?.future;
    return result;
  }
}

void main() {
  late FakeCoverageRepository repo;
  var clock = DateTime.utc(2026, 11, 26, 10);

  setUp(() {
    repo = FakeCoverageRepository();
    clock = DateTime.utc(2026, 11, 26, 10);
  });

  CoverageCubit makeCoverage() => CoverageCubit(repo, debounce: const Duration(milliseconds: 20), now: () => clock);

  group('CoverageCubit', () {
    test('out_of_order_responses_show_only_the_latest', () async {
      final first = Completer<Either<Failure, CoverageCheck>>();
      final second = Completer<Either<Failure, CoverageCheck>>();
      repo.checkGates.addAll([first, second]);
      final cubit = makeCoverage();
      final seen = <CoverageState>[];
      cubit.stream.listen(seen.add);
      final a = cubit.checkAt(-26.1, 28.1);
      final b = cubit.checkAt(-26.2, 28.2);
      // The newer request answers first (planned), then the older one arrives late (covered).
      second.complete(Right(checkFixture('coverage_check_planned.json')));
      await b;
      first.complete(Right(checkFixture('coverage_check_two_options.json')));
      await a;
      await _wait(const Duration(milliseconds: 10));
      expect(cubit.state.status, CoverageStatus.ready);
      expect(cubit.state.check!.options.single.kind, OptionKind.planned);
      expect(
        seen.where((s) => s.status == CoverageStatus.ready).map((s) => s.check!.options.single.kind).toSet(),
        {OptionKind.planned},
        reason: 'the older answer must never flicker in',
      );
      await cubit.close();
    });

    test('a new check clears the old answer at once (an answer is never shown for another point)', () async {
      final cubit = makeCoverage();
      await cubit.checkAt(-26.1, 28.1);
      expect(cubit.state.check, isNotNull);
      final gate = Completer<Either<Failure, CoverageCheck>>();
      repo.checkGates.add(gate);
      final next = cubit.checkAt(-26.3, 28.3);
      expect(cubit.state.status, CoverageStatus.loading);
      expect(cubit.state.check, isNull);
      gate.complete(Right(checkFixture('coverage_check_nearest.json')));
      await next;
      expect(cubit.state.check!.options, isEmpty);
      await cubit.close();
    });

    test('rapid map taps send one request, for the last point', () async {
      final cubit = makeCoverage();
      cubit.pinDropped(-26.1, 28.1);
      cubit.pinDropped(-26.2, 28.2);
      cubit.pinDropped(-26.3, 28.3);
      expect(cubit.state.status, CoverageStatus.loading);
      expect(cubit.state.point!.lat, -26.3, reason: 'the pin moves at once');
      expect(repo.checkCalls, isEmpty);
      await _wait();
      expect(repo.checkCalls, [(lat: -26.3, lon: 28.3)]);
      expect(cubit.state.status, CoverageStatus.ready);
      await cubit.close();
    });

    test('a_point_outside_meta_bounds_is_explained_without_a_request', () async {
      final cubit = makeCoverage();
      await cubit.load();
      expect(cubit.state.meta, isNotNull);
      await cubit.checkAt(-40.0, 28.0); // south of the box
      expect(cubit.state.status, CoverageStatus.outside);
      cubit.pinDropped(-26.2, 5.0); // west of the box
      expect(cubit.state.status, CoverageStatus.outside);
      await _wait();
      expect(repo.checkCalls, isEmpty);
      // A point inside still works afterwards.
      await cubit.checkAt(-26.2, 28.0);
      expect(cubit.state.status, CoverageStatus.ready);
      expect(repo.checkCalls, hasLength(1));
      await cubit.close();
    });

    test('a point the server calls outside the service area is explained too', () async {
      repo.checkResult = const Left(OutsideServiceAreaFailure());
      final cubit = makeCoverage();
      await cubit.checkAt(-26.2, 28.0);
      expect(cubit.state.status, CoverageStatus.outside);
      await cubit.close();
    });

    test('without meta (not read yet, or it failed) the server decides', () async {
      repo.metaResult = const Left(NetworkFailure());
      final cubit = makeCoverage();
      await cubit.load();
      expect(cubit.state.status, CoverageStatus.idle, reason: 'a network blip at start is not an error screen');
      await cubit.checkAt(-40.0, 28.0);
      expect(repo.checkCalls, hasLength(1));
      await cubit.close();
    });

    test('rate_limited_waits_for_retry_after_and_never_shows_a_stale_answer', () async {
      final cubit = makeCoverage();
      await cubit.checkAt(-26.1, 28.1);
      repo.checkResult = const Left(RateLimitedFailure('Too many', Duration(seconds: 30)));
      await cubit.checkAt(-26.1, 28.1);
      expect(cubit.state.status, CoverageStatus.rateLimited);
      expect(cubit.state.check, isNull);
      expect(cubit.state.retryAt, clock.add(const Duration(seconds: 30)));
      final calls = repo.checkCalls.length;
      await cubit.retry(); // too early: nothing is sent
      expect(repo.checkCalls, hasLength(calls));
      repo.checkResult = Right(checkFixture());
      clock = clock.add(const Duration(seconds: 31));
      await cubit.retry();
      expect(repo.checkCalls, hasLength(calls + 1));
      expect(cubit.state.status, CoverageStatus.ready);
      await cubit.close();
    });

    test('a rate limit with no Retry-After still waits a little', () async {
      repo.checkResult = const Left(RateLimitedFailure());
      final cubit = makeCoverage();
      await cubit.checkAt(-26.1, 28.1);
      expect(cubit.state.retryAt, isNotNull);
      expect(cubit.state.retryAt!.isAfter(clock), isTrue);
      await cubit.close();
    });

    test('an older server, or a provider with no active dataset, is unavailable, never an empty answer', () async {
      repo.checkResult = const Left(CoverageUnavailableFailure());
      final cubit = makeCoverage();
      await cubit.checkAt(-26.1, 28.1);
      expect(cubit.state.status, CoverageStatus.unavailable);
      // A 200 that says no dataset is active (dataset_version null, nothing found) must not read as "not covered".
      repo.checkResult = Right(
        CoverageCheck(
          status: CoverageAnswer.notCovered,
          tenant: 'sentech',
          shapeVersion: 2,
          options: const [],
          disclaimerKeys: const ['coverage.estimate'],
          waitlistAvailable: true,
        ),
      );
      await cubit.checkAt(-26.1, 28.1);
      expect(cubit.state.status, CoverageStatus.unavailable);
      await cubit.close();
    });

    test('meta that says no dataset is active, or a missing route, is unavailable at once, with a retry that reads meta again', () async {
      repo.metaResult = const Left(CoverageUnavailableFailure());
      final cubit = makeCoverage();
      await cubit.load();
      expect(cubit.state.status, CoverageStatus.unavailable);
      repo.metaResult = Right(metaFixture());
      final before = repo.metaRefreshes;
      await cubit.retry();
      expect(repo.metaRefreshes, before + 1, reason: 'the retry reads the meta again, not a cached answer');
      expect(cubit.state.status, CoverageStatus.idle);
      expect(cubit.state.meta, isNotNull);
      await cubit.close();
    });

    test('a failed check keeps the point so the retry asks again, and the retry works once back online', () async {
      repo.checkResult = const Left(NetworkFailure());
      final cubit = makeCoverage();
      await cubit.checkAt(-26.1, 28.1);
      expect(cubit.state.status, CoverageStatus.error);
      expect(cubit.state.failure, isA<NetworkFailure>());
      repo.checkResult = Right(checkFixture());
      await cubit.retry();
      expect(cubit.state.status, CoverageStatus.ready);
      expect(repo.checkCalls.last, (lat: -26.1, lon: 28.1));
      await cubit.close();
    });

    test('reset forgets the point and the answer', () async {
      final cubit = makeCoverage();
      await cubit.checkAt(-26.1, 28.1);
      cubit.reset();
      expect(cubit.state.status, CoverageStatus.idle);
      expect(cubit.state.point, isNull);
      expect(cubit.state.check, isNull);
      await cubit.close();
    });

    test('the point prints redacted', () async {
      final cubit = makeCoverage();
      await cubit.checkAt(-26.51423, 29.10311);
      expect(cubit.state.point.toString(), isNot(contains('26.514')));
      await cubit.close();
    });

    test('closing_the_page_emits_nothing_after_close', () async {
      final gate = Completer<Either<Failure, CoverageCheck>>();
      repo.checkGates.add(gate);
      final cubit = makeCoverage();
      final pending = cubit.checkAt(-26.1, 28.1);
      cubit.pinDropped(-26.2, 28.2); // a debounce timer is pending too
      await cubit.close();
      gate.complete(Right(checkFixture()));
      await pending;
      await _wait();
      expect(repo.checkCalls, hasLength(1), reason: 'the pending pin drop never fires');
    });
  });

  group('AddressSearchCubit', () {
    AddressSearchCubit makeSearch() => AddressSearchCubit(repo, debounce: const Duration(milliseconds: 20), now: () => clock);

    test('rapid_typing_sends_one_request_per_settled_query', () async {
      final cubit = makeSearch();
      cubit.queryChanged('Lif');
      cubit.queryChanged('Lifa');
      cubit.queryChanged('Lifal');
      await _wait();
      expect(repo.searchCalls, ['Lifal']);
      expect(cubit.state.status, AddressSearchStatus.results);
      expect(cubit.state.matches, hasLength(1));
      // The same settled text again asks nothing.
      cubit.queryChanged('Lifal');
      await _wait();
      expect(repo.searchCalls, ['Lifal']);
      await cubit.close();
    });

    test('fewer than three characters sends nothing and clears the list', () async {
      final cubit = makeSearch();
      cubit.queryChanged('Lifalethu');
      await _wait();
      expect(cubit.state.matches, isNotEmpty);
      cubit.queryChanged('Li');
      await _wait();
      expect(cubit.state.status, AddressSearchStatus.idle);
      expect(cubit.state.matches, isEmpty);
      expect(repo.searchCalls, ['Lifalethu']);
      cubit.queryChanged('   a  ');
      await _wait();
      expect(repo.searchCalls, ['Lifalethu']);
      await cubit.close();
    });

    test('spaces are tidied before the query leaves the device', () async {
      final cubit = makeSearch();
      cubit.queryChanged('  12   Lifalethu \n Avenue ');
      await _wait();
      expect(repo.searchCalls, ['12 Lifalethu Avenue']);
      await cubit.close();
    });

    test('a slow older search never replaces a newer one', () async {
      final slow = Completer<Either<Failure, AddressSearchResult>>();
      repo.searchGates.add(slow);
      final cubit = makeSearch();
      cubit.queryChanged('Lifalethu');
      await _wait(); // the first request is now held
      repo.searchResult = Right(
        const AddressSearchResult(matches: [GeocodeMatch(label: 'Marula Street, Mamelodi', lat: -25.7, lon: 28.35)]),
      );
      cubit.queryChanged('Marula');
      await _wait();
      expect(cubit.state.matches.single.label, 'Marula Street, Mamelodi');
      slow.complete(
        const Right(AddressSearchResult(matches: [GeocodeMatch(label: 'Lifalethu Avenue', lat: -26.5, lon: 29.1)])),
      );
      await _wait();
      expect(cubit.state.matches.single.label, 'Marula Street, Mamelodi', reason: 'the late answer is dropped');
      await cubit.close();
    });

    test('no matches, an off address step, a rate limit and a network failure each have their own state', () async {
      final cubit = makeSearch();
      repo.searchResult = const Right(AddressSearchResult(matches: []));
      cubit.queryChanged('Nowhere');
      await _wait();
      expect(cubit.state.status, AddressSearchStatus.none);
      repo.searchResult = const Left(AddressSearchUnavailableFailure());
      cubit.queryChanged('Nowhere2');
      await _wait();
      expect(cubit.state.status, AddressSearchStatus.unavailable);
      repo.searchResult = const Left(RateLimitedFailure('x', Duration(seconds: 20)));
      cubit.queryChanged('Nowhere3');
      await _wait();
      expect(cubit.state.status, AddressSearchStatus.rateLimited);
      expect(cubit.state.retryAt, clock.add(const Duration(seconds: 20)));
      repo.searchResult = const Left(NetworkFailure());
      cubit.queryChanged('Nowhere4');
      await _wait();
      expect(cubit.state.status, AddressSearchStatus.error);
      await cubit.close();
    });

    test('with_the_address_step_off_the_field_is_off_and_a_network_failure_is_unknown_not_off', () async {
      repo.addressLookupResult = const Right(false);
      final cubit = makeSearch();
      await cubit.load();
      expect(cubit.state.status, AddressSearchStatus.off);
      cubit.queryChanged('Lifalethu');
      await _wait();
      expect(repo.searchCalls, isEmpty, reason: 'nothing is typed into a search that is off');
      repo.addressLookupResult = const Left(NetworkFailure());
      final unknown = makeSearch();
      await unknown.load();
      expect(unknown.state.status, AddressSearchStatus.idle);
      repo.addressLookupResult = const Right(true);
      await unknown.load();
      expect(unknown.state.status, AddressSearchStatus.idle);
      unknown.queryChanged('Lifalethu');
      await _wait();
      expect(repo.searchCalls, ['Lifalethu']);
      await cubit.close();
      await unknown.close();
    });

    test('clear drops the list and cancels a pending search', () async {
      final cubit = makeSearch();
      cubit.queryChanged('Lifalethu');
      cubit.clear();
      await _wait();
      expect(repo.searchCalls, isEmpty);
      expect(cubit.state.status, AddressSearchStatus.idle);
      await cubit.close();
    });

    test('closing_the_page_emits_nothing_after_close', () async {
      final gate = Completer<Either<Failure, AddressSearchResult>>();
      repo.searchGates.add(gate);
      final cubit = makeSearch();
      cubit.queryChanged('Lifalethu');
      await _wait();
      cubit.queryChanged('Lifalethu Avenue'); // a timer is pending too
      await cubit.close();
      gate.complete(Right(repo.searchResult.getOrElse((_) => throw StateError('x'))));
      await _wait();
      expect(repo.searchCalls, hasLength(1));
    });

    test('the state never keeps the typed text', () async {
      final cubit = makeSearch();
      cubit.queryChanged('Lifalethu');
      await _wait();
      expect(cubit.state.toString(), isNot(contains('Lifalethu')));
      await cubit.close();
    });
  });

  group('LocationCubit', () {
    test('location_permission_denied_still_allows_search', () async {
      final service = _FakeLocation()..result = const LocationDenied();
      final location = LocationCubit(service);
      await location.locate();
      expect(location.state.status, LocationStatus.denied);
      // Search is a different cubit and is untouched.
      final search = AddressSearchCubit(repo, debounce: const Duration(milliseconds: 20), now: () => clock);
      search.queryChanged('Lifalethu');
      await _wait();
      expect(search.state.status, AddressSearchStatus.results);
      await search.close();
      await location.close();
    });

    test('permission denied for good, location services off, and a failed read are each their own state', () async {
      final service = _FakeLocation();
      final location = LocationCubit(service);
      service.result = const LocationDeniedForever();
      await location.locate();
      expect(location.state.status, LocationStatus.deniedForever);
      service.result = const LocationServiceOff();
      await location.locate();
      expect(location.state.status, LocationStatus.serviceOff);
      service.result = const LocationFailed();
      await location.locate();
      expect(location.state.status, LocationStatus.failed);
      service.result = const LocationFound(lat: -26.514, lon: 29.103);
      await location.locate();
      expect(location.state.status, LocationStatus.located);
      expect(location.state.point!.lat, -26.514);
      expect(location.state.point.toString(), isNot(contains('26.514')));
      location.reset();
      expect(location.state.status, LocationStatus.idle);
      expect(location.state.point, isNull);
      await location.close();
    });

    test('a second tap while locating asks once, and closing during the read emits nothing', () async {
      final service = _FakeLocation()..gate = Completer<void>();
      final location = LocationCubit(service);
      final first = location.locate();
      await location.locate();
      expect(service.calls, 1);
      await location.close();
      service.gate!.complete();
      await first;
    });
  });
}
