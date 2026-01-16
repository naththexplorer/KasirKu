import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/shop_repository.dart';

part 'shop_setup_provider.g.dart';

@riverpod
Future<bool> isShopSetup(Ref ref) async {
  final repo = ref.watch(shopRepositoryProvider);
  final shop = await repo.getShop();
  return shop != null;
}
