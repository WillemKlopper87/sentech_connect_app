import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/features/account_dashboard/domain/entities/account_summary.dart';
import 'package:sentech_connect_app/features/account_dashboard/domain/repositories/account_repository.dart';

class MockAccountRepository implements AccountRepository {
  MockAccountRepository([SimulatedNetwork? network]) : _network = network ?? SimulatedNetwork();

  final SimulatedNetwork _network;

  @override
  Future<Either<Failure, AccountSummary>> getSummary() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_network.failure case final failure?) return Left(failure);
    return const Right(AccountSummary(
      planName: 'Home 100',
      renewsOn: '14 Sep',
      usedGB: 62,
      totalGB: 100,
      routerName: 'Living room router',
      macAddressSuffix: '4F:2C',
      signalBars: 4,
    ));
  }
}
