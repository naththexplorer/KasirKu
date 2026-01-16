import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/customer_repository.dart';
import '../../../../data/local/db/app_database.dart';

final customerListProvider = StreamProvider.autoDispose<List<Customer>>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  return repo.watchCustomers();
});
