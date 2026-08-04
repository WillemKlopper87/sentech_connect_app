import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/registration_details.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/registration_cubit.dart';

class RegistrationPage extends StatelessWidget {
  const RegistrationPage({super.key, required this.onRegistered});

  final VoidCallback onRegistered;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RegistrationCubit(locator()),
      child: _RegistrationView(onRegistered: onRegistered),
    );
  }
}

class _RegistrationView extends StatefulWidget {
  const _RegistrationView({required this.onRegistered});

  final VoidCallback onRegistered;

  @override
  State<_RegistrationView> createState() => _RegistrationViewState();
}

class _RegistrationViewState extends State<_RegistrationView> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Create an account')),
      body: BlocConsumer<RegistrationCubit, RegistrationState>(
        listener: (context, state) {
          if (state.submitStatus == SubmitStatus.submitted) {
            context.read<AuthCubit>().registered(User(
                  id: 'usr_new',
                  fullName: state.fullName,
                  mobileNumber: state.mobileNumber,
                ));
            widget.onRegistered();
          }
          if (state.submitStatus == SubmitStatus.failed) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('Could not save your details — please try again.')));
          }
          if (state.locationStatus == LocationFetchStatus.fetched && _addressController.text != state.address) {
            _addressController.text = state.address;
          }
          if (state.locationStatus == LocationFetchStatus.denied) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('Location permission denied — enter your address manually.')));
          }
          if (state.locationStatus == LocationFetchStatus.failed) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('Could not get your location — check that location services are on.')));
          }
        },
        builder: (context, state) {
          final cubit = context.read<RegistrationCubit>();
          final submitting = state.submitStatus == SubmitStatus.submitting;
          final locating = state.locationStatus == LocationFetchStatus.fetching;
          final canSubmit = state.fullName.isNotEmpty &&
              state.email.isNotEmpty &&
              state.mobileNumber.isNotEmpty &&
              state.address.isNotEmpty;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('PERSONAL DETAILS', style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0.6)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    onChanged: cubit.setFullName,
                    decoration: const InputDecoration(hintText: 'Full name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailController,
                    onChanged: cubit.setEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(hintText: 'Email address'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _mobileController,
                    onChanged: cubit.setMobileNumber,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(hintText: 'Mobile number'),
                  ),
                  const SizedBox(height: 22),
                  Text('INSTALLATION ADDRESS', style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0.6)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _addressController,
                    onChanged: cubit.setAddress,
                    maxLines: 2,
                    decoration: const InputDecoration(hintText: 'Street address, suburb, city'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: locating ? null : cubit.useDeviceLocation,
                    icon: locating
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(state.hasLocation ? Icons.check_circle : Icons.my_location, size: 18),
                    label: Text(state.hasLocation ? 'Location captured' : 'Use my current location'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Narrows your coverage check to your exact location — you can still edit the address above.',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('HOW SHOULD WE CONTACT YOU?', style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0.6)),
                  const SizedBox(height: 10),
                  SegmentedButton<ContactMethod>(
                    segments: ContactMethod.values
                        .map((m) => ButtonSegment(value: m, label: Text(m.label)))
                        .toList(),
                    selected: {state.preferredContactMethod},
                    onSelectionChanged: (s) => cubit.setPreferredContactMethod(s.first),
                  ),
                  const SizedBox(height: 22),
                  Text('MARKETING PREFERENCES', style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0.6)),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: state.marketingEmail,
                    onChanged: (v) => cubit.setMarketingEmail(v ?? false),
                    title: const Text('Send me offers by email'),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: state.marketingSms,
                    onChanged: (v) => cubit.setMarketingSms(v ?? false),
                    title: const Text('Send me offers by SMS'),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: state.marketingPush,
                    onChanged: (v) => cubit.setMarketingPush(v ?? false),
                    title: const Text('Send me push notifications'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: (!canSubmit || submitting) ? null : cubit.submit,
                    child: submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Create account'),
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
