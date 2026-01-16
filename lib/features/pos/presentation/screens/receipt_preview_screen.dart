import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../../data/local/db/app_database.dart';
import '../../../../data/repositories/shop_repository.dart';
import '../../../../data/repositories/transaction_repository.dart';
import '../../../../core/providers.dart';
import '../../../../core/services/receipt_service.dart';

class ReceiptPreviewScreen extends ConsumerWidget {
  final int transactionId;

  const ReceiptPreviewScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Struk Pembayaran')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadData(ref),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('Gagal memuat data struk'));
          }

          final shop = snapshot.data!['shop'] as Shop;
          final txWithItems = snapshot.data!['tx'] as TransactionWithItems;

          return PdfPreview(
            build: (format) => ReceiptService.generateReceiptPdf(
              shop: shop,
              transaction: txWithItems.transaction,
              items: txWithItems.items,
            ),
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canChangeOrientation: false, // Fix landscape error
            canDebug: false,
            initialPageFormat: PdfPageFormat.roll80,
            pdfFileName: 'struk-${txWithItems.transaction.invoiceNumber}.pdf',
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _loadData(WidgetRef ref) async {
    final shop = await ref.read(shopRepositoryProvider).getShop();
    final tx = await _getTransactionData(ref, transactionId);
    return {'shop': shop, 'tx': tx};
  }

  Future<TransactionWithItems?> _getTransactionData(
    WidgetRef ref,
    int id,
  ) async {
    final db = ref.read(databaseProvider);
    final transaction = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (transaction == null) return null;

    final items = await (db.select(
      db.transactionItems,
    )..where((t) => t.transactionId.equals(id))).get();
    return TransactionWithItems(transaction: transaction, items: items);
  }
}
