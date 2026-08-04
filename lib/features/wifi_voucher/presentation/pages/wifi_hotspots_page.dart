import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/bloc/wifi_hotspots_cubit.dart';
import 'package:sentech_connect_app/shared/widgets/osm_map.dart';

class WifiHotspotsPage extends StatelessWidget {
  const WifiHotspotsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WiFi hotspots near you')),
      body: BlocBuilder<WifiHotspotsCubit, WifiHotspotsState>(
        builder: (context, state) {
          if (state.status == WifiHotspotsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final theme = Theme.of(context);
          final center = state.hasUserLocation
              ? LatLng(state.userLatitude!, state.userLongitude!)
              : (state.hotspots.isNotEmpty
                  ? LatLng(state.hotspots.first.hotspot.latitude, state.hotspots.first.hotspot.longitude)
                  : southAfricaCenter);

          final markers = [
            for (final h in state.hotspots) brandPin(LatLng(h.hotspot.latitude, h.hotspot.longitude)),
            if (state.hasUserLocation)
              Marker(
                point: LatLng(state.userLatitude!, state.userLongitude!),
                width: 26,
                height: 26,
                child: const Icon(Icons.person_pin_circle, color: Color(0xFF005BAA), size: 26),
              ),
          ];

          return Column(
            children: [
              SizedBox(
                height: 240,
                child: OsmMap(center: center, zoom: state.hasUserLocation ? 13 : 10, markers: markers, borderRadius: BorderRadius.zero),
              ),
              if (!state.hasUserLocation)
                Container(
                  width: double.infinity,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    'Enable location to see which hotspot is closest to you.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.hotspots.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final entry = state.hotspots[i];
                    final isNearest = i == 0 && state.hasUserLocation;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isNearest ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                          width: isNearest ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wifi, color: isNearest ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.hotspot.name, style: theme.textTheme.titleMedium),
                                if (entry.distanceMeters != null)
                                  Text(entry.distanceLabel,
                                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          if (isNearest)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text('CLOSEST', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
