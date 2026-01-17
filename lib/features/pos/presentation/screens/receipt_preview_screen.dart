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
  bool _isProcessing = false;
  Uint8List? _cachedImageBytes;
  Uint8List? _cachedPdfBytes;
  String? _cachedInvoiceNumber;

  @override
  void dispose() {
    _cachedImageBytes = null;
    _cachedPdfBytes = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Struk Pembayaran')),
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

          return Column(
            children: [
              // PDF Preview
              Expanded(
                child: PdfPreview(
                  build: (format) => ReceiptService.generateReceiptPdf(
                    shop: shop,
                    transaction: txWithItems.transaction,
                    items: txWithItems.items,
                  ),
                  allowPrinting: false,
                  allowSharing: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  pdfFileName:
                      'struk-${txWithItems.transaction.invoiceNumber}.pdf',
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: _isProcessing
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.download,
                              label: 'Download',
                              onPressed: () =>
                                  _showDownloadOptions(shop, txWithItems),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.share,
                              label: 'Share PDF',
                              onPressed: () => _shareAsPdf(shop, txWithItems),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.image,
                              label: 'Share PNG',
                              onPressed: () => _shareAsImage(shop, txWithItems),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.print,
                              label: 'Print',
                              onPressed: () => _print(shop, txWithItems),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDownloadOptions(Shop shop, TransactionWithItems txWithItems) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Download Format',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('PDF'),
              subtitle: const Text('Untuk print & share'),
              onTap: () {
                Navigator.pop(context);
                _downloadPdf(shop, txWithItems);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.green),
              title: const Text('PNG (Gambar)'),
              subtitle: const Text('Untuk WhatsApp & sosmed'),
              onTap: () {
                Navigator.pop(context);
                _downloadPng(shop, txWithItems);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadPdf(Shop shop, TransactionWithItems txWithItems) async {
    setState(() => _isProcessing = true);
    try {
      final pdfBytes = await _getOrGeneratePdf(shop, txWithItems);
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/struk-${txWithItems.transaction.invoiceNumber}.pdf',
      );
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF disimpan: ${file.path}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal download: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _downloadPng(Shop shop, TransactionWithItems txWithItems) async {
    setState(() => _isProcessing = true);
    try {
      final imageBytes = await _getOrGenerateImage(shop, txWithItems);
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/struk-${txWithItems.transaction.invoiceNumber}.png',
      );
      await file.writeAsBytes(imageBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gambar disimpan: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal download: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _shareAsPdf(Shop shop, TransactionWithItems txWithItems) async {
    setState(() => _isProcessing = true);
    try {
      final pdfBytes = await _getOrGeneratePdf(shop, txWithItems);
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/struk-${txWithItems.transaction.invoiceNumber}.pdf',
      );
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Struk - ${txWithItems.transaction.invoiceNumber}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal share: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _shareAsImage(
    Shop shop,
    TransactionWithItems txWithItems,
  ) async {
    setState(() => _isProcessing = true);
    try {
      final imageBytes = await _getOrGenerateImage(shop, txWithItems);
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/struk-${txWithItems.transaction.invoiceNumber}.png',
      );
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Struk - ${txWithItems.transaction.invoiceNumber}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal share: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _print(Shop shop, TransactionWithItems txWithItems) async {
    try {
      final pdfBytes = await _getOrGeneratePdf(shop, txWithItems);
      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal print: $e')));
      }
    }
  }

  // Helper methods with caching
  Future<Uint8List> _getOrGeneratePdf(
    Shop shop,
    TransactionWithItems txWithItems,
  ) async {
    final invoiceNumber = txWithItems.transaction.invoiceNumber;
    if (_cachedPdfBytes != null && _cachedInvoiceNumber == invoiceNumber) {
      return _cachedPdfBytes!;
    }

    final pdfBytes = await ReceiptService.generateReceiptPdf(
      shop: shop,
      transaction: txWithItems.transaction,
      items: txWithItems.items,
    );
    _cachedPdfBytes = pdfBytes;
    _cachedInvoiceNumber = invoiceNumber;
    return pdfBytes;
  }

  Future<Uint8List> _getOrGenerateImage(
    Shop shop,
    TransactionWithItems txWithItems,
  ) async {
    final invoiceNumber = txWithItems.transaction.invoiceNumber;
    if (_cachedImageBytes != null && _cachedInvoiceNumber == invoiceNumber) {
      return _cachedImageBytes!;
    }

    final imageBytes = await ReceiptService.generateReceiptImage(
      shop: shop,
      transaction: txWithItems.transaction,
      items: txWithItems.items,
    );
    _cachedImageBytes = imageBytes;
    _cachedInvoiceNumber = invoiceNumber;
    return imageBytes;
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
