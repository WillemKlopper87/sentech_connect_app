import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/dot_grid_panel.dart';
import 'package:sentech_connect_app/shared/widgets/sentech_logo.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onRegister});

  /// Successful login needs no callback: the router's auth guard moves a
  /// signed-in user off this screen (to their intended route, if any).
  final VoidCallback onRegister;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Decides whether "Use biometrics" is offered (needs an earlier session
    // on this device plus an enrolled biometric).
    context.read<AuthCubit>().refreshBiometrics();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _biometricMessage(BiometricIssue? issue) => switch (issue) {
        null || BiometricIssue.cancelled => null,
        BiometricIssue.notEnrolled => context.l10n.biometricNotEnrolled,
        BiometricIssue.unavailable => context.l10n.biometricUnavailable,
        BiometricIssue.lockedOut => context.l10n.biometricLockedOut,
        BiometricIssue.permanentlyLockedOut => context.l10n.biometricPermanentlyLockedOut,
        BiometricIssue.failed => context.l10n.biometricFailed,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      body: BlocConsumer<AuthCubit, AuthState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == AuthStatus.failure) {
            final message = state.errorMessage ?? _biometricMessage(state.biometricIssue);
            if (message != null) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(message)));
            }
          }
        },
        builder: (context, state) {
          final loading = state.status == AuthStatus.loading;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: SentechLogo(height: 44)),
                  const SizedBox(height: 24),
                  const DotGridPanel(height: 130),
                  const SizedBox(height: 24),
                  Text(l10n.loginWelcomeBack, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    l10n.loginSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  if (state.biometricsReady) ...[
                    OutlinedButton.icon(
                      onPressed: loading
                          ? null
                          : () => context.read<AuthCubit>().logInWithBiometrics(reason: l10n.biometricPromptReason),
                      icon: const Icon(Icons.fingerprint),
                      label: Text(l10n.loginUseBiometrics),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(l10n.loginOr, style: theme.textTheme.bodyMedium),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: InputDecoration(hintText: l10n.loginMobileHint),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(hintText: l10n.loginPasswordHint),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: loading
                        ? null
                        : () => context.read<AuthCubit>().logIn(
                              mobileNumber: _mobileController.text,
                              password: _passwordController.text,
                            ),
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(l10n.loginButton),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: loading ? null : widget.onRegister,
                    child: Text(l10n.loginCreateAccount, textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
