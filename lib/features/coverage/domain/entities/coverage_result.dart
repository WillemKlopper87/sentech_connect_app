import 'package:equatable/equatable.dart';

class CoverageResult extends Equatable {
  const CoverageResult({
    required this.address,
    required this.isCovered,
    required this.estimatedSpeedMbps,
  });

  final String address;
  final bool isCovered;
  final int estimatedSpeedMbps;

  @override
  List<Object?> get props => [address, isCovered, estimatedSpeedMbps];
}
