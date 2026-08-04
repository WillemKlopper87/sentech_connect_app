import 'package:equatable/equatable.dart';

class WifiHotspot extends Equatable {
  const WifiHotspot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;

  @override
  List<Object?> get props => [id, name, latitude, longitude];
}
