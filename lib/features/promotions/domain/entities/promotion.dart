import 'package:equatable/equatable.dart';

class Promotion extends Equatable {
  const Promotion({
    required this.id,
    required this.title,
    required this.description,
    required this.badge,
    required this.expiresOn,
  });

  final String id;
  final String title;
  final String description;
  final String badge; // e.g. "20% OFF", "LOYALTY"
  final String expiresOn;

  @override
  List<Object?> get props => [id, title, description, badge, expiresOn];
}
