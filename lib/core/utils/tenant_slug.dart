/// Tenant slugs are lowercase letters, digits and hyphens (2-40 chars). The
/// single definition: directory entries (`Tenant`) and the request-building
/// `TenantContext` both validate against it.
final tenantSlugPattern = RegExp(r'^[a-z0-9-]{2,40}$');
