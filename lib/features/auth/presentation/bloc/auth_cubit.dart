import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/local/app_preferences.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';

enum AuthStatus { initial, loading, success, failure }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  AuthState copyWith({AuthStatus? status, User? user, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage];
}

/// The logged-in session is persisted locally (see AppPreferences) so a
/// customer isn't logged out every time the app is closed and reopened —
/// there's no backend session/token yet, so this is a device-local
/// "remember me" rather than a real auth token refresh.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository, {AuthState initial = const AuthState()}) : super(initial);

  final AuthRepository _repository;

  Future<void> logIn({required String mobileNumber, required String password}) async {
    emit(state.copyWith(status: AuthStatus.loading));
    final result = await _repository.logIn(mobileNumber: mobileNumber, password: password);
    result.match(
      (failure) => emit(state.copyWith(status: AuthStatus.failure, errorMessage: failure.message)),
      (user) => _onSignedIn(user),
    );
  }

  Future<void> logInWithBiometrics() async {
    emit(state.copyWith(status: AuthStatus.loading));
    final result = await _repository.logInWithBiometrics();
    result.match(
      (failure) => emit(state.copyWith(status: AuthStatus.failure, errorMessage: failure.message)),
      (user) => _onSignedIn(user),
    );
  }

  /// Registers a user directly as logged in — used after the registration
  /// form completes, so a new customer isn't asked to log in again with
  /// the details they just entered.
  void registered(User user) => _onSignedIn(user);

  void _onSignedIn(User user) {
    emit(state.copyWith(status: AuthStatus.success, user: user));
    AppPreferences.saveUser(user);
  }

  void logOut() {
    emit(const AuthState());
    AppPreferences.clearUser();
  }
}
