import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentech_connect_app/core/local/app_preferences.dart';
import 'package:sentech_connect_app/core/local/data_saver.dart';
import 'package:sentech_connect_app/shared/widgets/osm_map.dart';

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
}
