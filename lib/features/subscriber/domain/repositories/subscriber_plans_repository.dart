import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';

abstract class SubscriberPlansRepository {
  /// Every active plan of the tenant (all pages), in the order the API sends.
  Future<Either<Failure, List<SubscriberPlan>>> list();
}
