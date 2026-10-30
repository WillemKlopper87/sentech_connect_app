import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/privacy/presentation/widgets/legal_reading_links.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_signup.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/signup_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/plans/plan_facts.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/service_format.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/widgets/service_banner_view.dart';
import 'package:sentech_connect_app/l10n/failure_copy.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// Sign-up confirmation for one plan, then the result: the first invoice with
/// "Pay now" / "Pay later" and what happens next. Needs a [SignupCubit] above.
class SignupPage extends StatelessWidget {
  const SignupPage({
    super.key,
    required this.onPayNow,
    required this.onPayLater,
    required this.onStartIdCheck,
    required this.onBackToPlans,
  });

  /// Opens the first invoice to pay it (S2).
  final void Function(SubscriberInvoice invoice) onPayNow;

  /// Leaves for the new service (the pending banner covers the rest).
  final void Function(SubscriberService service) onPayLater;

  /// Opens the ID check (S4); null hides the button.
  final VoidCallback? onStartIdCheck;
  final VoidCallback onBackToPlans;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.signupTitle)),
      body: SafeArea(
        child: BlocBuilder<SignupCubit, SignupState>(
          builder: (context, state) {
            switch (state.phase) {
              case SignupPhase.loading:
                return const Center(child: CircularProgressIndicator());
              case SignupPhase.loadFailed:
                return FailureView(failure: state.failure, onRetry: context.read<SignupCubit>().load);
              case SignupPhase.planMissing:
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.failurePlanUnavailable, key: const Key('signup-plan-missing'), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: onBackToPlans, child: Text(l10n.planBackToPlans)),
                      ],
                    ),
                  ),
                );
              case SignupPhase.done:
                return _Done(
                  plan: state.plan!,
                  signup: state.result!,
                  onPayNow: onPayNow,
                  onPayLater: onPayLater,
                  onStartIdCheck: onStartIdCheck,
                );
              case SignupPhase.ready || SignupPhase.submitting:
                return _Form(state: state);
            }
          },
        ),
      ),
    );
  }
}

/// Customer text for a sign-up refusal (the account-closed case has its own
/// sentence; everything else goes through the shared failure copy).
String signupFailureText(BuildContext context, Failure failure) {
  final l10n = context.l10n;
  if (failure is ServiceStateFailure && failure.code == 'account_closed') return l10n.signupAccountClosed;
  if (failure is NetworkFailure) return l10n.failureYouReOfflineCheckYourConnection;
  return typedFailureText(l10n, failure) ?? localizedFailureText(l10n, failure.message);
}

class _Form extends StatefulWidget {
  const _Form({required this.state});

  final SignupState state;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final _address = TextEditingController();

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final plan = state.plan!;
    final cubit = context.read<SignupCubit>();
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final busy = state.busy;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final error = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error);
    final failure = state.failure;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(plan.name, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('${serviceKindLabel(context, plan.kind)} · ${planPriceLine(context, plan)}', style: muted),
        Text(planSpeedLine(context, plan), style: muted),
        if (plan.setupFeeCents > 0) Text(l10n.planSetupFee(formatRands(plan.setupFeeCents)), style: muted),
        const SizedBox(height: 12),
        Text(l10n.signupFirstInvoiceNote, style: theme.textTheme.bodyMedium),
        if (plan.kycRequired) ...[
          const SizedBox(height: 8),
          Text(l10n.signupIdCheckNote, style: theme.textTheme.bodyMedium),
        ],
        if (state.needsAddress) ...[
          const SizedBox(height: 16),
          TextField(
            key: const Key('signup-address'),
            controller: _address,
            enabled: !busy,
            minLines: 2,
            maxLines: 4,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.streetAddress,
            decoration: InputDecoration(
              labelText: l10n.signupAddressLabel,
              errorText: state.showErrors && !cubit.addressValid ? l10n.signupAddressRequired : null,
            ),
            onChanged: cubit.setAddress,
          ),
          Text(l10n.signupAvailabilityNote, style: muted),
        ],
        const SizedBox(height: 12),
        CheckboxListTile(
          key: const Key('signup-terms'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: state.acceptTerms,
          onChanged: busy ? null : (v) => cubit.setAcceptTerms(v ?? false),
          title: Text(l10n.signupTermsLabel, style: theme.textTheme.bodyMedium),
        ),
        if (state.showErrors && !state.acceptTerms) Text(l10n.signupTermsRequired, style: error),
        const LegalReadingLinks(),
        if (failure != null) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(signupFailureText(context, failure), key: const Key('signup-failure'), style: error)),
            ],
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('signup-submit'),
          onPressed: busy ? null : cubit.submit,
          child: busy
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Text(l10n.signupSubmitting),
                  ],
                )
              : Text(l10n.signupSubmit),
        ),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({
    required this.plan,
    required this.signup,
    required this.onPayNow,
    required this.onPayLater,
    required this.onStartIdCheck,
  });

  final SubscriberPlan plan;
  final SubscriberSignup signup;
  final void Function(SubscriberInvoice invoice) onPayNow;
  final void Function(SubscriberService service) onPayLater;
  final VoidCallback? onStartIdCheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final invoice = signup.invoice;
    final service = signup.service;
    final needsIdCheck = plan.kycRequired || service.activationBlocker == ActivationBlocker.kycRequired;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(Icons.check_circle_outline, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text(l10n.signupDoneTitle, key: const Key('signup-done'), style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(service.planName, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          l10n.signupDoneInvoice(
            invoice.invoiceNo,
            formatRands(invoice.amountCents),
            formatApiDay(context, invoice.dueDate),
          ),
          key: const Key('signup-invoice'),
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        // The platform's own account of what the service is waiting for.
        ServiceBannerView(service, showActions: false),
        if (service.kind == SubscriberPlanKind.fixedWireless) ...[
          const SizedBox(height: 10),
          Text(l10n.signupInstallationNote, key: const Key('signup-installation'), style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 20),
        FilledButton(key: const Key('signup-pay-now'), onPressed: () => onPayNow(invoice), child: Text(l10n.signupPayNow)),
        const SizedBox(height: 8),
        OutlinedButton(key: const Key('signup-pay-later'), onPressed: () => onPayLater(service), child: Text(l10n.signupPayLater)),
        if (needsIdCheck && onStartIdCheck != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(key: const Key('signup-id-check'), onPressed: onStartIdCheck, child: Text(l10n.serviceActionIdCheck)),
        ],
      ],
    );
  }
}
