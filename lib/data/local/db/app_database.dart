import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// Tables

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get price =>
      integer()(); // Storing as integer (e.g. Rp 10.000 -> 10000)
  IntColumn get cost => integer().nullable()();
  IntColumn get stock => integer().withDefault(const Constant(0))();
  TextColumn get barcode => text().nullable()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  TextColumn get imagePath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNumber => text().unique()(); // e.g., INV-20231027-001
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get subtotal => integer()();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  IntColumn get tax => integer().withDefault(const Constant(0))();
  IntColumn get totalAmount => integer()();
  TextColumn get paymentMethod => text()(); // 'cash', 'qris', 'debt'
  IntColumn get cashReceived => integer().nullable()();
  IntColumn get changeAmount => integer().nullable()();
  TextColumn get status => text()(); // 'pending', 'completed', 'void'
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
}

class TransactionItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().references(Transactions, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get productName => text()(); // Snapshot of name at time of sale
  IntColumn get quantity => integer()();
  IntColumn get priceAtTime => integer()();
  IntColumn get costAtTime => integer().nullable()();
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  IntColumn get totalDebt => integer().withDefault(const Constant(0))();
}

class Shops extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get logoPath => text().nullable()();
  TextColumn get businessType => text().withDefault(const Constant('Retail'))();
  IntColumn get taxRate => integer().withDefault(const Constant(0))();
  TextColumn get defaultPaymentMethod =>
      text().withDefault(const Constant('cash'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('UserEntity')
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text().unique().nullable()(); // Added in v6
  TextColumn get email => text().unique().nullable()(); // Added in v6
  TextColumn get name => text()();
  TextColumn get pin => text()(); // Will store HASH
  TextColumn get pinSalt => text().nullable()(); // Added in v6
  TextColumn get role => text()(); // 'Owner', 'Kasir'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// New Tables for Phase 4

@DataClassName('StockHistoryItem')
class StockHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get changeAmount => integer()(); // + for in, - for out
  TextColumn get type =>
      text()(); // 'transaction', 'adjustment', 'initial', 'edit'
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('ExpenseItem')
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text()();
  IntColumn get amount => integer()();
  TextColumn get category => text()(); // 'Operasional', 'Gaji', 'Lainnya'
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(
  tables: [
    Products,
    Categories,
    Transactions,
    TransactionItems,
    Customers,
    Shops,
    Users,
    StockHistory,
    Expenses,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(stockHistory);
        await m.createTable(expenses);
      }
      if (from < 4) {
        // Add new columns added in version 3 & 4
        // Use try-catch to ignore errors if columns already exist
        try {
          await m.addColumn(products, products.imagePath);
        } catch (_) {}
        try {
          await m.addColumn(transactions, transactions.status);
        } catch (_) {}
        try {
          await m.addColumn(shops, shops.businessType);
        } catch (_) {}
        try {
          await m.addColumn(shops, shops.taxRate);
        } catch (_) {}
        try {
          await m.addColumn(shops, shops.defaultPaymentMethod);
        } catch (_) {}
      }
      if (from < 6) {
        // Migration to add pinSalt, username, email
        await m.addColumn(users, users.pinSalt);
        await m.addColumn(users, users.username);
        await m.addColumn(users, users.email);
        // Note: In a real production app with existing users,
        // we would need a strategy to upgrade plaintext pins to hashes.
        // For this local app, we'll assume a fresh setup or re-onboarding
        // is acceptable, or we'll handle the 'null salt' as 'needs update' in repo.
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'kasirku.sqlite'));
    final oldFile = File(p.join(dbFolder.path, 'kasir_offline.sqlite'));

    // Migration: If old database exists, move it to the new name
    if (await oldFile.exists() && !(await file.exists())) {
      await oldFile.rename(file.path);
    }

    return NativeDatabase.createInBackground(file);
  });
}
