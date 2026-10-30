import 'package:equatable/equatable.dart';

/// `ChangeOut`: what a plan change did. [applied] means the service is on the
/// new plan from [effectiveOn] (today); otherwise the change is scheduled for
/// [effectiveOn] (the first day of next month). [prorationInvoiceId] is the
/// invoice for the price difference, when one was issued.
class PlanChange extends Equatable {
  const PlanChange({required this.applied, required this.effectiveOn, this.prorationInvoiceId});

  final bool applied;
  final DateTime effectiveOn;
  final String? prorationInvoiceId;

  @override
  List<Object?> get props => [applied, effectiveOn, prorationInvoiceId];
}
