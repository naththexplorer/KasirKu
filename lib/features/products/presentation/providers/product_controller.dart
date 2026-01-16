import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/local/db/app_database.dart';
import '../../../../data/repositories/product_repository.dart';

final productListProvider = StreamProvider.autoDispose
    .family<List<ProductWithCategory>, String>((ref, query) {
      final repo = ref.watch(productRepositoryProvider);
      return repo.watchProducts(query: query);
    });

final categoryListProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return repo.watchCategories();
});

class ProductController extends StateNotifier<AsyncValue<void>> {
  final ProductRepository _repo;

  ProductController(this._repo) : super(const AsyncValue.data(null));

  Future<bool> addProduct(ProductsCompanion product) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.createProduct(product));
    return !state.hasError;
  }

  Future<bool> editProduct(Product product) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.updateProduct(product));
    return !state.hasError;
  }

  Future<bool> deleteProduct(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.deleteProduct(id));
    return !state.hasError;
  }

  Future<bool> addCategory(String name) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.createCategory(CategoriesCompanion(name: Value(name))),
    );
    return !state.hasError;
  }
}

final productControllerProvider =
    StateNotifierProvider<ProductController, AsyncValue<void>>((ref) {
      return ProductController(ref.watch(productRepositoryProvider));
    });
