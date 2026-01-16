import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../local/db/app_database.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(databaseProvider));
});

class ExpenseRepository {
  final AppDatabase _db;
  ExpenseRepository(this._db);

  Future<int> addExpense(ExpensesCompanion expense) {
    return _db.into(_db.expenses).insert(expense);
  }

  Future<bool> deleteExpense(int id) async {
    final count = await (_db.delete(
      _db.expenses,
    )..where((t) => t.id.equals(id))).go();
    return count > 0;
  }

  Stream<List<ExpenseItem>> watchExpenses() {
    return (_db.select(_db.expenses)..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  // Future summary for reports
  Future<int> getTotalExpenses({DateTime? start, DateTime? end}) async {
    final query = _db.selectOnly(_db.expenses);
    query.addColumns([_db.expenses.amount.sum()]);

    if (start != null) {
      query.where(_db.expenses.date.isBiggerOrEqualValue(start));
    }
    if (end != null) {
      query.where(_db.expenses.date.isSmallerOrEqualValue(end));
    }

    final result = await query.getSingle();
    return result.read(_db.expenses.amount.sum()) ?? 0;
  }
}
