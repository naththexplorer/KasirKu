import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/services/auth_service.dart';
import '../local/db/app_database.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(databaseProvider));
});

class UserRepository {
  final AppDatabase _db;
  UserRepository(this._db);

  Future<int> createUser(UsersCompanion user) {
    return _db.into(_db.users).insert(user);
  }

  /// Proper fetch by identifier then verify credential
  Future<UserEntity?> getUserByPin(String pin) async {
    // For now, since it's a simple POS, we might only have one owner
    // or we fetch all and check.
    // BUT to be "proper", let's assume we fetch the owner first
    final users = await _db.select(_db.users).get();

    for (final user in users) {
      if (user.pinSalt != null) {
        if (AuthService.verifyPin(pin, user.pin, user.pinSalt!)) {
          return user;
        }
      } else {
        // Fallback for old plaintext pins (during migration)
        if (user.pin == pin) return user;
      }
    }
    return null;
  }

  Future<UserEntity?> getUserByIdentifier(String identifier) {
    return (_db.select(_db.users)..where(
          (t) => t.username.equals(identifier) | t.email.equals(identifier),
        ))
        .getSingleOrNull();
  }

  Future<UserEntity?> getOwner() {
    return (_db.select(_db.users)
          ..where((t) => t.role.equals('Owner'))
          ..limit(1))
        .getSingleOrNull();
  }
}
