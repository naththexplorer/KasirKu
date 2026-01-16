import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../local/db/app_database.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(databaseProvider));
});

class ProductRepository {
  final AppDatabase _db;
  ProductRepository(this._db);

  // Categories
  Future<int> createCategory(CategoriesCompanion category) {
    return _db.into(_db.categories).insert(category);
  }

  Future<int> deleteCategory(int id) {
    return (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<Category>> watchCategories() {
    return _db.select(_db.categories).watch();
  }

  Future<List<Category>> getCategories() {
    return _db.select(_db.categories).get();
  }

  // Products
  Future<int> createProduct(ProductsCompanion product) {
    return _db.into(_db.products).insert(product);
  }

  Future<Product?> getProduct(int id) {
    return (_db.select(
      _db.products,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<bool> updateProduct(Product product) {
    return _db.update(_db.products).replace(product);
  }

  Future<int> deleteProduct(int id) {
    // Soft delete
    return (_db.update(_db.products)..where((t) => t.id.equals(id))).write(
      const ProductsCompanion(isDeleted: Value(true)),
    );
  }

  Stream<List<ProductWithCategory>> watchProducts({
    String query = '',
    int? categoryId,
  }) {
    final queryBuilder = _db.select(_db.products).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.products.categoryId),
      ),
    ]);

    // Filter not deleted
    queryBuilder.where(_db.products.isDeleted.equals(false));

    if (query.isNotEmpty) {
      queryBuilder.where(
        _db.products.name.contains(query) | _db.products.barcode.equals(query),
      );
    }

    if (categoryId != null) {
      queryBuilder.where(_db.products.categoryId.equals(categoryId));
    }

    return queryBuilder.map((row) {
      return ProductWithCategory(
        product: row.readTable(_db.products),
        category: row.readTableOrNull(_db.categories),
      );
    }).watch();
  }
}

class ProductWithCategory {
  final Product product;
  final Category? category;

  ProductWithCategory({required this.product, this.category});
}
