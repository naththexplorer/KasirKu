import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/local/db/app_database.dart';
import '../../core/providers.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.read(databaseProvider));
});

class BackupService {
  final AppDatabase _db;

  BackupService(this._db);

  Future<void> exportData() async {
    final archive = Archive();

    // 1. Products
    final products = await _db.select(_db.products).get();
    final productCsv = const ListToCsvConverter().convert([
      ['ID', 'Name', 'Barcode', 'Price', 'Cost', 'Stock', 'Category'],
      ...products.map(
        (e) => [
          e.id,
          e.name,
          e.barcode,
          e.price,
          e.cost, // Fixed: cost instead of costPrice
          e.stock,
          e.categoryId,
        ],
      ),
    ]);
    archive.addFile(
      ArchiveFile(
        'products.csv',
        utf8.encode(productCsv).length,
        utf8.encode(productCsv),
      ),
    );

    // 2. Transactions
    final transactions = await _db.select(_db.transactions).get();
    final transactionCsv = const ListToCsvConverter().convert([
      ['ID', 'Date', 'Total', 'Payment Method', 'Tax', 'Customer ID'],
      ...transactions.map(
        (e) => [
          e.id,
          e.createdAt.toIso8601String(),
          e.totalAmount,
          e.paymentMethod,
          e.tax, // Fixed: tax instead of taxAmount
          e.customerId,
        ],
      ),
    ]);
    archive.addFile(
      ArchiveFile(
        'transactions.csv',
        utf8.encode(transactionCsv).length,
        utf8.encode(transactionCsv),
      ),
    );

    // 3. Transaction Items
    final items = await _db.select(_db.transactionItems).get();
    final itemsCsv = const ListToCsvConverter().convert([
      [
        'ID',
        'Transaction ID',
        'Product ID',
        'Name',
        'Quantity',
        'Price',
        'Cost',
      ],
      ...items.map(
        (e) => [
          e.id,
          e.transactionId,
          e.productId,
          e.productName,
          e.quantity,
          e.priceAtTime, // Fixed: priceAtTime
          e.costAtTime, // Fixed: costAtTime
        ],
      ),
    ]);
    archive.addFile(
      ArchiveFile(
        'transaction_items.csv',
        utf8.encode(itemsCsv).length,
        utf8.encode(itemsCsv),
      ),
    );

    // 4. Expenses
    final expenses = await _db.select(_db.expenses).get();
    final expenseCsv = const ListToCsvConverter().convert([
      ['ID', 'Date', 'Amount', 'Description', 'Category'],
      ...expenses.map(
        (e) => [
          e.id,
          e.date.toIso8601String(),
          e.amount,
          e.description,
          e.category,
        ],
      ),
    ]);
    archive.addFile(
      ArchiveFile(
        'expenses.csv',
        utf8.encode(expenseCsv).length,
        utf8.encode(expenseCsv),
      ),
    );

    // 5. ZIP and Share
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);

    if (zipData.isNotEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/backup_kasirku_$dateStr.zip');
      await file.writeAsBytes(zipData);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Backup Data KasirKu $dateStr');
    }
  }
}
