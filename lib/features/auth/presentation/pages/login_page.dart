import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/utils/phone_number.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/otp_login_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/dot_grid_panel.dart';
import 'package:sentech_connect_app/shared/widgets/sentech_logo.dart';

/// Sign-in and sign-up in one: mobile number -> SMS code. New customers
/// complete their profile next (router rule). A locked session (cold start
/// with an enrolled biometric) can be unlocked with "Use biometrics".
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, this.demoMode = false});

  /// Shows the "any 6-digit code works" hint (demo flavor only).
  final bool demoMode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final auth = context.read<AuthCubit>();
        return OtpLoginCubit(
          locator(),
          // Verification and sign-in are ONE operation (AuthCubit.signInWithOtp). The legal consent
          // step that follows is enforced by the router for every kind of session.
          verifier: (challenge, code) => auth.signInWithOtp(challenge: challenge, code: code),
        );
      },
      child: _LoginView(demoMode: demoMode),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView({required this.demoMode});

  final bool demoMode;

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<AuthCubit>().refreshBiometrics();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
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

  String _otpMessage(Failure failure) {
    final l10n = context.l10n;
    if (failure is ValidationFailure) {
      switch (failure.code) {
        case 'invalid_phone':
          return l10n.loginPhoneInvalid;
        case 'otp_invalid' || 'invalid_code':
          return l10n.otpInvalidCode;
      }
      return failure.messageIsDetail ? failure.message : l10n.otpServerError;
    }
    return switch (failure) {
      NetworkFailure() => l10n.otpOffline,
      RateLimitedFailure() => l10n.otpRateLimited,
      SessionSetupFailure() => l10n.otpSessionSetupFailed,
      _ => l10n.otpServerError, // no raw server or client English
    };
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<AuthCubit, AuthState>(
            listenWhen: (previous, current) => previous.status != current.status,
            listener: (context, state) {
              if (state.status != AuthStatus.failure) return;
              final message = state.errorMessage ?? _biometricMessage(state.biometricIssue);
              if (message != null) _snack(message);
            },
          ),
          BlocListener<OtpLoginCubit, OtpLoginState>(
            listenWhen: (previous, current) => previous.status != current.status || previous.step != current.step,
            listener: (context, state) {
              if (state.status == OtpLoginStatus.failure && state.failure != null) _snack(_otpMessage(state.failure!));
              if (state.step == OtpStep.phone) _codeController.clear();
            },
          ),
        ],
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, auth) => BlocBuilder<OtpLoginCubit, OtpLoginState>(
            builder: (context, otp) {
              final busy = auth.status == AuthStatus.loading || otp.busy;
              final locked = otp.locked;
              final name = auth.isSignedIn ? null : auth.user?.fullName.trim();
              final firstName = (name == null || name.isEmpty) ? null : name.split(' ').first;
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
                      Text(
                        firstName == null ? l10n.loginWelcomeBack : l10n.loginWelcomeBackName(firstName),
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.loginSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      if (auth.biometricsReady) ...[
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => context.read<AuthCubit>().logInWithBiometrics(reason: l10n.biometricPromptReason),
                          icon: const Icon(Icons.fingerprint),
                          label: Text(l10n.loginUseBiometrics),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => context.read<AuthCubit>().logOut(),
                          child: Text(l10n.loginNotYou),
                        ),
                        const SizedBox(height: 8),
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
                      if (otp.step == OtpStep.phone) ..._phoneStep(context, otp, busy || locked) else ..._codeStep(context, otp, busy, locked),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneStep(BuildContext context, OtpLoginState otp, bool busy) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cubit = context.read<OtpLoginCubit>();
    return [
      TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        textInputAction: TextInputAction.send,
        onSubmitted: busy ? null : cubit.submitPhone,
        decoration: InputDecoration(hintText: l10n.loginMobileHint),
      ),
      const SizedBox(height: 8),
      Text(
        l10n.loginNewCustomerHint,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: busy ? null : () => cubit.submitPhone(_phoneController.text),
        child: otp.status == OtpLoginStatus.sending ? const _ButtonSpinner() : Text(l10n.loginSendCode),
      ),
    ];
  }

  List<Widget> _codeStep(BuildContext context, OtpLoginState otp, bool busy, bool locked) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cubit = context.read<OtpLoginCubit>();
    return [
      Text(l10n.otpSentTo(maskPhone(otp.challenge!.phoneE164)), style: theme.textTheme.bodyLarge),
      const SizedBox(height: 12),
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
        textInputAction: TextInputAction.done,
        autofocus: true,
        onSubmitted: busy || locked ? null : cubit.submitCode,
        decoration: InputDecoration(labelText: l10n.otpCodeHint),
      ),
      if (widget.demoMode) ...[
        const SizedBox(height: 6),
        Text(l10n.otpDemoHint, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: busy || locked ? null : () => cubit.submitCode(_codeController.text),
        child: otp.status == OtpLoginStatus.verifying ? const _ButtonSpinner() : Text(l10n.otpVerify),
      ),
      const SizedBox(height: 8),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: busy || otp.resendIn > 0 ? null : cubit.resend,
            child: Text(otp.resendIn > 0 ? l10n.otpResendIn(otp.resendIn) : l10n.otpResend),
          ),
          TextButton(onPressed: busy ? null : cubit.changeNumber, child: Text(l10n.otpChangeNumber)),
        ],
      ),
    ];
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
}
