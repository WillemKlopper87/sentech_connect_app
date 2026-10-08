import 'package:flutter/material.dart';
import 'package:sentech_connect_app/app/theme/color_contrast.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/shared/widgets/sentech_logo.dart';

/// Sentech uses the bundled brand asset; other tenants use their public
/// https logo, falling back to an initial when it cannot be loaded.
///
/// Set [decorative] when the tenant name is already shown next to the logo,
/// so screen readers do not announce it twice.
class TenantLogo extends StatelessWidget {
  const TenantLogo({super.key, required this.tenant, this.height = 32, this.decorative = false});

  final Tenant tenant;
  final double height;
  final bool decorative;

  /// A remote logo is untrusted: decode it no larger than this box (physical px).
  static const _maxDecodeSide = 512;

  @override
  Widget build(BuildContext context) {
    final Widget logo;
    final url = tenant.branding.logoUrl;
    if (tenant.slug == TenantContext.defaultSlug) {
      logo = SentechLogo(height: height);
    } else if (url == null) {
      logo = _initial(context);
    } else {
      final side = (height * MediaQuery.devicePixelRatioOf(context) * 4).round().clamp(1, _maxDecodeSide);
      final decodeHeight = (height * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, _maxDecodeSide);
      logo = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: height * 4, maxHeight: height),
        child: Image(
          image: ResizeImage(
            NetworkImage(url.toString()),
            width: side,
            height: decodeHeight,
            policy: ResizeImagePolicy.fit,
          ),
          height: height,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          errorBuilder: (context, _, _) => _initial(context),
        ),
      );
    }
    return decorative
        ? ExcludeSemantics(child: logo)
        : Semantics(label: tenant.branding.logoAlt ?? tenant.name, image: true, excludeSemantics: true, child: logo);
  }

  Widget _initial(BuildContext context) {
    final background = tenant.branding.primaryColor ?? Theme.of(context).colorScheme.primary;
    return CircleAvatar(
      radius: height / 2,
      backgroundColor: background,
      child: Text(
        tenant.name.isEmpty ? '?' : tenant.name.substring(0, 1).toUpperCase(),
        style: TextStyle(color: ColorContrast.onColor(background), fontWeight: FontWeight.w800),
      ),
    );
  }
}
