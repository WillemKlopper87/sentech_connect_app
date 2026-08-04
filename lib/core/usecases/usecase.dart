import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';

abstract class UseCase<ReturnType, Params> {
  Future<Either<Failure, ReturnType>> call(Params params);
}

class NoParams {
  const NoParams();
}
