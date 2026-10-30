import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/subscriber_profile_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/subscriber_failure_text.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// "Contact details": name, email, mobile number and message language of the
/// home internet account; for a customer without an account yet, the name and
/// email of the sign-in profile that the sign-up copies. Needs a
/// [SubscriberProfileCubit] above; [onDone] runs after a successful save.
class SubscriberProfilePage extends StatelessWidget {
  const SubscriberProfilePage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.subscriberProfileTitle)),
      body: SafeArea(
        child: BlocConsumer<SubscriberProfileCubit, ProfileState>(
          listenWhen: (a, b) => a.phase != b.phase && b.phase == ProfilePhase.saved,
          listener: (context, state) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.subscriberProfileSaved)));
            onDone();
          },
          builder: (context, state) {
            if (state.phase == ProfilePhase.loading) return const Center(child: CircularProgressIndicator());
            if (state.phase == ProfilePhase.loadFailed) {
              return FailureView(failure: state.failure, onRetry: context.read<SubscriberProfileCubit>().load);
            }
            return _Form(state: state);
          },
        ),
      ),
    );
  }
}

/// A `validation_error` has no customer text of its own: say what to do.
String _failureText(AppLocalizations l10n, Failure failure) =>
    failure is ValidationFailure && failure.code == 'validation_error'
    ? l10n.failureProfileInvalid
    : subscriberFailureText(l10n, failure);

const _languages = <String, String>{'en': 'English', 'af': 'Afrikaans', 'zu': 'isiZulu'};

class _Form extends StatefulWidget {
  const _Form({required this.state});

  final ProfileState state;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final _name = TextEditingController(text: widget.state.name);
  late final _email = TextEditingController(text: widget.state.email);
  late final _phone = TextEditingController(text: widget.state.phone);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final cubit = context.read<SubscriberProfileCubit>();
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final busy = state.busy;
    final login = state.mode == ProfileMode.login;
    final issues = state.showErrors ? cubit.issues : const <ProfileField>{};
    final failure = state.failure;
    final named = failure is ValidationFailure ? failure.fields : const <String>[];
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final error = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error);

    String? nameError() => issues.contains(ProfileField.name)
        ? (login ? l10n.subscriberProfileLoginNameInvalid : l10n.subscriberProfileNameInvalid)
        : named.contains('display_name')
        ? l10n.subscriberProfileFieldRejected
        : null;
    String? emailError() => issues.contains(ProfileField.email)
        ? l10n.subscriberProfileEmailInvalid
        : named.contains('email')
        ? l10n.subscriberProfileFieldRejected
        : null;
    String? phoneError() => issues.contains(ProfileField.phone)
        ? l10n.subscriberProfilePhoneInvalid
        : named.contains('phone_e164')
        ? l10n.subscriberProfileFieldRejected
        : null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (state.accountNo != null)
          Text(l10n.subscriberProfileAccountNo(state.accountNo!), key: const Key('profile-account-no'), style: muted),
        if (login) Text(l10n.subscriberProfileLoginNote, key: const Key('profile-login-note'), style: muted),
        const SizedBox(height: 12),
        TextField(
          key: const Key('profile-name'),
          controller: _name,
          enabled: !busy,
          maxLength: login ? 80 : 120,
          textCapitalization: TextCapitalization.words,
          keyboardType: TextInputType.name,
          decoration: InputDecoration(labelText: l10n.subscriberProfileNameLabel, errorText: nameError()),
          onChanged: cubit.setName,
        ),
        TextField(
          key: const Key('profile-email'),
          controller: _email,
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(labelText: l10n.subscriberProfileEmailLabel, errorText: emailError()),
          onChanged: cubit.setEmail,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('profile-phone'),
          controller: _phone,
          enabled: !busy && !login,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: l10n.subscriberProfilePhoneLabel, errorText: phoneError()),
          onChanged: cubit.setPhone,
        ),
        if (issues.contains(ProfileField.contact))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l10n.subscriberProfileContactRequired, key: const Key('profile-contact-required'), style: error),
          ),
        if (!login) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('profile-language'),
            initialValue: state.language,
            decoration: InputDecoration(labelText: l10n.subscriberProfileLanguageLabel),
            items: [for (final e in _languages.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: busy ? null : (v) => v == null ? null : cubit.setLanguage(v),
          ),
        ],
        if (failure != null) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_failureText(l10n, failure), key: const Key('profile-failure'), style: error),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('profile-save'),
          onPressed: busy || !cubit.hasChanges ? null : cubit.save,
          child: Text(busy ? l10n.subscriberProfileSaving : l10n.subscriberProfileSave),
        ),
      ],
    );
  }
}
