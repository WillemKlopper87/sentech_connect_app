import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentech_connect_app/features/privacy/presentation/widgets/legal_reading_links.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/kyc/id_image_picker.dart';
import 'package:sentech_connect_app/features/subscriber/domain/kyc/kyc_validators.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/kyc/id_number_formatter.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/kyc/kyc_form_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/kyc/kyc_labels.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';
import 'package:sentech_connect_app/shared/widgets/secure_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// The ID check form: ID type and number, address, one photo of the ID
/// document, consent. Needs a [KycFormCubit] above it. Everything typed lives
/// in that cubit only (not saved, not restored) and the screen is
/// capture-protected (FLAG_SECURE). [onDone] closes the form after a
/// successful send.
class KycFormPage extends StatelessWidget {
  const KycFormPage({super.key, required this.onDone, this.openSettings, this.openPrivacy});

  final VoidCallback onDone;

  /// Opens the system settings for this app. Defaults to `permission_handler`.
  final Future<void> Function()? openSettings;

  /// Opens the privacy notice. Defaults to the tenant's configured policy URL.
  final Future<void> Function(BuildContext context)? openPrivacy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.kycTitle)),
        body: SafeArea(
          child: BlocBuilder<KycFormCubit, KycFormState>(
            buildWhen: (a, b) => (a.phase == KycFormPhase.submitted) != (b.phase == KycFormPhase.submitted),
            builder: (context, state) => state.phase == KycFormPhase.submitted
                ? _Success(onDone: onDone)
                : _Form(openSettings: openSettings ?? () async => openAppSettings(), openPrivacy: openPrivacy),
          ),
        ),
      ),
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.check_circle_outline, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(l10n.kycSuccessTitle, key: const Key('kyc-success'), textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(l10n.kycSuccessBody, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(key: const Key('kyc-success-done'), onPressed: onDone, child: Text(l10n.kycSuccessDone)),
        ],
      ),
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({required this.openSettings, required this.openPrivacy});

  final Future<void> Function() openSettings;
  final Future<void> Function(BuildContext context)? openPrivacy;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final TextEditingController _idNumber;
  late final TextEditingController _address;

  @override
  void initState() {
    super.initState();
    final state = context.read<KycFormCubit>().state;
    _idNumber = TextEditingController(text: state.idNumber);
    _address = TextEditingController(text: state.address);
  }

  @override
  void dispose() {
    _idNumber.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _defaultOpenPrivacy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.legalLinkOpenFailed;
    var opened = false;
    try {
      opened = await launchUrl(privacyReadingUrl(context), mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cubit = context.read<KycFormCubit>();
    return BlocBuilder<KycFormCubit, KycFormState>(
      builder: (context, state) {
        final busy = state.busy;
        final showIdError = state.showErrors && !cubit.idNumberValid;
        final showAddressError = state.showErrors && !cubit.addressValid;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(l10n.kycFormIntro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            DropdownMenu<KycIdType>(
              key: const Key('kyc-id-type'),
              expandedInsets: EdgeInsets.zero,
              label: Text(l10n.kycFieldIdType),
              initialSelection: state.idType,
              enabled: !busy,
              requestFocusOnTap: false,
              dropdownMenuEntries: [
                for (final type in KycIdType.values) DropdownMenuEntry(value: type, label: kycIdTypeLabel(l10n, type)),
              ],
              onSelected: (type) {
                if (type == null) return;
                _idNumber.clear();
                cubit.setIdType(type);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('kyc-id-number'),
              controller: _idNumber,
              enabled: !busy,
              keyboardType: state.idType == KycIdType.passport ? TextInputType.visiblePassword : TextInputType.number,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              inputFormatters: [IdNumberFormatter(state.idType)],
              decoration: InputDecoration(
                labelText: kycIdTypeLabel(l10n, state.idType),
                helperText: kycIdNumberHint(l10n, state.idType),
                errorText: showIdError ? l10n.failureKycInvalidId : null,
              ),
              onChanged: cubit.setIdNumber,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('kyc-address'),
              controller: _address,
              enabled: !busy,
              minLines: 2,
              maxLines: 4,
              keyboardType: TextInputType.streetAddress,
              autocorrect: false,
              enableIMEPersonalizedLearning: false,
              inputFormatters: [
                FilteringTextInputFormatter.deny(KycValidators.forbidden),
                LengthLimitingTextInputFormatter(KycValidators.maxAddressLength),
              ],
              decoration: InputDecoration(
                labelText: l10n.kycFieldAddress,
                helperText: l10n.kycFieldAddressHint,
                errorText: showAddressError ? l10n.failureKycInvalidAddress : null,
              ),
              onChanged: cubit.setAddress,
            ),
            const SizedBox(height: 24),
            Text(l10n.kycPhotoTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l10n.kycPhotoHelp, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            _PhotoSection(openSettings: widget.openSettings),
            const SizedBox(height: 16),
            CheckboxListTile(
              key: const Key('kyc-consent'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: state.consent,
              onChanged: busy ? null : (v) => cubit.setConsent(v ?? false),
              title: Text(l10n.kycConsentLabel, style: theme.textTheme.bodyMedium),
            ),
            if (state.showErrors && !state.consent)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l10n.kycConsentRequired, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => (widget.openPrivacy ?? _defaultOpenPrivacy)(context),
                child: Text(l10n.kycPrivacyLink),
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.kycSendNote, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            if (state.failure != null) ...[
              FailureView(key: const Key('kyc-failure'), failure: state.failure, onRetry: cubit.submit, compact: true),
              const SizedBox(height: 12),
            ],
            FilledButton(
              key: const Key('kyc-submit'),
              onPressed: busy ? null : cubit.submit,
              child: Text(state.phase == KycFormPhase.submitting ? l10n.kycSubmitting : l10n.kycSubmit),
            ),
          ],
        );
      },
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({required this.openSettings});

  final Future<void> Function() openSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cubit = context.read<KycFormCubit>();
    return BlocBuilder<KycFormCubit, KycFormState>(
      buildWhen: (a, b) =>
          a.photo != b.photo ||
          a.phase != b.phase ||
          a.photoIssue != b.photoIssue ||
          a.showErrors != b.showErrors,
      builder: (context, state) {
        final photo = state.photo;
        final preparing = state.phase == KycFormPhase.preparingPhoto;
        final busy = state.busy;
        final issue = switch (state.photoIssue) {
          KycPhotoIssue.permissionDenied => l10n.kycPhotoDenied,
          KycPhotoIssue.unreadable => l10n.kycPhotoUnreadable,
          KycPhotoIssue.tooLarge => l10n.kycPhotoTooLarge,
          KycPhotoIssue.failed => l10n.kycPhotoFailed,
          null => state.showErrors && photo == null ? l10n.kycPhotoRequired : null,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  photo.jpeg,
                  key: const Key('kyc-photo-preview'),
                  height: 200,
                  fit: BoxFit.cover,
                  semanticLabel: l10n.kycPhotoPreview,
                  gaplessPlayback: true,
                ),
              ),
            if (preparing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Text(l10n.kycPhotoPreparing, key: const Key('kyc-photo-preparing')),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('kyc-take-photo'),
                  onPressed: busy ? null : () => cubit.pickPhoto(IdImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(photo == null ? l10n.kycTakePhoto : l10n.kycReplacePhoto),
                ),
                OutlinedButton.icon(
                  key: const Key('kyc-choose-photo'),
                  onPressed: busy ? null : () => cubit.pickPhoto(IdImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(l10n.kycChoosePhoto),
                ),
                if (photo != null)
                  TextButton(
                    key: const Key('kyc-remove-photo'),
                    onPressed: busy ? null : cubit.removePhoto,
                    child: Text(l10n.kycRemovePhoto),
                  ),
              ],
            ),
            if (issue != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  issue,
                  key: const Key('kyc-photo-issue'),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            if (state.photoIssue == KycPhotoIssue.permissionDenied)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const Key('kyc-open-settings'),
                  onPressed: openSettings,
                  child: Text(l10n.kycOpenSettings),
                ),
              ),
          ],
        );
      },
    );
  }
}
