import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/expense_repository.dart';
import '../../../../data/local/db/app_database.dart';

final expenseListProvider = StreamProvider.autoDispose<List<ExpenseItem>>((
  ref,
) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.watchExpenses();
});
