import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../local/db/app_database.dart';

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return StockRepository(ref.watch(databaseProvider));
});

class StockRepository {
  final AppDatabase _db;
  StockRepository(this._db);

  Stream<List<StockHistoryItem>> watchStockHistory(int productId) {
    return (_db.select(_db.stockHistory)
          ..where((t) => t.productId.equals(productId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<List<StockHistoryItem>> getStockHistory(int productId) {
    return (_db.select(_db.stockHistory)
          ..where((t) => t.productId.equals(productId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<void> adjustStock({
    required int productId,
    required int changeAmount,
    required String type, // 'adjustment', 'initial', etc.
    String? note,
  }) async {
    return _db.transaction(() async {
      // 1. Get current stock
      final product = await (_db.select(
        _db.products,
      )..where((t) => t.id.equals(productId))).getSingle();

      // 2. Update Product Stock
      final newStock = product.stock + changeAmount;
      await (_db.update(_db.products)..where((t) => t.id.equals(productId)))
          .write(ProductsCompanion(stock: Value(newStock)));

      // 3. Log History
      await _db
          .into(_db.stockHistory)
          .insert(
            StockHistoryCompanion(
              productId: Value(productId),
              changeAmount: Value(changeAmount),
              type: Value(type),
              note: Value(note),
            ),
          );
    });
  }

  Future<int> deleteStockHistory(int id) {
    return (_db.delete(_db.stockHistory)..where((t) => t.id.equals(id))).go();
  }
}
