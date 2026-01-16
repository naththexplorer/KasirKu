import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../data/local/db/app_database.dart';
import '../../../../data/repositories/shop_repository.dart';
import '../../../../data/repositories/transaction_repository.dart';
import '../../../../core/providers.dart';
import '../../../../core/services/receipt_service.dart';

class ReceiptPreviewScreen extends ConsumerStatefulWidget {
  final int transactionId;

  const ReceiptPreviewScreen({super.key, required this.transactionId});

  @override
  ConsumerState<ReceiptPreviewScreen> createState() =>
      _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends ConsumerState<ReceiptPreviewScreen> {
  bool _isGeneratingImage = false;
  Uint8List? _cachedImageBytes; // Cache to prevent regeneration
  String? _cachedInvoiceNumber; // Track which transaction is cached

  @override
  void dispose() {
    _cachedImageBytes = null; // Clear cache on disposal
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Struk Pembayaran'),
        actions: [
          // Share as Image Button
          IconButton(
            icon: _isGeneratingImage
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.image),
            tooltip: 'Bagikan sebagai Gambar',
            onPressed: _isGeneratingImage ? null : () => _shareAsImage(),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadData(),
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
            canChangeOrientation: false,
            canDebug: false,
            pdfFileName: 'struk-${txWithItems.transaction.invoiceNumber}.pdf',
          );
        },
      ),
    );
  }

  Future<void> _shareAsImage() async {
    setState(() => _isGeneratingImage = true);

    try {
      final data = await _loadData();
      final shop = data['shop'] as Shop;
      final txWithItems = data['tx'] as TransactionWithItems;
      final invoiceNumber = txWithItems.transaction.invoiceNumber;

      // Check if we have cached image for this transaction
      Uint8List imageBytes;
      if (_cachedImageBytes != null && _cachedInvoiceNumber == invoiceNumber) {
        // Use cached image
        imageBytes = _cachedImageBytes!;
      } else {
        // Generate new image and cache it
        imageBytes = await ReceiptService.generateReceiptImage(
          shop: shop,
          transaction: txWithItems.transaction,
          items: txWithItems.items,
        );
        _cachedImageBytes = imageBytes;
        _cachedInvoiceNumber = invoiceNumber;
      }

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final fileName = 'struk-$invoiceNumber.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      // Share the image
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Struk Pembayaran - $invoiceNumber');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membuat gambar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingImage = false);
      }
    }
  }

  Future<Map<String, dynamic>> _loadData() async {
    final shop = await ref.read(shopRepositoryProvider).getShop();
    final tx = await _getTransactionData(widget.transactionId);
    return {'shop': shop, 'tx': tx};
  }

  Future<TransactionWithItems?> _getTransactionData(int id) async {
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
