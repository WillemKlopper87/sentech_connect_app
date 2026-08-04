import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong on our end.']);
}

class NotCoveredFailure extends Failure {
  const NotCoveredFailure(
      [super.message = 'This address is not yet in our coverage area.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
