import 'package:drift/drift.dart' as drift;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/providers.dart';
import '../../../../core/providers/shop_setup_provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../../data/local/db/app_database.dart';

part 'onboarding_controller.g.dart';

@riverpod
class OnboardingController extends _$OnboardingController {
  @override
  FutureOr<void> build() {
    // idle
  }

  Future<bool> submitShop({
    required String name,
    required String address,
    required String phone,
    required String businessType,
    required int taxRate,
    required String pin,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseProvider);

      await db.transaction(() async {
        // 1. Create Shop
        await db
            .into(db.shops)
            .insert(
              ShopsCompanion(
                name: drift.Value(name),
                address: drift.Value(address),
                phone: drift.Value(phone),
                businessType: drift.Value(businessType),
                taxRate: drift.Value(taxRate),
              ),
            );

        // 2. Create Owner User
        final salt = AuthService.generateSalt();
        final hashedPin = AuthService.hashPin(pin, salt);

        final userId = await db
            .into(db.users)
            .insert(
              UsersCompanion(
                name: const drift.Value('Owner'),
                username: const drift.Value('admin'),
                pin: drift.Value(hashedPin),
                pinSalt: drift.Value(salt),
                role: const drift.Value('Owner'),
              ),
            );

        final user = await (db.select(
          db.users,
        )..where((u) => u.id.equals(userId))).getSingle();
        ref.read(authControllerProvider.notifier).setUser(user);
      });

      // Invalidate shop setup check to force router redirect
      ref.invalidate(isShopSetupProvider);
    });

    return !state.hasError;
  }

  Future<bool> loginWithGoogle() async {
    state = const AsyncValue.loading();
    final success = await ref
        .read(authControllerProvider.notifier)
        .loginWithGoogle();
    state = const AsyncValue.data(null);
    return success;
  }
}
