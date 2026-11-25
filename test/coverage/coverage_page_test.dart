import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/coverage/domain/device_location.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_check.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/geocode_match.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/address_search_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/coverage_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/location_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/pages/coverage_page.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/consent_repository.dart';
import 'package:sentech_connect_app/shared/widgets/osm_map.dart';
import 'package:sentech_connect_app/app/locator.dart';

import '../helpers/pump_themed.dart';
import '../helpers/test_setup.dart';
import 'fake_coverage_repository.dart';

class _FakeLocation implements DeviceLocationService {
  DeviceLocationResult result = const LocationFound(lat: -26.514, lon: 29.103);
  int calls = 0;

  @override
  Future<DeviceLocationResult> current() async {
    calls++;
    return result;
  }
}

void main() {
  setUpAppTests();

  late FakeCoverageRepository repo;
  late _FakeLocation location;
  var clock = DateTime.utc(2026, 11, 26, 10);

  setUp(() {
    repo = FakeCoverageRepository();
    location = _FakeLocation();
    clock = DateTime.utc(2026, 11, 26, 10);
  });

  Future<void> pump(WidgetTester tester, {VoidCallback? onCovered, VoidCallback? onSkip}) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpThemed(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => CoverageCubit(repo, debounce: const Duration(milliseconds: 10), now: () => clock)),
          BlocProvider(create: (_) => AddressSearchCubit(repo, debounce: const Duration(milliseconds: 10), now: () => clock)),
          BlocProvider(create: (_) => LocationCubit(location)),
        ],
        child: CoveragePage(onCovered: onCovered ?? () {}, onSkip: onSkip),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> grantLocationConsent() async {
    await locator<ConsentRepository>().grant(ConsentPurpose.locationCapture);
  }

  testWidgets('shows the search, the location button, a map and the plain start hint, and reads the provider meta', (tester) async {
    await pump(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Use my current location'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.textContaining('Search for an address'), findsOneWidget);
    expect(repo.metaCalls, 1);
    // The phone's map service is not used for the typed address.
    expect(find.textContaining("phone's map service"), findsNothing);
    expect(find.textContaining('sent to your provider'), findsWidgets);
  });

  testWidgets('typing an address lists the platform matches, and picking one checks that place and moves the pin', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Lifalethu');
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    expect(repo.searchCalls, ['Lifalethu']);
    expect(find.text('12 Lifalethu Avenue, eMbalenhle'), findsOneWidget);
    await tester.tap(find.text('12 Lifalethu Avenue, eMbalenhle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(repo.checkCalls, [(lat: -26.514, lon: 29.103)]);
    expect(find.byIcon(Icons.location_on), findsOneWidget, reason: 'the pin is on the map');
    // The list closes once a place is picked.
    expect(find.text('12 Lifalethu Avenue, eMbalenhle'), findsOneWidget, reason: 'only the field still holds it');
  });

  testWidgets('a street-level match says the house number was not found', (tester) async {
    repo.searchResult = const Right(
      AddressSearchResult(
        matches: [GeocodeMatch(label: 'Lifalethu Avenue, eMbalenhle', lat: -26.5, lon: 29.1, precision: MatchPrecision.street)],
        matched: MatchPrecision.street,
      ),
    );
    await pump(tester);
    await tester.enterText(find.byType(TextField), '99 Lifalethu');
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    expect(find.textContaining('could not find that house number'), findsOneWidget);
  });

  testWidgets('address search off on the platform says so and leaves the location button and the map working', (tester) async {
    repo.searchResult = const Left(AddressSearchUnavailableFailure());
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Lifalethu');
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    expect(find.textContaining('Address search is not available'), findsOneWidget);
    expect(find.text('Use my current location'), findsOneWidget);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.options.onTap!(const TapPosition(Offset.zero, Offset.zero), const LatLng(-26.2, 28.0));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    expect(repo.checkCalls, [(lat: -26.2, lon: 28.0)]);
  });

  testWidgets('a map tap drops a pin and checks that point once the taps settle', (tester) async {
    await pump(tester);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.options.onTap!(const TapPosition(Offset.zero, Offset.zero), const LatLng(-26.2, 28.0));
    map.options.onTap!(const TapPosition(Offset.zero, Offset.zero), const LatLng(-26.3, 28.1));
    await tester.pump();
    expect(find.byIcon(Icons.location_on), findsOneWidget);
    expect(repo.checkCalls, isEmpty, reason: 'waits for the taps to settle');
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    expect(repo.checkCalls, [(lat: -26.3, lon: 28.1)]);
  });

  testWidgets('the answer is the server cards with the release of the data shown, and a new tap clears it at once', (tester) async {
    await pump(tester);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.options.onTap!(const TapPosition(Offset.zero, Offset.zero), const LatLng(-26.2, 28.0));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    expect(find.text('5G: predicted coverage'), findsOneWidget);
    expect(find.text('LTE (4G): predicted coverage'), findsOneWidget);
    expect(find.textContaining('Network data: 2026 Q4 plan'), findsOneWidget);
    final gate = Completer<Either<Failure, CoverageCheck>>();
    repo.checkGates.add(gate);
    map.options.onTap!(const TapPosition(Offset.zero, Offset.zero), const LatLng(-26.3, 28.0));
    await tester.pump();
    expect(find.text('5G: predicted coverage'), findsNothing, reason: 'the old answer is not shown for the new point');
    expect(find.text('Checking coverage…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 30));
    gate.complete(Right(checkFixture('coverage_check_planned.json')));
    await tester.pump();
    await tester.pump();
    expect(find.text('5G: planned'), findsOneWidget);
  });

  testWidgets('a tap outside the service area is explained and sends nothing', (tester) async {
    await pump(tester);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.options.onTap!(const TapPosition(Offset.zero, Offset.zero), const LatLng(-10.0, 28.0));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    expect(find.textContaining('only check places in South Africa'), findsOneWidget);
    expect(repo.checkCalls, isEmpty);
  });

  testWidgets('use my location checks the phone position after consent, and says nothing about a geocoder', (tester) async {
    await pump(tester);
    await grantLocationConsent();
    await tester.tap(find.text('Use my current location'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(location.calls, 1);
    expect(repo.checkCalls, [(lat: -26.514, lon: 29.103)]);
  });

  testWidgets('location_permission_denied_still_allows_search', (tester) async {
    location.result = const LocationDenied();
    await pump(tester);
    await grantLocationConsent();
    await tester.tap(find.text('Use my current location'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('permission denied'), findsOneWidget);
    expect(repo.checkCalls, isEmpty);
    await tester.enterText(find.byType(TextField), 'Lifalethu');
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    expect(find.text('12 Lifalethu Avenue, eMbalenhle'), findsOneWidget);
  });

  testWidgets('location denied for good and location services off are explained in words', (tester) async {
    location.result = const LocationDeniedForever();
    await pump(tester);
    await grantLocationConsent();
    await tester.tap(find.text('Use my current location'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('turned off for this app'), findsOneWidget);
    location.result = const LocationServiceOff();
    await tester.tap(find.text('Use my current location'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Turn on location services'), findsOneWidget);
  });

  testWidgets('an older server or a provider with no data says so in words with a retry, never an empty screen', (tester) async {
    repo.metaResult = const Left(CoverageUnavailableFailure());
    await pump(tester);
    expect(find.textContaining('not available yet'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    repo.metaResult = Right(metaFixture());
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Search for an address'), findsOneWidget);
  });

  testWidgets('a failed check shows the plain network message and a retry that asks again', (tester) async {
    repo.checkResult = const Left(NetworkFailure());
    await pump(tester);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.options.onTap!(const TapPosition(Offset.zero, Offset.zero), const LatLng(-26.2, 28.0));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    expect(find.textContaining("You're offline"), findsOneWidget);
    repo.checkResult = Right(checkFixture());
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(repo.checkCalls, hasLength(2));
    expect(find.textContaining("You're offline"), findsNothing);
  });

  testWidgets('a rate limit counts down the server wait and enables the retry only when it has run out', (tester) async {
    repo.checkResult = const Left(RateLimitedFailure('x', Duration(seconds: 5)));
    await pump(tester);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.options.onTap!(const TapPosition(Offset.zero, Offset.zero), const LatLng(-26.2, 28.0));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    expect(find.textContaining('try again in 5 seconds'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Retry')).onPressed, isNull);
    clock = clock.add(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('try again now'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Retry')).onPressed, isNotNull);
  });

  testWidgets('the skip button is always there so the first-run screen is never a dead end', (tester) async {
    var skipped = 0;
    repo.metaResult = const Left(CoverageUnavailableFailure());
    await pump(tester, onSkip: () => skipped++);
    await tester.tap(find.text('Skip for now'));
    expect(skipped, 1);
  });

  testWidgets('view plans appears only for an answer with a covered option', (tester) async {
    var covered = 0;
    await pump(tester, onCovered: () => covered++);
    expect(find.text('View plans for this address'), findsNothing);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.options.onTap!(const TapPosition(Offset.zero, Offset.zero), const LatLng(-26.2, 28.0));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    await tester.ensureVisible(find.text('View plans for this address'));
    await tester.tap(find.text('View plans for this address'));
    expect(covered, 1);
    // A planned-only answer offers no plans.
    repo.checkResult = Right(checkFixture('coverage_check_planned.json'));
    final map2 = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map2.options.onTap!(const TapPosition(Offset.zero, Offset.zero), const LatLng(-26.4, 28.0));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    expect(find.text('View plans for this address'), findsNothing);
  });

  testWidgets('closing the page while a check and a search are in flight throws nothing', (tester) async {
    final gate = Completer<Either<Failure, CoverageCheck>>();
    repo.checkGates.add(gate);
    await pump(tester);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.options.onTap!(const TapPosition(Offset.zero, Offset.zero), const LatLng(-26.2, 28.0));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(const SizedBox.shrink());
    gate.complete(Right(checkFixture()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the data saver hides the map but search and location still work', (tester) async {
    OsmMap.sourceOverride = const UnavailableTileSource();
    addTearDown(() => OsmMap.sourceOverride = null);
    await pump(tester);
    expect(find.byType(FlutterMap), findsNothing);
    await tester.enterText(find.byType(TextField), 'Lifalethu');
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    expect(find.text('12 Lifalethu Avenue, eMbalenhle'), findsOneWidget);
  });
}
