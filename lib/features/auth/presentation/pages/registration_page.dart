import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/registration_details.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/registration_cubit.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/presentation/widgets/consent_gate.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/notification_rationale_sheet.dart';

class RegistrationPage extends StatelessWidget {
  const RegistrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RegistrationCubit(
        locator(),
        consents: locator(),
        initialMobile: context.read<AuthCubit>().state.user?.mobileNumber ?? '',
      ),
      child: const _RegistrationView(),
    );
  }
}

class _RegistrationView extends StatefulWidget {
  const _RegistrationView();

  @override
  State<_RegistrationView> createState() => _RegistrationViewState();
}

class _RegistrationViewState extends State<_RegistrationView> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mobileController.text = context.read<RegistrationCubit>().state.mobileNumber;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// "Not you?": leaves the half-created account on this phone (wipes the session).
  Future<void> _signOut() async {
    try {
      await context.read<AuthCubit>().logOut();
    } catch (_) {
      // Signed out in the UI already; a storage failure has nowhere to go.
    }
  }

  /// POPIA: location is only captured after the customer has agreed to the
  /// (versioned, timestamped) location-consent notice.
  Future<void> _useLocation(RegistrationCubit cubit) async {
    if (!await ensureConsent(context, ConsentPurpose.locationCapture)) return;
    await cubit.useDeviceLocation();
  }

  /// Ticking "push notifications" explains the permission before the system
  /// prompt (Android 13+) appears.
  Future<void> _onPushToggled(RegistrationCubit cubit, bool enabled) async {
    cubit.setMarketingPush(enabled);
    if (enabled) await showNotificationRationale(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.registerCompleteProfileTitle),
        automaticallyImplyLeading: false,
        actions: [TextButton(onPressed: _signOut, child: Text(l10n.loginNotYou))],
      ),
      body: BlocConsumer<RegistrationCubit, RegistrationState>(
        listener: (context, state) {
          if (state.submitStatus == SubmitStatus.submitted) {
            // The router guard then moves the customer on (coverage for a fresh sign-in).
            final auth = context.read<AuthCubit>();
            auth.profileUpdated(User(
              id: auth.state.user?.id ?? 'usr_new',
              fullName: state.fullName.trim(),
              mobileNumber: auth.state.user?.mobileNumber ?? state.mobileNumber,
            ), legalAccepted: true);
          }
          if (state.submitStatus == SubmitStatus.failed) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(l10n.registerSaveFailed)));
          }
          if (state.locationStatus == LocationFetchStatus.fetched && _addressController.text != state.address) {
            _addressController.text = state.address;
          }
          if (state.locationStatus == LocationFetchStatus.denied) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(l10n.registerLocationDenied)));
          }
          if (state.locationStatus == LocationFetchStatus.failed) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(l10n.registerLocationFailed)));
          }
        },
        builder: (context, state) {
          final cubit = context.read<RegistrationCubit>();
          final submitting = state.submitStatus == SubmitStatus.submitting;
          final locating = state.locationStatus == LocationFetchStatus.fetching;
          final canSubmit = state.acceptedTerms &&
              state.fullName.trim().isNotEmpty &&
              state.email.isNotEmpty &&
              state.mobileNumber.isNotEmpty &&
              state.address.isNotEmpty;
          final heading = theme.textTheme.labelLarge?.copyWith(letterSpacing: 0.6);

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.registerPersonalDetails, style: heading),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    onChanged: cubit.setFullName,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(hintText: l10n.registerFullName),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailController,
                    onChanged: cubit.setEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(hintText: l10n.registerEmail),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _mobileController,
                    readOnly: true, // verified by SMS
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(hintText: l10n.registerMobile),
                  ),
                  const SizedBox(height: 22),
                  Text(l10n.registerInstallationAddress, style: heading),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _addressController,
                    onChanged: cubit.setAddress,
                    maxLines: 2,
                    decoration: InputDecoration(hintText: l10n.registerAddressHint),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: locating ? null : () => _useLocation(cubit),
                    icon: locating
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(state.hasLocation ? Icons.check_circle : Icons.my_location, size: 18),
                    label: Text(state.hasLocation ? l10n.registerLocationCaptured : l10n.registerUseLocation),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l10n.registerLocationHelp,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(l10n.registerContactHeading, style: heading),
                  const SizedBox(height: 10),
                  SegmentedButton<ContactMethod>(
                    segments: ContactMethod.values
                        .map((m) => ButtonSegment(value: m, label: Text(m.label)))
                        .toList(),
                    selected: {state.preferredContactMethod},
                    onSelectionChanged: (s) => cubit.setPreferredContactMethod(s.first),
                  ),
                  const SizedBox(height: 22),
                  Text(l10n.registerMarketingHeading, style: heading),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: state.marketingEmail,
                    onChanged: (v) => cubit.setMarketingEmail(v ?? false),
                    title: Text(l10n.registerMarketingEmail),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: state.marketingSms,
                    onChanged: (v) => cubit.setMarketingSms(v ?? false),
                    title: Text(l10n.registerMarketingSms),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: state.marketingPush,
                    onChanged: (v) => _onPushToggled(cubit, v ?? false),
                    title: Text(l10n.registerMarketingPush),
                  ),
                  const SizedBox(height: 20),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: state.acceptedTerms,
                    onChanged: (v) => cubit.setAcceptedTerms(v ?? false),
                    title: Text(l10n.registerAcceptTerms),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: (!canSubmit || submitting) ? null : cubit.submit,
                    child: submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(l10n.registerCreateAccount),
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
