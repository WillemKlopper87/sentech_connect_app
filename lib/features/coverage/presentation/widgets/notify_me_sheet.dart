import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/coverage/data/pending_lead_keys.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/geo_point.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';
import 'package:sentech_connect_app/features/coverage/domain/repositories/coverage_repository.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/coverage_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/notify_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/coverage_text.dart';
import 'package:sentech_connect_app/features/coverage/presentation/widgets/contact_input.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// The waiting-list form for the place that was checked. Two separate consent tick
/// boxes, both unticked, each naming the consent text version the platform expects
/// (from `GET /v1/coverage/meta`): the waiting list itself, and the optional "tell me
/// if coverage arrives or improves". Needs a [CoverageCubit] (for the meta) and a
/// [NotifyCubit] above it; [show] builds both. The contact, address and place go to
/// the customer's provider only, and the contact is gone from the screen once the
/// sign-up is accepted.
class NotifyMeSheet extends StatefulWidget {
  const NotifyMeSheet({super.key, required this.point, required this.interest, this.initialAddress});

  final GeoPoint point;
  final TechnologyInterest interest;

  /// The address the customer picked, to start from (editable); null for a pin or the phone's location.
  final String? initialAddress;

  static Future<void> show(
    BuildContext context, {
    required GeoPoint point,
    required TechnologyInterest interest,
    String? initialAddress,
  }) {
    final coverage = context.read<CoverageCubit>();
    final repository = context.read<CoverageRepository>();
    final pending = locator<PendingLeadKeys>();
    final scope = PendingLeadKeys.scopeFor(locator<TenantContext>().slug, point.lat, point.lon, interest);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: coverage),
          BlocProvider(create: (_) => NotifyCubit(repository, pending: pending, scope: scope)),
        ],
        child: NotifyMeSheet(point: point, interest: interest, initialAddress: initialAddress),
      ),
    );
  }

  @override
  State<NotifyMeSheet> createState() => NotifyMeSheetState();
}

class NotifyMeSheetState extends State<NotifyMeSheet> {
  final _contact = TextEditingController();
  late final TextEditingController _address = TextEditingController(text: widget.initialAddress ?? '');
  var _kind = ContactKind.phone;
  late var _interest = widget.interest;
  var _consent = false;
  var _arrival = false;
  var _contactTouched = false;
  Timer? _ticker;

  /// What the form holds right now (contact and address). Empty once a sign-up is accepted.
  @visibleForTesting
  String get heldText => _contact.text + _address.text;

  void _tickWhileWaiting(DateTime? until, DateTime Function() now) {
    _ticker?.cancel();
    if (until == null || !now().isBefore(until)) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !now().isBefore(until)) timer.cancel();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _contact.dispose();
    _address.dispose();
    super.dispose();
  }

  bool get _addressOk => _address.text.trim().length >= 5;

  void _submit(NotifyState state) {
    final meta = context.read<CoverageCubit>().state.meta;
    final waitlist = meta?.waitlistConsentVersion;
    final arrival = meta?.coverageArrivedConsentVersion;
    if (waitlist == null || arrival == null || !_consent || !_addressOk || !isPlausibleContact(_kind, _contact.text)) return;
    context.read<NotifyCubit>().submit(
      NotifyRequest(
        contactType: _kind,
        contactValue: _contact.text.trim(),
        addressText: _address.text.trim(),
        lat: widget.point.lat,
        lon: widget.point.lon,
        technologyInterest: _interest,
        waitlistConsentVersion: waitlist,
        arrivalConsentGranted: _arrival,
        arrivalConsentVersion: arrival,
      ),
    );
  }

  String? _message(AppLocalizations l10n, NotifyState state) {
    final failure = state.failure;
    if (state.consentOutdated) return l10n.coverageNotifyReconfirm;
    if (failure is HumanCheckCancelledFailure) return state.outcomeUnknown ? l10n.coverageNotifyPending : null;
    final until = state.retryAt;
    if (failure is RateLimitedFailure && until != null) {
      final left = until.difference(context.read<NotifyCubit>().now());
      if (left > Duration.zero) return l10n.coverageNotifyRateLimitedWait(((left.inMilliseconds) / 1000).ceil().toString());
      return null;
    }
    if (failure != null) {
      final text = coverageFailureText(l10n, failure);
      if (state.outcomeUnknown) return '${l10n.coverageNotifyPending}\n$text';
      if (state.notSent) return '${l10n.coverageNotifyNotSent}\n$text';
      return text;
    }
    return state.outcomeUnknown ? l10n.coverageNotifyPending : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final meta = context.select((CoverageCubit cubit) => cubit.state.meta);
    return BlocConsumer<NotifyCubit, NotifyState>(
      listenWhen: (previous, current) =>
          (current.consentOutdated && !previous.consentOutdated) ||
          (current.status == NotifyStatus.done && previous.status != NotifyStatus.done) ||
          current.retryAt != previous.retryAt,
      listener: (context, state) {
        if (state.status == NotifyStatus.done) {
          // Accepted: nothing the customer typed stays on the screen.
          _contact.clear();
          _address.clear();
          return;
        }
        _tickWhileWaiting(state.retryAt, context.read<NotifyCubit>().now);
        if (!state.consentOutdated) return;
        // The consent text changed: both boxes are cleared so the customer reads and ticks again,
        // and the new versions are read.
        setState(() {
          _consent = false;
          _arrival = false;
        });
        context.read<CoverageCubit>().refreshMeta();
      },
      builder: (context, state) {
        final bottom = MediaQuery.viewInsetsOf(context).bottom;
        if (state.status == NotifyStatus.done) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.check_circle_outline, size: 36, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(l10n.coverageNotifySent, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(l10n.coverageNotifyDone)),
              ],
            ),
          );
        }
        final submitting = state.status == NotifyStatus.submitting;
        final message = _message(l10n, state);
        final waiting = state.retryAt != null && context.read<NotifyCubit>().now().isBefore(state.retryAt!);
        final canSend = !submitting &&
            !waiting &&
            _consent &&
            _addressOk &&
            isPlausibleContact(_kind, _contact.text) &&
            (meta?.canOfferNotify ?? false);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text(l10n.coverageNotifyTitle, style: theme.textTheme.titleLarge)),
              const SizedBox(height: 8),
              Text(l10n.coverageNotifyIntro),
              const SizedBox(height: 16),
              Text(l10n.coverageNotifyInterest, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<TechnologyInterest>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: TechnologyInterest.any, label: Text(l10n.coverageInterestAny)),
                  ButtonSegment(value: TechnologyInterest.fiveG, label: Text(l10n.coverageTech5g)),
                  ButtonSegment(value: TechnologyInterest.lte, label: Text(l10n.coverageTechLte)),
                ],
                selected: {_interest},
                onSelectionChanged: submitting ? null : (selected) => setState(() => _interest = selected.first),
              ),
              const SizedBox(height: 16),
              ContactInput(
                fieldKey: const ValueKey('notify-contact'),
                controller: _contact,
                kind: _kind,
                showError: _contactTouched,
                onKindChanged: (kind) => setState(() {
                  _kind = kind;
                  _contact.clear();
                  _contactTouched = false;
                }),
                onChanged: () => setState(() => _contactTouched = true),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('notify-address'),
                controller: _address,
                maxLength: 300,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.coverageAddress,
                  hintText: l10n.coverageNotifyAddressHint,
                  errorText: _address.text.isNotEmpty && !_addressOk ? l10n.coverageNotifyAddressInvalid : null,
                ),
              ),
              const SizedBox(height: 12),
              // Two separate consents, both unticked by default; ticking one never ticks the other.
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _consent,
                onChanged: submitting ? null : (value) => setState(() => _consent = value ?? false),
                title: Text(l10n.coverageNotifyConsent),
                subtitle: Text(l10n.coverageNotifyConsentNote(meta?.waitlistConsentVersion ?? '')),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _arrival,
                onChanged: submitting ? null : (value) => setState(() => _arrival = value ?? false),
                title: Text(l10n.coverageNotifyArrivalConsent),
                subtitle: Text(l10n.coverageNotifyArrivalNote(meta?.coverageArrivedConsentVersion ?? '')),
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('notify-submit'),
                onPressed: canSend ? () => _submit(state) : null,
                child: submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.coverageNotifySubmit),
              ),
            ],
          ),
        );
      },
    );
  }
}
