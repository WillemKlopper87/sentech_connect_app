import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';

/// Rewards (credits) are on only when the provider's plan has the `credits`
/// module AND the `credits` feature flag is on. Either one missing, an unknown
/// or absent flag, a server that does not report modules, or no tenant config
/// yet all read as OFF: an unfinished or unavailable feature never appears by
/// accident. (The server enforces the same two gates on every route.)
bool creditsOn(TenantState state) =>
    state.isModuleOn(AppModuleKeys.credits) && state.featureFlags.credits;

/// The router bounces the Rewards pages back to Home when the provider's config
/// is loaded and rewards are off. Before the config loads they stay, so a deep
/// link at launch is not lost.
bool creditsRoutesOff(TenantCubit? tenant) =>
    tenant != null && tenant.state.status == TenantStatus.ready && !creditsOn(tenant.state);
