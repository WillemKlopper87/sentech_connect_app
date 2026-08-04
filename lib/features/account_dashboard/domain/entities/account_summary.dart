import 'package:equatable/equatable.dart';

class AccountSummary extends Equatable {
  const AccountSummary({
    required this.planName,
    required this.renewsOn,
    required this.usedGB,
    required this.totalGB,
    required this.routerName,
    required this.macAddressSuffix,
    required this.signalBars,
  });

  final String planName;
  final String renewsOn;
  final double usedGB;
  final double totalGB;
  final String routerName;
  final String macAddressSuffix;
  final int signalBars; // 0-4

  double get usageFraction => (usedGB / totalGB).clamp(0, 1);

  @override
  List<Object?> get props =>
      [planName, renewsOn, usedGB, totalGB, routerName, macAddressSuffix, signalBars];
}
