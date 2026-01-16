import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../local/db/app_database.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(databaseProvider));
});

class CustomerRepository {
  final AppDatabase _db;
  CustomerRepository(this._db);

  Stream<List<Customer>> watchCustomers({String query = ''}) {
    final q = _db.select(_db.customers);
    if (query.isNotEmpty) {
      q.where((t) => t.name.contains(query) | t.phone.contains(query));
    }
    return (q..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
  }

  Future<int> createCustomer(CustomersCompanion customer) {
    return _db.into(_db.customers).insert(customer);
  }

  Future<bool> updateCustomer(Customer customer) async {
    return await _db.update(_db.customers).replace(customer);
  }

  Future<int> payDebt(int customerId, int amount) async {
    return _db.transaction(() async {
      final customer = await (_db.select(
        _db.customers,
      )..where((t) => t.id.equals(customerId))).getSingle();
      final newDebt = customer.totalDebt - amount;

      // Update customer debt
      await (_db.update(
        _db.customers,
      )..where((t) => t.id.equals(customerId))).write(
        CustomersCompanion(totalDebt: Value(newDebt < 0 ? 0 : newDebt)),
      );

      // Optionally Record a 'Debt Payment' transaction or log
      // For now, we just reduce the debt.
      return newDebt;
    });
  }

  Future<int> addDebt(int customerId, int amount) async {
    return _db.transaction(() async {
      final customer = await (_db.select(
        _db.customers,
      )..where((t) => t.id.equals(customerId))).getSingle();
      final newDebt = customer.totalDebt + amount;

      await (_db.update(_db.customers)..where((t) => t.id.equals(customerId)))
          .write(CustomersCompanion(totalDebt: Value(newDebt)));
      return newDebt;
    });
  }

  Future<void> deleteCustomer(int id) async {
    await (_db.delete(_db.customers)..where((c) => c.id.equals(id))).go();
  }
}
