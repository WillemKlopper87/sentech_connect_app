import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_account.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_profile_edit.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_profile_repository.dart';

/// Demo flavor only: the demo account's profile changes in memory.
class MockSubscriberProfileRepository implements SubscriberProfileRepository {
  SubscriberAccount _account = MockSubscriberRepository.mockAccount;
  LoginContact _login = const LoginContact(phoneE164: '+27821234567', displayName: 'Demo Customer');

  @override
  Future<Either<Failure, SubscriberAccount>> patchProfile(SubscriberProfilePatch patch, {required String idempotencyKey}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final p = _account.profile!;
    final email = patch.clearEmail ? null : (patch.email ?? p.email);
    final phone = patch.clearPhone ? null : (patch.phoneE164 ?? p.phoneE164);
    if (email == null && phone == null) return const Left(ProfileInvalidFailure());
    return Right(
      _account = SubscriberAccount(
        id: _account.id,
        accountNo: _account.accountNo,
        kind: _account.kind,
        status: _account.status,
        serviceCounts: _account.serviceCounts,
        profile: SubscriberProfile(
          displayName: patch.displayName ?? p.displayName,
          email: email,
          phoneE164: phone,
          language: patch.language ?? p.language,
        ),
      ),
    );
  }

  @override
  Future<Either<Failure, LoginContact>> getLoginContact() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return Right(_login);
  }

  @override
  Future<Either<Failure, LoginContact>> patchLoginContact({String? displayName, String? email, bool clearEmail = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return Right(
      _login = LoginContact(
        phoneE164: _login.phoneE164,
        displayName: displayName ?? _login.displayName,
        email: clearEmail ? null : (email ?? _login.email),
      ),
    );
  }
}
