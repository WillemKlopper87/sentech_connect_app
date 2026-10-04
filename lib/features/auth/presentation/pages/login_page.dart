import 'package:flutter/material.dart';
import 'package:sentech_connect_app/l10n/failure_copy.dart';
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
import 'package:sentech_connect_app/shared/widgets/language_chip.dart';

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
          verifier: (challenge, code) =>
              auth.signInWithOtp(challenge: challenge, code: code),
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

  bool _invalidCodeInput = false;
  int _challengeRevision = 0;

  String? _normalizedCode(String text) {
    // Accept code formatting, never extract a prefix from a message/phone.
    if (!RegExp(r'^[0-9\s-]+$').hasMatch(text)) return null;
    final digits = text.replaceAll(RegExp(r'[\s-]'), '');
    return RegExp(r'^[0-9]{6}$').hasMatch(digits) ? digits : null;
  }

  void _codeChanged(String input) {
    final cubit = context.read<OtpLoginCubit>();
    if (cubit.state.busy ||
        cubit.state.locked ||
        cubit.state.status == OtpLoginStatus.verified) {
      return;
    }
    final normalized = _normalizedCode(input);
    final invalid =
        input.isNotEmpty &&
        (input.replaceAll(RegExp(r'[\s-]'), '').length > 6 ||
            !RegExp(r'^[0-9\s-]+$').hasMatch(input));
    setState(() => _invalidCodeInput = invalid);
    if (normalized != null) {
      if (input != normalized) {
        _codeController.value = TextEditingValue(
          text: normalized,
          selection: TextSelection.collapsed(offset: normalized.length),
        );
      }
      cubit.submitCode(normalized);
    }
  }

  void _submitCode(String input) {
    final cubit = context.read<OtpLoginCubit>();
    if (cubit.state.busy ||
        cubit.state.locked ||
        cubit.state.status == OtpLoginStatus.verified) {
      return;
    }
    final normalized = _normalizedCode(input);
    if (normalized == null) {
      setState(() => _invalidCodeInput = true);
      return;
    }
    setState(() => _invalidCodeInput = false);
    cubit.submitCode(normalized);
  }

  Future<void> _pasteCode() async {
    final cubit = context.read<OtpLoginCubit>();
    final challenge = cubit.state.challenge;
    final revision = _challengeRevision;
    if (challenge == null ||
        cubit.state.busy ||
        cubit.state.locked ||
        cubit.state.status == OtpLoginStatus.verified) {
      return;
    }
    ClipboardData? data;
    try {
      data = await Clipboard.getData('text/plain');
    } catch (_) {
      // Clipboard access may fail; show the same local guidance below.
    }
    if (!mounted ||
        cubit.isClosed ||
        revision != _challengeRevision ||
        cubit.state.step != OtpStep.code ||
        !identical(challenge, cubit.state.challenge) ||
        cubit.state.busy ||
        cubit.state.locked ||
        cubit.state.status == OtpLoginStatus.verified) {
      return;
    }
    final normalized = _normalizedCode(data?.text ?? '');
    if (normalized == null) {
      setState(() => _invalidCodeInput = true);
      return;
    }
    _codeController.text = normalized;
    _submitCode(normalized);
  }

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
    BiometricIssue.permanentlyLockedOut =>
      context.l10n.biometricPermanentlyLockedOut,
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
            listenWhen: (previous, current) =>
                !previous.providerUnavailable && current.providerUnavailable,
            listener: (context, state) =>
                _snack(l10n.signedOutProviderUnavailable),
          ),
          BlocListener<AuthCubit, AuthState>(
            listenWhen: (previous, current) =>
                previous.status != current.status,
            listener: (context, state) {
              if (state.status != AuthStatus.failure) return;
              final message = state.errorMessage == null
                  ? _biometricMessage(state.biometricIssue)
                  : localizedFailureText(l10n, state.errorMessage!);
              if (message != null) _snack(message);
            },
          ),
          BlocListener<OtpLoginCubit, OtpLoginState>(
            listener: (context, state) {
              // A send/verify invalidates clipboard reads begun earlier, even
              // when a resend returns the same challenge id.
              if (state.busy ||
                  state.status == OtpLoginStatus.verified ||
                  state.step == OtpStep.phone) {
                _challengeRevision++;
              }
              if (state.step == OtpStep.phone ||
                  state.status == OtpLoginStatus.sending) {
                _codeController.clear();
                _invalidCodeInput = false;
              }
            },
          ),
        ],
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, auth) => BlocBuilder<OtpLoginCubit, OtpLoginState>(
            builder: (context, otp) {
              final busy = auth.status == AuthStatus.loading || otp.busy;
              final locked = otp.locked;
              final name = auth.isSignedIn ? null : auth.user?.fullName.trim();
              final firstName = (name == null || name.isEmpty)
                  ? null
                  : name.split(' ').first;
              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerRight,
                        child: LanguageChip(),
                      ),
                      const SizedBox(height: 8),
                      const Center(child: SentechLogo(height: 44)),
                      const SizedBox(height: 24),
                      const DotGridPanel(height: 96),
                      const SizedBox(height: 24),
                      Text(
                        firstName == null
                            ? l10n.loginTitleNew
                            : l10n.loginWelcomeBackName(firstName),
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.loginEnterPhone,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (auth.biometricsReady) ...[
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => context
                                    .read<AuthCubit>()
                                    .logInWithBiometrics(
                                      reason: l10n.biometricPromptReason,
                                    ),
                          icon: const Icon(Icons.fingerprint),
                          label: Text(l10n.loginUseBiometrics),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => context.read<AuthCubit>().logOut(),
                          child: Text(l10n.loginNotYou),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                l10n.loginOr,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (otp.step == OtpStep.phone)
                        ..._phoneStep(context, otp, busy || locked)
                      else
                        ..._codeStep(context, otp, busy, locked),
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
        decoration: InputDecoration(
          hintText: l10n.loginMobileHint,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: theme.colorScheme.outline),
          ),
          errorText: otp.failure == null ? null : _otpMessage(otp.failure!),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        l10n.loginNewCustomerHint,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: busy ? null : () => cubit.submitPhone(_phoneController.text),
        child: otp.status == OtpLoginStatus.sending
            ? const _ButtonSpinner()
            : Text(l10n.loginSendCode),
      ),
    ];
  }

  List<Widget> _codeStep(
    BuildContext context,
    OtpLoginState otp,
    bool busy,
    bool locked,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cubit = context.read<OtpLoginCubit>();
    return [
      Text(
        l10n.otpSentTo(maskPhone(otp.challenge!.phoneE164)),
        style: theme.textTheme.bodyLarge,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        maxLength: 6,
        // Keep overlong/ambiguous paste intact so it can be rejected visibly.
        maxLengthEnforcement: MaxLengthEnforcement.none,
        onChanged: _codeChanged,
        textInputAction: TextInputAction.done,
        autofocus: true,
        onSubmitted: busy || locked ? null : _submitCode,
        decoration: InputDecoration(
          labelText: l10n.otpCodeHint,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: theme.colorScheme.outline),
          ),
          errorText: _invalidCodeInput
              ? l10n.otpPasteOnlyCode
              : (otp.failure == null ? null : _otpMessage(otp.failure!)),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: busy || locked || otp.status == OtpLoginStatus.verified
              ? null
              : _pasteCode,
          icon: const Icon(Icons.content_paste),
          label: Text(l10n.otpPasteCode),
        ),
      ),
      if (widget.demoMode) ...[
        const SizedBox(height: 6),
        Text(
          l10n.otpDemoHint,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: busy || locked || otp.status == OtpLoginStatus.verified
            ? null
            : () => _submitCode(_codeController.text),
        child: otp.status == OtpLoginStatus.verifying
            ? const _ButtonSpinner()
            : Text(l10n.otpVerify),
      ),
      const SizedBox(height: 8),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: busy || otp.resendIn > 0 ? null : cubit.resend,
            child: Text(
              otp.resendIn > 0
                  ? l10n.otpResendIn(otp.resendIn)
                  : l10n.otpResend,
            ),
          ),
          TextButton(
            onPressed: busy ? null : cubit.changeNumber,
            child: Text(l10n.otpChangeNumber),
          ),
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
