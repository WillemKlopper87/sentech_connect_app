import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';

/// Support tickets are on only when the provider's plan has the `tickets`
/// module AND Sentech's `ticketing` kill switch is literally `true` in a LOADED
/// app config (the platform runbook: one switch per provider, the module
/// decides while the kill switch is on). Either one missing, an unknown or
/// non-boolean flag, a server that reports no modules, or no config yet all read
/// as OFF: the entry never appears by accident, and the existing contact form
/// stays the way to reach support. (The server enforces the same two gates on
/// every route.)
bool ticketsOn(TenantState state) =>
    // `featureFlags` falls back to the demo flags without a config: only a loaded config may open the gate.
    state.config != null &&
    state.status == TenantStatus.ready &&
    state.isModuleOn(AppModuleKeys.tickets) &&
    state.featureFlags.ticketing;

/// The router bounces the ticket pages back to Home when the provider's config
/// is loaded and tickets are off. Before the config loads they stay, so a deep
/// link at launch is not lost (the screens then say so in words if the server
/// refuses).
bool ticketsRoutesOff(TenantCubit? tenant) =>
    tenant != null && tenant.state.status == TenantStatus.ready && !ticketsOn(tenant.state);
