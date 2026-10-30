import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/hotspot_login/presentation/bloc/hotspot_login_cubit.dart';
import 'package:sentech_connect_app/features/hotspot_login/presentation/clipboard_auto_clear.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';
import 'package:sentech_connect_app/shared/widgets/secure_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opened to make the hotspot show its sign-in page. A plain-HTTP page that
/// never redirects to HTTPS, so the controller can intercept it. The Android
/// connectivity-check address (generate_204) is not suitable: it answers 204
/// with no content when the phone is already online and may not be
/// intercepted, and an HTTPS address cannot be intercepted at all.
const captivePortalTriggerUrl = 'http://neverssl.com';

typedef UrlOpener = Future<bool> Function(Uri uri);

Future<bool> _openExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// "Get online now". Needs a [HotspotLoginCubit] above it. The login details
/// are secrets: the screen is capture-protected, the password is masked until
/// revealed, and copies leave the clipboard after a minute.
class GetOnlinePage extends StatefulWidget {
  const GetOnlinePage({
    super.key,
    this.openUrl = _openExternal,
    this.clipboardDelay = const Duration(seconds: 60),
  });

  final UrlOpener openUrl;
  final Duration clipboardDelay;

  @override
  State<GetOnlinePage> createState() => _GetOnlinePageState();
}

class _GetOnlinePageState extends State<GetOnlinePage> {
  late final ClipboardAutoClear _clipboard = ClipboardAutoClear(
    delay: widget.clipboardDelay,
  );
  bool _reveal = false;

  @override
  void dispose() {
    _clipboard.dispose();
    super.dispose();
  }

  Future<void> _copy(String text) async {
    await _clipboard.copy(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.hotspotLoginCopied)));
  }

  Future<void> _openPortal() async {
    var opened = false;
    try {
      opened = await widget.openUrl(Uri.parse(captivePortalTriggerUrl));
    } on Object {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.hotspotLoginOpenPortalFailed)),
      );
    }
  }

  String _clock(Duration d) {
    final s = d.inSeconds < 0 ? 0 : d.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.hotspotLoginTitle)),
        body: SafeArea(
          child: BlocConsumer<HotspotLoginCubit, HotspotLoginState>(
            listener: (context, state) {
              if (state.status != HotspotLoginStatus.ready) {
                _reveal = false;
                _clipboard.dispose();
              }
            },
            builder: (context, state) {
              final cubit = context.read<HotspotLoginCubit>();
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    l10n.hotspotLoginIntro,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  switch (state.status) {
                    HotspotLoginStatus.idle => FilledButton(
                      key: const Key('hotspot-login-get'),
                      onPressed: cubit.request,
                      child: Text(l10n.hotspotLoginGetDetails),
                    ),
                    HotspotLoginStatus.requesting => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    HotspotLoginStatus.failure => FailureView(
                      key: const Key('hotspot-login-failure'),
                      failure: state.failure,
                      compact: true,
                      onRetry: cubit.request,
                    ),
                    HotspotLoginStatus.expired => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.hotspotLoginExpired,
                          key: const Key('hotspot-login-expired'),
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          key: const Key('hotspot-login-new'),
                          onPressed: cubit.request,
                          child: Text(l10n.hotspotLoginGetNew),
                        ),
                      ],
                    ),
                    HotspotLoginStatus.ready => _details(context, state, cubit),
                  },
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _details(
    BuildContext context,
    HotspotLoginState state,
    HotspotLoginCubit cubit,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final token = state.token!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Secret(
          label: l10n.hotspotLoginUsername,
          value: token.username,
          valueKey: const Key('hotspot-login-username'),
          trailing: IconButton(
            key: const Key('hotspot-login-copy-username'),
            tooltip: l10n.hotspotLoginCopyUsername,
            icon: const Icon(Icons.copy),
            onPressed: () => _copy(token.username),
          ),
        ),
        const SizedBox(height: 12),
        _Secret(
          label: l10n.hotspotLoginPassword,
          value: _reveal ? token.password : '•' * 10,
          valueKey: const Key('hotspot-login-password'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const Key('hotspot-login-reveal'),
                tooltip: _reveal
                    ? l10n.hotspotLoginHidePassword
                    : l10n.hotspotLoginShowPassword,
                icon: Icon(_reveal ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _reveal = !_reveal),
              ),
              IconButton(
                key: const Key('hotspot-login-copy-password'),
                tooltip: l10n.hotspotLoginCopyPassword,
                icon: const Icon(Icons.copy),
                onPressed: () => _copy(token.password),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.hotspotLoginValidFor(_clock(state.remaining)),
          key: const Key('hotspot-login-countdown'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(l10n.hotspotLoginUseOnce, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('hotspot-login-portal'),
          onPressed: _openPortal,
          child: Text(l10n.hotspotLoginOpenPortal),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('hotspot-login-new'),
          onPressed: cubit.request,
          child: Text(l10n.hotspotLoginGetNew),
        ),
      ],
    );
  }
}

class _Secret extends StatelessWidget {
  const _Secret({
    required this.label,
    required this.value,
    required this.valueKey,
    required this.trailing,
  });

  final String label;
  final String value;
  final Key valueKey;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                Text(
                  value,
                  key: valueKey,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
