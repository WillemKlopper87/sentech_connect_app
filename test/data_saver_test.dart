import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/app_preferences.dart';
import 'package:sentech_connect_app/core/local/data_saver.dart';
import 'package:sentech_connect_app/shared/widgets/osm_map.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/bloc/wifi_hotspots_cubit.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/pages/wifi_hotspots_page.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/entities/wifi_hotspot.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/wifi_hotspots_repository.dart';
import 'package:sentech_connect_app/features/coverage/data/repositories/mock_coverage_repository.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/coverage_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/pages/coverage_page.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class _CountingTiles extends TileProvider {
  int requests = 0;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    requests++;
    return MemoryImage(_png);
  }
}

class _PendingHotspotsRepository implements WifiHotspotsRepository {
  @override
  Future<Either<Failure, List<WifiHotspot>>> getHotspots() =>
      Completer<Either<Failure, List<WifiHotspot>>>().future;
}

class _LoadedHotspotsCubit extends WifiHotspotsCubit {
  _LoadedHotspotsCubit() : super(_PendingHotspotsRepository()) {
    emit(
      const WifiHotspotsState(
        status: WifiHotspotsStatus.loaded,
        hotspots: [
          HotspotDistance(
            hotspot: WifiHotspot(
              id: 'hs_1',
              name: 'eMbalenhle Community Hall',
              latitude: -26.6873,
              longitude: 29.0721,
            ),
            distanceMeters: null,
          ),
        ],
      ),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OsmMap.sourceOverride = const ConfiguredTileSource(
      urlTemplate: 'https://tiles.example.com/{z}/{x}/{y}.png',
      attribution: '© Example Maps',
    );
  });
  tearDown(() {
    OsmMap.tileProviderOverride = null;
    OsmMap.sourceOverride = null;
  });

  test('saver persists across cubit instances', () async {
    final first = DataSaverCubit();
    await first.set(true);
    expect(await AppPreferences.loadDataSaver(), isTrue);
    await first.close();
    final second = DataSaverCubit();
    await second.load();
    expect(second.state, isTrue);
    await second.close();
  });

  test('failed save leaves the visible state at its saved value', () async {
    final saver = DataSaverCubit(save: (_) async => throw StateError('disk'));
    await expectLater(saver.set(true), throwsStateError);
    expect(saver.state, isFalse);
    await saver.close();
  });

  test(
    'late save completion cannot replace newer choice or a closed cubit',
    () async {
      final first = Completer<void>();
      final second = Completer<void>();
      var writes = 0;
      final saver = DataSaverCubit(
        save: (_) => ++writes == 1 ? first.future : second.future,
      );
      final old = saver.set(true);
      final latest = saver.set(false);
      first.completeError(StateError('first failed'));
      await old;
      second.complete();
      await latest;
      expect(saver.state, isFalse);
      final third = Completer<void>();
      final closing = DataSaverCubit(save: (_) => third.future);
      final pending = closing.set(true);
      await closing.close();
      third.complete();
      await pending;
      expect(closing.state, isFalse);
      await saver.close();
    },
  );

  testWidgets('saver avoids tile requests and restores map when switched off', (
    tester,
  ) async {
    final tiles = _CountingTiles();
    OsmMap.tileProviderOverride = tiles;
    final saver = DataSaverCubit(initial: true);
    await tester.pumpWidget(
      BlocProvider.value(
        value: saver,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: OsmMap(center: southAfricaCenter),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.byType(TileLayer), findsNothing);
    expect(tiles.requests, 0);

    await saver.set(false);
    await tester.pump();
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(tiles.requests, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    await saver.close();
  });

  testWidgets('saver keeps real hotspot list without map or tiles', (
    tester,
  ) async {
    final tiles = _CountingTiles();
    OsmMap.tileProviderOverride = tiles;
    final saver = DataSaverCubit(initial: true);
    final hotspots = _LoadedHotspotsCubit();
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: saver),
          BlocProvider<WifiHotspotsCubit>.value(value: hotspots),
        ],
        child: const MaterialApp(home: WifiHotspotsPage()),
      ),
    );
    expect(find.text('eMbalenhle Community Hall'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
    expect(tiles.requests, 0);
    await tester.pumpWidget(const SizedBox());
    await hotspots.close();
    await saver.close();
  });

  testWidgets('saver keeps typed coverage address and results', (tester) async {
    final tiles = _CountingTiles();
    OsmMap.tileProviderOverride = tiles;
    final saver = DataSaverCubit(initial: true);
    final coverage = CoverageCubit(MockCoverageRepository());
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: saver),
          BlocProvider.value(value: coverage),
        ],
        child: MaterialApp(home: CoveragePage(onCovered: () {})),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      find.widgetWithText(TextField, '12 Lifalethu Ave, eMbalenhle'),
      findsOneWidget,
    );
    expect(find.text('Home internet is available here'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
    expect(tiles.requests, 0);
    await tester.pumpWidget(const SizedBox());
    await coverage.close();
    await saver.close();
  });
}
