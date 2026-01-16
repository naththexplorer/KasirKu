import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/local/db/app_database.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../core/services/google_auth_service.dart';
import '../../../../core/services/login_guard_service.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, UserEntity?>((ref) {
      return AuthController(ref);
    });

class AuthController extends StateNotifier<UserEntity?> {
  final Ref ref;
  String? _lastErrorMessage;

  AuthController(this.ref) : super(null);

  String? get lastErrorMessage => _lastErrorMessage;

  Future<bool> login(String pin) async {
    final guard = ref.read(loginGuardProvider);
    const identifier = 'admin'; // For now, simple POS assumes one admin session

    if (guard.isLockedOut(identifier)) {
      _lastErrorMessage =
          'Terlalu banyak percobaan. Terkunci selama ${guard.getRemainingLockoutTime(identifier)}';
      return false;
    }

    final repo = ref.read(userRepositoryProvider);
    final user = await repo.getUserByPin(pin);

    if (user != null) {
      state = user;
      guard.reset(identifier);
      _lastErrorMessage = null;
      return true;
    }

    guard.recordFailure(identifier);
    _lastErrorMessage = 'PIN salah. Percobaan gagal.';
    return false;
  }

  Future<bool> loginWithGoogle() async {
    final googleAuth = ref.read(googleAuthServiceProvider);
    final account = await googleAuth.signIn();

    if (account != null) {
      final repo = ref.read(userRepositoryProvider);

      // 1. Check if user exists by email
      var user = await repo.getUserByIdentifier(account.email);

      if (user == null) {
        // 2. If no user, maybe this is a secondary sign-in or we need to register.
        // During onboarding, onboarding_controller handles creation.
        // If they sign in from elsewhere, we seek owner first.
        final owner = await repo.getOwner();
        if (owner != null) {
          state = owner;
          return true;
        }

        // Return true to indicate Google success, but UI might still need Onboarding
        return true;
      }

      state = user;
      return true;
    }
    return false;
  }

  void setUser(UserEntity? user) {
    state = user;
  }

  void logout() {
    state = null;
  }
}
