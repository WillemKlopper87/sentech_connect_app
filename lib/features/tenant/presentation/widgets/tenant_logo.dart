import 'package:flutter/material.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/shared/widgets/sentech_logo.dart';

/// Sentech uses the bundled brand asset; other tenants use their public
/// https logo, falling back to an initial when it cannot be loaded.
class TenantLogo extends StatelessWidget {
  const TenantLogo({super.key, required this.tenant, this.height = 32});

  final Tenant tenant;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (tenant.slug == TenantContext.defaultSlug) return SentechLogo(height: height);
    final url = tenant.branding.logoUrl;
    if (url == null) return _initial(context);
    return Image.network(
      url.toString(),
      height: height,
      semanticLabel: tenant.name,
      errorBuilder: (context, _, _) => _initial(context),
    );
  }

  Widget _initial(BuildContext context) => CircleAvatar(
        radius: height / 2,
        backgroundColor: tenant.branding.primaryColor ?? Theme.of(context).colorScheme.primary,
        child: Text(
          tenant.name.isEmpty ? '?' : tenant.name.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      );
}
