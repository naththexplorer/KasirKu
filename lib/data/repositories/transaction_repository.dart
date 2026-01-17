import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../local/db/app_database.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(databaseProvider));
});

class TransactionRepository {
  final AppDatabase _db;
  TransactionRepository(this._db);

  Future<int> createTransaction({
    required TransactionsCompanion transaction,
    required List<TransactionItemsCompanion> items,
  }) async {
    return _db.transaction(() async {
      // 1. Insert Transaction
      final transactionId = await _db
          .into(_db.transactions)
          .insert(transaction);

      // 2. Insert Items
      for (var item in items) {
        await _db
            .into(_db.transactionItems)
            .insert(item.copyWith(transactionId: Value(transactionId)));

        // 3. Update Stock
        final product = await (_db.select(
          _db.products,
        )..where((t) => t.id.equals(item.productId.value))).getSingle();
        final newStock = product.stock - item.quantity.value;
        await (_db.update(_db.products)..where((t) => t.id.equals(product.id)))
            .write(ProductsCompanion(stock: Value(newStock)));
      }

      // 4. Handle Debt (Kasbon)
      if (transaction.paymentMethod.value == 'debt' &&
          transaction.customerId.value != null) {
        final customerId = transaction.customerId.value!;
        final customer = await (_db.select(
          _db.customers,
        )..where((t) => t.id.equals(customerId))).getSingle();

        final debtIncrease = transaction.totalAmount.value;

        await (_db.update(
          _db.customers,
        )..where((t) => t.id.equals(customerId))).write(
          CustomersCompanion(
            totalDebt: Value(customer.totalDebt + debtIncrease),
          ),
        );
      }

      return transactionId;
    });
  }

  Stream<List<TransactionWithItems>> watchTransactions() {
    return _db.select(_db.transactions).watch().asyncMap((transactions) async {
      if (transactions.isEmpty) return [];

      final ids = transactions.map((t) => t.id).toList();
      final allItems = await (_db.select(
        _db.transactionItems,
      )..where((t) => t.transactionId.isIn(ids))).get();

      return transactions.map((t) {
        final relatedItems = allItems
            .where((i) => i.transactionId == t.id)
            .toList();
        return TransactionWithItems(transaction: t, items: relatedItems);
      }).toList();
    });
  }

  Future<TransactionSummary> getTransactionSummary({
    DateTime? start,
    DateTime? end,
  }) async {
    final revenueQuery = _db.selectOnly(_db.transactions);
    revenueQuery.addColumns([_db.transactions.totalAmount.sum()]);

    if (start != null) {
      revenueQuery.where(
        _db.transactions.createdAt.isBiggerOrEqualValue(start),
      );
    }
    if (end != null) {
      revenueQuery.where(_db.transactions.createdAt.isSmallerOrEqualValue(end));
    }

    final revenueResult = await revenueQuery.getSingle();
    final revenue = revenueResult.read(_db.transactions.totalAmount.sum()) ?? 0;

    final cogsQuery = _db.selectOnly(_db.transactionItems)
      ..join([
        innerJoin(
          _db.transactions,
          _db.transactions.id.equalsExp(_db.transactionItems.transactionId),
        ),
      ]);

    final costExpression =
        coalesce([_db.transactionItems.costAtTime, const Constant(0)]) *
        _db.transactionItems.quantity;

    cogsQuery.addColumns([costExpression.sum()]);

    if (start != null) {
      cogsQuery.where(_db.transactions.createdAt.isBiggerOrEqualValue(start));
    }
    if (end != null) {
      cogsQuery.where(_db.transactions.createdAt.isSmallerOrEqualValue(end));
    }

    final cogsResult = await cogsQuery.getSingle();
    final cost = cogsResult.read(costExpression.sum()) ?? 0;

    return TransactionSummary(totalRevenue: revenue, totalCost: cost);
  }

  Future<TransactionTodayStats> getTodayStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    // 1. Count Transactions
    final countQuery = _db.selectOnly(_db.transactions);
    countQuery.addColumns([_db.transactions.id.count()]);
    countQuery.where(
      _db.transactions.createdAt.isBetweenValues(todayStart, todayEnd),
    );
    countQuery.where(_db.transactions.status.equals('completed'));

    final countResult = await countQuery.getSingle();
    final count = countResult.read(_db.transactions.id.count()) ?? 0;

    // 2. Total Revenue
    final revenueQuery = _db.selectOnly(_db.transactions);
    revenueQuery.addColumns([_db.transactions.totalAmount.sum()]);
    revenueQuery.where(
      _db.transactions.createdAt.isBetweenValues(todayStart, todayEnd),
    );
    revenueQuery.where(_db.transactions.status.equals('completed'));

    final revenueResult = await revenueQuery.getSingle();
    final revenue = revenueResult.read(_db.transactions.totalAmount.sum()) ?? 0;

    return TransactionTodayStats(totalRevenue: revenue, count: count);
  }

  Stream<TransactionTodayStats> watchTodayStats() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    final query = _db.selectOnly(_db.transactions);
    query.addColumns([
      _db.transactions.id.count(),
      _db.transactions.totalAmount.sum(),
    ]);
    query.where(
      _db.transactions.createdAt.isBetweenValues(todayStart, todayEnd),
    );
    query.where(_db.transactions.status.equals('completed'));

    return query.watch().map((rows) {
      if (rows.isEmpty) {
        return TransactionTodayStats(totalRevenue: 0, count: 0);
      }
      final row = rows.first;
      final count = row.read(_db.transactions.id.count()) ?? 0;
      final revenue = row.read(_db.transactions.totalAmount.sum()) ?? 0;
      return TransactionTodayStats(totalRevenue: revenue, count: count);
    });
  }

  Future<void> deleteTransaction(int id) async {
    await _db.transaction(() async {
      // 1. Get Transaction Info
      final transaction = await (_db.select(
        _db.transactions,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (transaction == null) return;

      // 2. Get Items to restore stock
      final items = await (_db.select(
        _db.transactionItems,
      )..where((ti) => ti.transactionId.equals(id))).get();

      // 3. Restore Stock
      for (final item in items) {
        final product = await (_db.select(
          _db.products,
        )..where((p) => p.id.equals(item.productId))).getSingleOrNull();

        if (product != null) {
          final restoredStock = product.stock + item.quantity;
          await (_db.update(_db.products)
                ..where((p) => p.id.equals(product.id)))
              .write(ProductsCompanion(stock: Value(restoredStock)));
        }
      }

      // 4. Revert Debt if applicable
      if (transaction.paymentMethod == 'debt' &&
          transaction.customerId != null) {
        final customer =
            await (_db.select(_db.customers)
                  ..where((c) => c.id.equals(transaction.customerId!)))
                .getSingleOrNull();

        if (customer != null) {
          final reducedDebt = customer.totalDebt - transaction.totalAmount;
          await (_db.update(_db.customers)
                ..where((c) => c.id.equals(customer.id)))
              .write(CustomersCompanion(totalDebt: Value(reducedDebt)));
        }
      }

      // 5. Delete Records
      await (_db.delete(
        _db.transactionItems,
      )..where((ti) => ti.transactionId.equals(id))).go();
      await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
    });
  }
}

class TransactionWithItems {
  final Transaction transaction;
  final List<TransactionItem> items;

  TransactionWithItems({required this.transaction, required this.items});
}

class TransactionSummary {
  final int totalRevenue;
  final int totalCost;
  int get grossProfit => totalRevenue - totalCost;

  TransactionSummary({required this.totalRevenue, required this.totalCost});
}

class TransactionTodayStats {
  final int totalRevenue;
  final int count;

  TransactionTodayStats({required this.totalRevenue, required this.count});
}
