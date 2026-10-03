import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/shared/widgets/osm_map.dart';
import 'helpers/test_setup.dart';

void main() {
  group('MapTileSource.resolve', () {
    test('debug/demo builds default to public OSM tiles', () {
      final source = MapTileSource.resolve(release: false);
      expect(source, isA<OsmDemoTileSource>());
      expect(source.urlTemplate, contains('tile.openstreetmap.org'));
    });

    test('release builds with no provider never use OSM', () {
      final source = MapTileSource.resolve(release: true);
      expect(source, isA<UnavailableTileSource>());
      expect(source.urlTemplate, isNull);
    });

    test(
      'a configured provider wins in every build mode and carries the key',
      () {
        for (final release in [true, false]) {
          final source = MapTileSource.resolve(
            url: 'https://tiles.example.com/{z}/{x}/{y}.png?key={apiKey}',
            apiKey: 'k123',
            attribution: '© Example',
            release: release,
          );
          expect(source, isA<ConfiguredTileSource>());
          expect(source.additionalOptions, {'apiKey': 'k123'});
          expect(source.attribution, '© Example');
        }
      },
    );

    test('cleartext provider URLs are rejected', () {
      final source = MapTileSource.resolve(
        url: 'http://tiles.example.com/{z}/{x}/{y}.png',
        release: false,
      );
      expect(source, isA<UnavailableTileSource>());
    });
  });

  group('OsmMap widget', () {
    setUpAppTests(); // offline tile provider
    tearDown(() => OsmMap.sourceOverride = null);

    Widget host() => const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 200,
          child: OsmMap(center: southAfricaCenter, zoom: 5),
        ),
      ),
    );

    testWidgets(
      'unconfigured source shows a placeholder and builds no tile layer',
      (tester) async {
        OsmMap.sourceOverride = const UnavailableTileSource();
        await tester.pumpWidget(host());
        expect(find.textContaining('Map not available'), findsOneWidget);
        expect(find.byType(FlutterMap), findsNothing);
        expect(find.byType(TileLayer), findsNothing);
      },
    );

    testWidgets(
      'a configured source renders the map with visible attribution',
      (tester) async {
        OsmMap.sourceOverride = const ConfiguredTileSource(
          urlTemplate: 'https://tiles.example.com/{z}/{x}/{y}.png',
          attribution: '© Example Maps',
        );
        await tester.pumpWidget(host());
        expect(find.byType(FlutterMap), findsOneWidget);
        expect(find.text('© Example Maps'), findsOneWidget);
        expect(find.textContaining('Map not available'), findsNothing);
      },
    );
  });
}
