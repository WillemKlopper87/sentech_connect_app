import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/geo_point.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/geocode_match.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/address_search_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/coverage_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/location_cubit.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';
import 'package:sentech_connect_app/features/coverage/presentation/coverage_text.dart';
import 'package:sentech_connect_app/features/coverage/presentation/widgets/coverage_result_view.dart';
import 'package:sentech_connect_app/features/coverage/presentation/widgets/leave_list_sheet.dart';
import 'package:sentech_connect_app/features/coverage/presentation/widgets/notify_me_sheet.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/presentation/widgets/consent_gate.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';
import 'package:sentech_connect_app/shared/widgets/osm_map.dart';

/// The customer's coverage check: search an address, use the phone's location or
/// drop a pin, then read the platform's answer. Needs a [CoverageCubit], an
/// [AddressSearchCubit] and a [LocationCubit] above it.
///
/// Privacy: the typed address goes to the customer's provider only (the phone's
/// geocoder is not used), a position is read only when the customer taps the
/// button (after the OS prompt), and nothing here is logged or saved.
class CoveragePage extends StatefulWidget {
  const CoveragePage({super.key, required this.onCovered, this.onSkip});

  /// Carry on to the plans for a covered place.
  final VoidCallback onCovered;

  /// Carry on without a check (never a dead end: the check may be unavailable).
  final VoidCallback? onSkip;

  @override
  State<CoveragePage> createState() => _CoveragePageState();
}

class _CoveragePageState extends State<CoveragePage> {
  final _addressController = TextEditingController();
  final _map = MapController();
  bool _mapReady = false;

  /// The address the customer picked from the search, to start the waiting-list form from (in memory only).
  String? _pickedAddress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CoverageCubit>().load();
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _map.dispose();
    super.dispose();
  }

  void _moveMapTo(GeoPoint point) {
    if (!_mapReady) return;
    try {
      _map.move(LatLng(point.lat, point.lon), 15);
    } on Object {
      // The map may have just been replaced (data saver); the pin is shown on the next build.
    }
  }

  void _pick(GeocodeMatch match) {
    _addressController.text = match.label;
    _pickedAddress = match.label;
    context.read<AddressSearchCubit>().clear();
    final point = GeoPoint(match.lat, match.lon);
    context.read<CoverageCubit>().checkAt(point.lat, point.lon);
    _moveMapTo(point);
    FocusScope.of(context).unfocus();
  }

  void _onMapTap(LatLng point) {
    _addressController.clear();
    _pickedAddress = null;
    context.read<AddressSearchCubit>().clear();
    context.read<CoverageCubit>().pinDropped(point.latitude, point.longitude);
  }

  void _openNotify(CoverageState state, TechnologyInterest interest) {
    final point = state.point;
    if (point == null) return;
    NotifyMeSheet.show(context, point: point, interest: interest, initialAddress: _pickedAddress);
  }

  Future<void> _useMyLocation() async {
    // POPIA: agree to the location notice before any location is read.
    if (!await ensureConsent(context, ConsentPurpose.locationCapture, mapServiceNote: false) || !mounted) return;
    unawaited(context.read<LocationCubit>().locate());
  }

  void _onLocated(LocationState state) {
    final point = state.point;
    if (state.status != LocationStatus.located || point == null) return;
    _addressController.clear();
    _pickedAddress = null;
    context.read<AddressSearchCubit>().clear();
    context.read<CoverageCubit>().checkAt(point.lat, point.lon);
    _moveMapTo(point);
    context.read<LocationCubit>().reset();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.coverageCoverageCheck)),
      body: BlocListener<LocationCubit, LocationState>(
        listener: (context, state) => _onLocated(state),
        child: BlocBuilder<CoverageCubit, CoverageState>(
          builder: (context, state) {
            final point = state.point;
            final covered = state.status == CoverageStatus.ready && (state.check?.hasCoveredOption ?? false);
            return SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SearchField(controller: _addressController),
                          _Suggestions(onPick: _pick),
                          const SizedBox(height: 10),
                          _LocationButton(onPressed: _useMyLocation),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: Semantics(
                              label: l10n.coverageMapSemantics,
                              child: OsmMap(
                                center: point == null ? southAfricaCenter : LatLng(point.lat, point.lon),
                                zoom: point == null ? 5 : 15,
                                controller: _map,
                                onMapReady: () => _mapReady = true,
                                onTap: _onMapTap,
                                markers: point == null ? const [] : [brandPin(LatLng(point.lat, point.lon))],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _ResultSection(
                            state: state,
                            // The waiting list is offered only where the server said so for the answer AND the
                            // provider can take sign-ups (it names both consent texts); an older server has neither.
                            onNotify: state.meta?.canOfferNotify == true ? (interest) => _openNotify(state, interest) : null,
                          ),
                          if (state.meta?.canOfferNotify == true)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton(
                                onPressed: () => LeaveListSheet.show(context),
                                child: Text(l10n.coverageLeaveLink),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (covered)
                          ElevatedButton(
                            onPressed: widget.onCovered,
                            child: Text(l10n.coverageViewPlansForThisAddress),
                          ),
                        if (widget.onSkip != null)
                          TextButton(
                            onPressed: widget.onSkip,
                            child: Text(l10n.coverageSkipForNow),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 200,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          onChanged: context.read<AddressSearchCubit>().queryChanged,
          decoration: InputDecoration(
            labelText: l10n.coverageAddress,
            hintText: l10n.coverageSearchHint,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: l10n.coverageClearSearch,
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        controller.clear();
                        context.read<AddressSearchCubit>().clear();
                      },
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            l10n.coverageSearchPrivacyNote,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onPick});

  final void Function(GeocodeMatch match) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return BlocBuilder<AddressSearchCubit, AddressSearchState>(
      builder: (context, state) {
        Widget note(String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(text, style: theme.textTheme.bodyMedium),
        );
        switch (state.status) {
          case AddressSearchStatus.idle:
            return const SizedBox.shrink();
          case AddressSearchStatus.searching:
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                label: l10n.coverageSearching,
                child: const LinearProgressIndicator(minHeight: 3),
              ),
            );
          case AddressSearchStatus.none:
            return note(l10n.coverageNoAddressMatches);
          case AddressSearchStatus.unavailable:
            return note(l10n.failureAddressSearchUnavailable);
          case AddressSearchStatus.rateLimited:
            return note(l10n.coverageSearchRateLimited);
          case AddressSearchStatus.error:
            return note(state.failure == null ? l10n.failureSomethingWentWrongPleaseTryAgain : coverageFailureText(l10n, state.failure!));
          case AddressSearchStatus.results:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.matched == MatchPrecision.street) note(l10n.coverageMatchedStreet),
                if (state.matched == MatchPrecision.area) note(l10n.coverageMatchedArea),
                for (final match in state.matches)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minVerticalPadding: 8,
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(match.label),
                    onTap: () => onPick(match),
                  ),
              ],
            );
        }
      },
    );
  }
}

class _LocationButton extends StatelessWidget {
  const _LocationButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return BlocBuilder<LocationCubit, LocationState>(
      builder: (context, state) {
        final locating = state.status == LocationStatus.locating;
        final message = switch (state.status) {
          LocationStatus.serviceOff => l10n.coverageTurnOnLocationServicesToUse,
          LocationStatus.denied => l10n.coverageLocationPermissionDeniedEnterYourAddress,
          LocationStatus.deniedForever => l10n.coverageLocationDeniedForever,
          LocationStatus.failed => l10n.coverageCouldNotGetYourLocationCheck,
          _ => null,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: locating ? null : onPressed,
              icon: locating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, size: 18),
              label: Text(l10n.coverageUseMyCurrentLocation),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.coverageLocationExplain,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
              ),
          ],
        );
      },
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.state, this.onNotify});

  final CoverageState state;
  final void Function(TechnologyInterest interest)? onNotify;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cubit = context.read<CoverageCubit>();
    switch (state.status) {
      case CoverageStatus.idle:
        return Text(l10n.coverageStartHint, style: theme.textTheme.bodyMedium);
      case CoverageStatus.loading:
        return Row(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.coverageChecking)),
          ],
        );
      case CoverageStatus.unavailable:
        return _Notice(
          icon: Icons.cloud_off_outlined,
          text: l10n.coverageNoDataYet,
          action: OutlinedButton.icon(
            onPressed: cubit.retry,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l10n.commonRetry),
          ),
        );
      case CoverageStatus.outside:
        return _Notice(icon: Icons.public_off_outlined, text: l10n.failureOutsideServiceArea);
      case CoverageStatus.rateLimited:
        return _RateLimitNotice(retryAt: state.retryAt, now: cubit.now, onRetry: cubit.retry);
      case CoverageStatus.error:
        return FailureView(failure: state.failure, compact: true, onRetry: cubit.retry);
      case CoverageStatus.ready:
        return CoverageResultView(check: state.check!, meta: state.meta, onNotify: onNotify, onRetry: cubit.retry);
    }
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        ),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    );
  }
}

/// Counts down the server's `Retry-After`; the retry button works only when it has run out.
class _RateLimitNotice extends StatefulWidget {
  const _RateLimitNotice({required this.retryAt, required this.now, required this.onRetry});

  final DateTime? retryAt;
  final DateTime Function() now;
  final VoidCallback onRetry;

  @override
  State<_RateLimitNotice> createState() => _RateLimitNoticeState();
}

class _RateLimitNoticeState extends State<_RateLimitNotice> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final until = widget.retryAt;
    final left = until == null ? Duration.zero : until.difference(widget.now());
    final waiting = left > Duration.zero;
    final seconds = (left.inMilliseconds / 1000).ceil();
    return _Notice(
      icon: Icons.hourglass_bottom,
      text: waiting ? l10n.coverageRateLimitedWait(seconds.toString()) : l10n.coverageRateLimitedNow,
      action: OutlinedButton.icon(
        onPressed: waiting ? null : widget.onRetry,
        icon: const Icon(Icons.refresh, size: 18),
        label: Text(l10n.commonRetry),
      ),
    );
  }
}
