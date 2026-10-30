import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/core/security/human_check_config.dart';
import 'package:sentech_connect_app/core/security/human_check_provider.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_config.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_provider.dart';

/// Decides, per request, whether a human check runs and with which Turnstile
/// settings. Precedence: **the API wins**. The settings come from
/// `GET /v1/auth/human-check/config` for the current provider (cached for
/// [ttl], the server's own `max-age=60`); only when that route fails (or
/// answers values the app cannot use) do the `--dart-define` build values
/// ([buildConfig]) apply. Nothing is fetched at app start: the first check
/// asks, so start-up never waits on it.
///
///  * route OK, `required.<action>` false: no check, no token;
///  * route OK, `site_key` null (fake verifier, dev stack): no widget, no token;
///  * route OK, otherwise: the WebView with the API's site key and base URL;
///  * route failed: the build defines if present, else no token (dev/test).
class HumanCheckGate {
  HumanCheckGate({
    required this._repository,
    required this._tenant,
    required HumanCheckPresenter presenter,
    this.buildConfig,
    this.ttl = const Duration(seconds: 60),
    this.failureTtl = const Duration(seconds: 15),
    DateTime Function()? now,
    bool? isDebug,
    HumanCheckProvider Function(TurnstileConfig config)? providerFactory,
  }) : _now = now ?? DateTime.now,
       _isDebug = isDebug ?? kDebugMode,
       _providerFactory = providerFactory ?? ((config) => TurnstileWebViewProvider(config: config, presenter: presenter));

  final TurnstileConfig? buildConfig;
  final Duration ttl;
  final Duration failureTtl;
  final HumanCheckConfigRepository _repository;
  final TenantContext _tenant;
  final DateTime Function() _now;
  final bool _isDebug;
  final HumanCheckProvider Function(TurnstileConfig) _providerFactory;

  final _cache = <String, _Entry>{};
  final _inflight = <String, Future<HumanCheckConfig?>>{};
  final _providers = <TurnstileConfig, HumanCheckProvider>{};

  /// The provider a repository uses for [action]; every `token()` call
  /// re-reads the (cached) settings.
  HumanCheckProvider forAction(HumanCheckAction action) => _ActionProvider(this, action);

  Future<HumanCheckConfig?> _settings() {
    final slug = _tenant.slug;
    final hit = _cache[slug];
    if (hit != null && _now().isBefore(hit.expires)) return Future.value(hit.config);
    return _inflight[slug] ??= () async {
      HumanCheckConfig? config;
      try {
        final result = await _repository.fetch(slug);
        config = result.match((_) => null, (c) => c);
      } on Object {
        config = null;
      }
      _cache[slug] = _Entry(config, _now().add(config == null ? failureTtl : ttl));
      return config;
    }().whenComplete(() {
      _inflight.remove(slug); // a block body: returning the removed future would make it wait on itself
    });
  }

  Future<String?> _token(HumanCheckAction action) async {
    final api = await _settings();
    TurnstileConfig? config;
    if (api != null) {
      if (!api.requires(action)) return null;
      final key = api.siteKey;
      final base = api.baseUrl;
      if (key == null || base == null) return null; // no widget on this deployment
      try {
        config = TurnstileConfig.resolve(siteKey: key, baseUrl: base, isDebug: _isDebug);
      } on InvalidTurnstileConfig {
        config = buildConfig; // the API's values are unusable here: the build's apply
      }
    } else {
      config = buildConfig;
    }
    if (config == null) return null;
    final scoped = config.withAction(action.widgetAction);
    return (_providers[scoped] ??= _providerFactory(scoped)).token();
  }
}

class _ActionProvider implements HumanCheckProvider {
  _ActionProvider(this._gate, this._action);

  final HumanCheckGate _gate;
  final HumanCheckAction _action;

  @override
  Future<String?> token() => _gate._token(_action);
}

class _Entry {
  _Entry(this.config, this.expires);
  final HumanCheckConfig? config;
  final DateTime expires;
}
