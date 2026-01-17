import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../data/local/db/app_database.dart';
import '../../../../data/repositories/transaction_repository.dart';
import '../../../../data/repositories/shop_repository.dart';
import '../../../../core/providers.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/services/receipt_service.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  final int transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('Gagal memuat detail transaksi'));
          }

          final shop = snapshot.data!['shop'] as Shop;
          final txWithItems = snapshot.data!['tx'] as TransactionWithItems;
          final customerName = snapshot.data!['customerName'] as String?;
          final transaction = txWithItems.transaction;
          final items = txWithItems.items;

          return CustomScrollView(
            slivers: [
              // App Bar with Delete Action
              SliverAppBar(
                expandedHeight: 60,
                pinned: true,
                title: const Text('Detail Transaksi'),
                actions: [
                  IconButton(
                    icon: _isDeleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.delete_outline),
                    onPressed: _isDeleting ? null : () => _confirmDelete(),
                    tooltip: 'Hapus Transaksi',
                  ),
                ],
              ),

              // Receipt Preview MOVED TO BOTTOM

              // Transaction Info Card
              SliverToBoxAdapter(
                child: Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi Transaksi',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          Icons.receipt_long,
                          'No. Invoice',
                          transaction.invoiceNumber,
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          Icons.calendar_today,
                          'Tanggal',
                          DateFormat(
                            'dd MMM yyyy, HH:mm',
                          ).format(transaction.createdAt),
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          Icons.person_outline,
                          'Pelanggan',
                          customerName ?? 'Umum',
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          Icons.payment,
                          'Metode Pembayaran',
                          transaction.paymentMethod.toUpperCase(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Items List
              SliverToBoxAdapter(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ExpansionTile(
                    leading: const Icon(Icons.shopping_cart_outlined),
                    title: Text(
                      'Detail Barang (${items.length} item)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    children: items
                        .map(
                          (item) => ListTile(
                            title: Text(item.productName),
                            subtitle: Text(
                              '${item.quantity} x ${CurrencyUtils.format(item.priceAtTime)}',
                            ),
                            trailing: Text(
                              CurrencyUtils.format(
                                item.quantity * item.priceAtTime,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),

              // Payment Summary
              SliverToBoxAdapter(
                child: Card(
                  margin: const EdgeInsets.all(16),
                  color: Colors.indigo.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildSummaryRow('Subtotal', transaction.subtotal),
                        if (transaction.tax > 0)
                          _buildSummaryRow('Pajak', transaction.tax),
                        if (transaction.discount > 0)
                          _buildSummaryRow('Diskon', -transaction.discount),
                        const Divider(height: 24),
                        _buildSummaryRow(
                          'TOTAL',
                          transaction.totalAmount,
                          isTotal: true,
                        ),
                        if (transaction.cashReceived != null)
                          _buildSummaryRow('Bayar', transaction.cashReceived!),
                        if (transaction.changeAmount != null &&
                            transaction.changeAmount! > 0)
                          _buildSummaryRow(
                            'Kembali',
                            transaction.changeAmount!,
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Receipt Preview (Moved based on user feedback)
              SliverToBoxAdapter(
                child: Card(
                  margin: const EdgeInsets.all(16),
                  child: ExpansionTile(
                    leading: const Icon(Icons.receipt_long),
                    title: const Text('Lihat Struk'),
                    children: [
                      FutureBuilder<List<int>>(
                        future: ReceiptService.generateReceiptImage(
                          shop: shop,
                          transaction: transaction,
                          items: items,
                        ),
                        builder: (context, imgSnapshot) {
                          if (imgSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox(
                              height: 200,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (imgSnapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Error: ${imgSnapshot.error}',
                                style: const TextStyle(color: Colors.red),
                              ),
                            );
                          }
                          if (!imgSnapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Gagal memuat struk'),
                            );
                          }

                          return Container(
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                Uint8List.fromList(imgSnapshot.data!),
                                fit: BoxFit.contain,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.indigo),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, int amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            CurrencyUtils.format(amount),
            style: TextStyle(
              fontSize: isTotal ? 20 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? Colors.indigo : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: const Text(
          'Transaksi yang dihapus tidak dapat dikembalikan. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isDeleting = true);
      try {
        await ref
            .read(transactionRepositoryProvider)
            .deleteTransaction(widget.transactionId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaksi berhasil dihapus')),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
        }
      }
    }
  }

  Future<Map<String, dynamic>> _loadData() async {
    final shop = await ref.read(shopRepositoryProvider).getShop();
    final tx = await _getTransactionData(widget.transactionId);

    // Fetch customer name if customerId exists
    String? customerName;
    if (tx?.transaction.customerId != null) {
      final db = ref.read(databaseProvider);
      final customer =
          await (db.select(db.customers)
                ..where((c) => c.id.equals(tx!.transaction.customerId!)))
              .getSingleOrNull();
      customerName = customer?.name;
    }

    return {'shop': shop, 'tx': tx, 'customerName': customerName};
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
