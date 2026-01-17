import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../local/db/app_database.dart';

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ShopRepository(db);
});

class ShopRepository {
  final AppDatabase _db;
  ShopRepository(this._db);

  Future<Shop?> getShop() async {
    return await (_db.select(_db.shops)..limit(1)).getSingleOrNull();
  }

  Future<int> createShop(ShopsCompanion shop) async {
    return await _db.into(_db.shops).insert(shop);
  }

  Future<void> updateShop(ShopsCompanion shop) async {
    await (_db.update(_db.shops)..where((s) => s.id.equals(1))).write(shop);
  }

  Future<void> updateDefaultPaymentMethod(String method) async {
    await (_db.update(_db.shops)..where((s) => s.id.equals(1))).write(
      ShopsCompanion(defaultPaymentMethod: Value(method)),
    );
  }

  Future<void> updateQrisImagePath(String? path) async {
    await (_db.update(_db.shops)..where((s) => s.id.equals(1))).write(
      ShopsCompanion(qrisImagePath: Value(path)),
    );
  }
}
