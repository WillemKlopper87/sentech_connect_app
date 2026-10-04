import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/local/data_saver.dart';

/// South Africa's rough centre — used as the default view before a
/// specific location (device GPS or a typed/geocoded address) is known.
const southAfricaCenter = LatLng(-28.4793, 24.6727);

/// Where map tiles come from. Injected at build time so the provider (and its
/// API key) can change without touching code:
///
///   flutter build apk --release \
///     --dart-define=TILE_URL_TEMPLATE=https://api.example.com/tiles/{z}/{x}/{y}.png?key={apiKey} \
///     --dart-define=TILE_API_KEY=... \
///     --dart-define=TILE_ATTRIBUTION="© OpenStreetMap contributors, © ExampleMaps"
///
/// `{apiKey}` in the template is replaced with `TILE_API_KEY`. Keys compiled
/// into an app are extractable, so restrict the key to this app's id and
/// signing certificate at the provider.
///
/// The public OpenStreetMap tile servers are only used for debug/demo builds
/// (their usage policy forbids production apps, and every tile request leaks
/// the viewport to the tile host). A release build with no provider configured
/// shows a placeholder instead and never contacts tile.openstreetmap.org.
abstract class MapTileSource {
  const MapTileSource();

  static const _urlDefine = String.fromEnvironment('TILE_URL_TEMPLATE');
  static const _keyDefine = String.fromEnvironment('TILE_API_KEY');
  static const _attributionDefine = String.fromEnvironment('TILE_ATTRIBUTION');

  /// Picks the source for this build. Parameters exist so tests can cover
  /// release/debug without recompiling.
  static MapTileSource resolve({
    String url = _urlDefine,
    String apiKey = _keyDefine,
    String attribution = _attributionDefine,
    bool release = kReleaseMode,
  }) {
    if (url.isNotEmpty) {
      // HTTPS only: cleartext tile requests are blocked by the network
      // security config anyway, and would expose the key.
      if (!url.startsWith('https://')) return const UnavailableTileSource();
      return ConfiguredTileSource(
        urlTemplate: url,
        apiKey: apiKey.isEmpty ? null : apiKey,
        attribution: attribution.isEmpty
            ? '© OpenStreetMap contributors'
            : attribution,
      );
    }
    return release ? const UnavailableTileSource() : const OsmDemoTileSource();
  }

  /// Null when no tiles may be fetched (see [UnavailableTileSource]).
  String? get urlTemplate;

  Map<String, String> get additionalOptions => const {};

  String get attribution;
}

/// A commercial / self-hosted provider supplied via `--dart-define`.
class ConfiguredTileSource extends MapTileSource {
  const ConfiguredTileSource({
    required this.urlTemplate,
    required this.attribution,
    this.apiKey,
  });

  @override
  final String urlTemplate;
  final String? apiKey;
  @override
  final String attribution;

  @override
  Map<String, String> get additionalOptions =>
      apiKey == null ? const {} : {'apiKey': apiKey!};
}

/// Public OSM tiles — debug/demo builds only.
class OsmDemoTileSource extends MapTileSource {
  const OsmDemoTileSource();

  @override
  String get urlTemplate => 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  String get attribution => '© OpenStreetMap contributors';
}

/// Release build with no provider configured.
class UnavailableTileSource extends MapTileSource {
  const UnavailableTileSource();

  @override
  String? get urlTemplate => null;

  @override
  String get attribution => '';
}

/// An interactive map used for both the coverage-check address pin and the
/// WiFi hotspot locator. Tiles come from [MapTileSource]; see there for how
/// to configure a production provider.
///
/// Note: this fetches tiles over the network on demand. Caching tiles for
/// offline use (e.g. "pre-load South Africa once on WiFi, refresh monthly")
/// is a real, separate engineering project — tile storage budgets,
/// background sync scheduling, cache invalidation — worth scoping on its own.
class OsmMap extends StatelessWidget {
  /// Replaces the network tile provider so widget tests never hit a tile
  /// server. Leave null in production code.
  @visibleForTesting
  static TileProvider? tileProviderOverride;

  /// Replaces the build-time tile source (tests).
  @visibleForTesting
  static MapTileSource? sourceOverride;

  const OsmMap({
    super.key,
    required this.center,
    this.zoom = 14,
    this.markers = const [],
    this.unavailableMessage,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final String? unavailableMessage;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final saver = context.watch<DataSaverCubit?>()?.state ?? false;
    if (saver) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: _MapUnavailable(message: unavailableMessage),
      );
    }
    final source = sourceOverride ?? _buildSource;
    final template = source.urlTemplate;
    if (template == null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: _MapUnavailable(message: unavailableMessage),
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: zoom),
        children: [
          TileLayer(
            urlTemplate: template,
            additionalOptions: source.additionalOptions,
            userAgentPackageName: 'za.co.sentech.sentech_connect_app',
            tileProvider: tileProviderOverride,
          ),
          if (markers.isNotEmpty) MarkerLayer(markers: markers),
          _MapAttribution(text: source.attribution),
        ],
      ),
    );
  }

  static final MapTileSource _buildSource = MapTileSource.resolve();
}

/// Required by OSM-derived tile licences: visible credit on the map.
class _MapAttribution extends StatelessWidget {
  const _MapAttribution({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Semantics(
        label: context.l10n.mapDataAttribution(text),
        child: ColoredBox(
          color: Colors.white.withValues(alpha: 0.8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              text,
              style: const TextStyle(fontSize: 10, color: Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                message ?? context.l10n.mapUnavailable,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A simple pin marker in the app's brand red (matching the CI manual's
/// map-pin usage elsewhere), sized for a 40x40 marker slot.
Marker brandPin(LatLng point, {Color color = const Color(0xFFED1C24)}) {
  return Marker(
    point: point,
    width: 40,
    height: 40,
    child: Icon(Icons.location_on, color: color, size: 36),
  );
}
