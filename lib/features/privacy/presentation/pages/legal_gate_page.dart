import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/privacy/presentation/widgets/legal_reading_links.dart';
import 'package:sentech_connect_app/shared/widgets/language_chip.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// The consent step every signed-in session passes before the app opens:
/// the CURRENT terms and privacy notice must be accepted, whether the session
/// began with an SMS code, a biometric unlock or a restore at launch. The
/// router keeps the customer here until `AuthState.legal` is accepted.
///
/// A check or recording that fails (offline, server) is shown as such with a
/// retry; it is never treated as a decline, and never as consent.
class LegalGatePage extends StatefulWidget {
  const LegalGatePage({super.key});

  @override
  State<LegalGatePage> createState() => _LegalGatePageState();
}

class _LegalGatePageState extends State<LegalGatePage> {
  bool _working = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthCubit>();
    if (auth.state.legal == LegalStatus.unchecked) auth.checkLegal();
  }

  Future<void> _accept() async {
    setState(() => _working = true);
    try {
      await context.read<AuthCubit>().acceptLegal();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await context.read<AuthCubit>().logOut();
    } catch (_) {
      // Signed out in the UI already; a storage failure has nowhere to go.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.legalGateTitle),
        automaticallyImplyLeading: false,
        actions: const [LanguageChip()],
      ),
      body: SafeArea(
        child: BlocBuilder<AuthCubit, AuthState>(
          buildWhen: (a, b) => a.legal != b.legal,
          builder: (context, auth) {
            final checking = auth.legal == LegalStatus.unchecked && !_working;
            final unavailable = auth.legal == LegalStatus.unavailable;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (checking) ...[
                  const SizedBox(height: 48),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                  Center(child: Text(l10n.legalGateChecking)),
                ] else ...[
                  if (!unavailable)
                    LegalLanguageNote(
                      body: l10n.consentLegalBody,
                      englishBody: lookupAppLocalizations(
                        const Locale('en'),
                      ).consentLegalBody,
                    ),
                  Text(
                    unavailable
                        ? l10n.legalGateUnavailable
                        : l10n.consentLegalBody,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  const LegalReadingLinks(),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _working
                        ? null
                        : (unavailable
                              ? () => context.read<AuthCubit>().checkLegal()
                              : _accept),
                    child: _working
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            unavailable ? l10n.commonRetry : l10n.consentAgree,
                          ),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _working ? null : _signOut,
                  child: Text(l10n.legalGateSignOut),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
