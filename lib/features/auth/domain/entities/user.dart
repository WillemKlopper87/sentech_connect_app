import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({required this.id, required this.fullName, required this.mobileNumber});

  final String id;
  final String fullName;
  final String mobileNumber;

  @override
  List<Object?> get props => [id, fullName, mobileNumber];
}
