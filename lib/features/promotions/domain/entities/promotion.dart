import 'package:equatable/equatable.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';

class Promotion extends Equatable {
  const Promotion({
    required this.id,
    required this.title,
    required this.description,
    required this.badge,
    this.expiresAt,
    this.appliesTo,
    this.isDemoCopy = false,
  });

  final bool isDemoCopy;
  final String id;
  final String title;
  final String description;
  final String badge; // e.g. "20% OFF", "LOYALTY"
  /// Null means ongoing. Comparisons use instants, regardless of timezone.
  final DateTime? expiresAt;

  /// Null means the offer is independent of product inventory.
  final ProductCategory? appliesTo;

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    badge,
    expiresAt,
    appliesTo,
    isDemoCopy,
  ];
}
