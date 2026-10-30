import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';

/// Every subscriber screen (plans, services, invoices, ID check, signup) is
/// hidden unless the provider has the `subscriber_billing` module on.
/// `GET /v1/app-config` already reports the effective value (plan, tenant
/// override and kill switch folded in), so this is the only gate the app
/// needs; the two server refusals (403 `module_not_enabled`, 409
/// `feature_disabled`) are still mapped for races. False until a config is
/// loaded.
bool subscriberBillingOn(TenantState state) => state.isModuleOn(AppModuleKeys.subscriberBilling);
