import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';

/// The platform's accept/decline/redirect URLs look like
/// `{web}/{tenant-slug}/checkout/{accepted|declined|return}`. Reaching one
/// only ends the hand-off; the order state always comes from the API.
final _returnPath = RegExp(
  r'^/[a-z0-9-]{2,40}/checkout/(accepted|declined|return)/?$',
);

bool isPaymentReturnUrl(Uri uri) =>
    (uri.scheme == 'https' || uri.scheme == 'http') &&
    _returnPath.hasMatch(uri.path);

/// The web view only ever navigates to https (and `about:blank`); local
/// cleartext only when [allowLocalHttp] (debug builds, local stack).
bool isAllowedPaymentUrl(Uri uri, {required bool allowLocalHttp}) {
  if (uri.scheme == 'https') return uri.host.isNotEmpty;
  if (uri.scheme == 'http') {
    return allowLocalHttp && AppEnvironment.localDevHosts.contains(uri.host);
  }
  return uri.scheme == 'about' && uri.path == 'blank';
}

/// A navigation the web view may perform: the scheme rules above AND the
/// gateway's own host (the hand-off URL's host) or `about:blank`. Return URLs
/// are intercepted before this check and never navigated to.
bool isAllowedHandoffNavigation(
  Uri uri, {
  required PaymentHandoff handoff,
  required bool allowLocalHttp,
}) {
  if (!isAllowedPaymentUrl(uri, allowLocalHttp: allowLocalHttp)) return false;
  if (uri.scheme == 'about') return true;
  return uri.host.toLowerCase() == handoff.url.host.toLowerCase();
}

enum NavigationVerdict { returned, allow, block }

/// One decision for every web-view navigation request: a return URL ends the
/// hand-off (checked first, never loaded); main-frame navigation is pinned to
/// the gateway host; sub-frames only need to satisfy the scheme rules.
NavigationVerdict decideNavigation(
  Uri uri, {
  required bool isMainFrame,
  required PaymentHandoff handoff,
  required bool allowLocalHttp,
}) {
  if (isPaymentReturnUrl(uri)) return NavigationVerdict.returned;
  final allowed = isMainFrame
      ? isAllowedHandoffNavigation(
          uri,
          handoff: handoff,
          allowLocalHttp: allowLocalHttp,
        )
      : isAllowedPaymentUrl(uri, allowLocalHttp: allowLocalHttp);
  return allowed ? NavigationVerdict.allow : NavigationVerdict.block;
}

Uri getHandoffUri(PaymentHandoff handoff) => handoff.fields.isEmpty
    ? handoff.url
    : handoff.url.replace(
        queryParameters: {...handoff.url.queryParameters, ...handoff.fields},
      );

String formBody(Map<String, String> fields) => fields.entries
    .map(
      (e) =>
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
    )
    .join('&');
