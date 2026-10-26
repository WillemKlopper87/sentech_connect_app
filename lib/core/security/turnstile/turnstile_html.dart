import 'package:sentech_connect_app/core/security/turnstile/turnstile_config.dart';

/// JavaScript channel the page posts to.
const turnstileChannelName = 'SentechTurnstile';

/// Cloudflare's script origin; also the only other host the WebView may open.
const turnstileScriptHost = 'challenges.cloudflare.com';

/// The page that renders the widget. Loaded with `loadHtmlString(html,
/// baseUrl: config.baseUrl)`, so the document origin is the platform's public
/// web hostname and Cloudflare reports that hostname with the token (the
/// platform checks it). Implicit retries are off (`retry: never`, no
/// auto-refresh): the app decides when to reset, so a token is only ever
/// produced for an attempt the customer is looking at.
///
/// [TurnstileConfig.siteKey] was validated to plain `[0-9A-Za-z_-]`, so it
/// needs no escaping; the action is a constant.
String buildTurnstileHtml(TurnstileConfig config) => '''<!DOCTYPE html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{margin:0;padding:0;background:transparent;display:flex;justify-content:center;align-items:center;min-height:100vh}</style>
</head><body>
<div id="w"></div>
<script>
function post(t, v) { try { $turnstileChannelName.postMessage(JSON.stringify({t: t, v: v})); } catch (e) {} }
var wid = null;
function onTurnstileLoad() {
  wid = turnstile.render('#w', {
    sitekey: '${config.siteKey}',
    action: '${config.action}',
    theme: 'auto',
    retry: 'never',
    'refresh-expired': 'never',
    'refresh-timeout': 'never',
    callback: function (token) { post('token', token); },
    'error-callback': function (code) { post('error', String(code)); return true; },
    'expired-callback': function () { post('expired', ''); },
    'timeout-callback': function () { post('timeout', ''); },
    'before-interactive-callback': function () { post('interactive', ''); }
  });
  post('ready', '');
}
function resetTurnstile() { if (wid !== null) { turnstile.reset(wid); } }
</script>
<script src="https://$turnstileScriptHost/turnstile/v0/api.js?render=explicit&onload=onTurnstileLoad" async defer></script>
</body></html>''';
