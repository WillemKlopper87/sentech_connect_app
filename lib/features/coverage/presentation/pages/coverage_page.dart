import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentech_connect_app/core/utils/reverse_geocode.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/coverage_cubit.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/presentation/widgets/consent_gate.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';
import 'package:sentech_connect_app/shared/widgets/osm_map.dart';

class CoveragePage extends StatefulWidget {
  const CoveragePage({super.key, required this.onCovered});

  final VoidCallback onCovered;

  @override
  State<CoveragePage> createState() => _CoveragePageState();
}

class _CoveragePageState extends State<CoveragePage> {
  final _addressController = TextEditingController(
    text: '12 Lifalethu Ave, eMbalenhle',
  );
  bool _locating = false;
  LatLng? _currentLatLng;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkAddress(_addressController.text),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  /// Checks coverage for the given address and, best-effort, forward
  /// geocodes it so the map can centre on a real point — falling back to
  /// the default South Africa-wide view if that lookup fails (e.g. no
  /// network, or an address the geocoder can't resolve).
  Future<void> _checkAddress(String address) async {
    context.read<CoverageCubit>().checkAddress(address);
    try {
      final locations = await Geocoding().locationFromAddress(address);
      if (locations.isNotEmpty && mounted) {
        setState(
          () => _currentLatLng = LatLng(
            locations.first.latitude,
            locations.first.longitude,
          ),
        );
      }
    } catch (_) {
      // Keep whatever map view we already had (or the SA-wide default).
    }
  }

  Future<void> _useDeviceLocation() async {
    // POPIA: agree to the location notice before any location is read.
    if (!await ensureConsent(context, ConsentPurpose.locationCapture) ||
        !mounted) {
      return;
    }
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        _showMessage(context.l10n.coverageTurnOnLocationServicesToUse);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage(
          context.l10n.coverageLocationPermissionDeniedEnterYourAddress,
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final address = await reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      _addressController.text =
          address ??
          context.l10n.coverageCurrentLocation(
            position.latitude.toStringAsFixed(4),
            position.longitude.toStringAsFixed(4),
          );
      if (mounted) {
        setState(
          () => _currentLatLng = LatLng(position.latitude, position.longitude),
        );
        context.read<CoverageCubit>().checkAddress(_addressController.text);
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage(context.l10n.coverageCouldNotGetYourLocationCheck);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.coverageCoverageCheck)),
      body: BlocBuilder<CoverageCubit, CoverageState>(
        builder: (context, state) {
          final checking = state.status == CoverageStatus.checking;
          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: context.l10n.coverageAddress,
                            prefixIcon: Icon(
                              Icons.location_on_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                        // A typed address is forward-geocoded by the platform
                        // geocoder (Google or Apple) to centre the map.
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            context.l10n.coverageAddressLookupNotice,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _locating ? null : _useDeviceLocation,
                          icon: _locating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location, size: 18),
                          label: Text(
                            context.l10n.coverageUseMyCurrentLocation,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 180,
                          child: OsmMap(
                            center: _currentLatLng ?? southAfricaCenter,
                            zoom: _currentLatLng != null ? 15 : 5,
                            markers: _currentLatLng == null
                                ? const []
                                : [brandPin(_currentLatLng!)],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (checking)
                          const Center(child: CircularProgressIndicator()),
                        if (state.status == CoverageStatus.failure)
                          FailureView(
                            failure: state.failure,
                            compact: true,
                            onRetry: () =>
                                context.read<CoverageCubit>().retry(),
                          ),
                        if (state.status == CoverageStatus.checked &&
                            state.result != null)
                          _ResultCard(
                            covered: state.result!.isCovered,
                            speed: state.result!.estimatedSpeedMbps,
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state.status == CoverageStatus.checked &&
                          state.result?.isCovered == true) ...[
                        ElevatedButton(
                          onPressed: widget.onCovered,
                          child: Text(
                            context.l10n.coverageViewPlansForThisAddress,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () =>
                              context.read<CoverageCubit>().reset(),
                          child: Text(
                            context.l10n.coverageCheckADifferentAddress,
                          ),
                        ),
                      ] else
                        ElevatedButton(
                          onPressed: checking
                              ? null
                              : () => _checkAddress(_addressController.text),
                          child: Text(context.l10n.coverageCheckThisAddress),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.covered, required this.speed});

  final bool covered;
  final int speed;

  @override
  Widget build(BuildContext context) {
    final color = covered
        ? const Color(0xFF6F9126)
        : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            covered ? Icons.check_circle : Icons.error_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  covered
                      ? context.l10n.coverageHomeInternetIsAvailableHere
                      : context.l10n.coverageNotYetCovered,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (covered)
                  Text(
                    context.l10n.coverageEstimatedSpeed(speed.toString()),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
