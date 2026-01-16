import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../data/repositories/stock_repository.dart';
import '../../../products/presentation/providers/product_controller.dart';
import '../../../../data/local/db/app_database.dart';
import '../../../../data/repositories/product_repository.dart';

class StockManageScreen extends ConsumerStatefulWidget {
  const StockManageScreen({super.key});

  @override
  ConsumerState<StockManageScreen> createState() => _StockManageScreenState();
}

class _StockManageScreenState extends ConsumerState<StockManageScreen> {
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(
      productListProvider(_searchController.text),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen Stok')),
      body: Column(
        children: [
          _buildPremiumSearchBar(),
          Expanded(
            child: productsAsync.when(
              data: (products) => _buildStockList(products),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextFormField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Cari produk...',
            prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF6366F1)),
              onPressed: () async {
                final code = await context.push<String>('/scanner');
                if (code != null) {
                  _searchController.text = code;
                  setState(() {});
                }
              },
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onChanged: (v) => setState(() {}),
        ),
      ),
    );
  }

  Widget _buildStockList(List<ProductWithCategory> products) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: products.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = products[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              item.product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Stok Saat Ini: ${item.product.stock}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.history_rounded, color: Colors.blue),
                  onPressed: () => _showHistory(
                    context,
                    ref,
                    item.product.id,
                    item.product.name,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_box_rounded,
                    color: Color(0xFF6366F1),
                  ),
                  onPressed: () => _showAdjustmentDialog(
                    context,
                    ref,
                    item.product.id,
                    item.product.name,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAdjustmentDialog(
    BuildContext context,
    WidgetRef ref,
    int productId,
    String productName,
  ) {
    final qtyController = TextEditingController();
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Atur Stok: $productName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Jumlah (+ atau -)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Keterangan'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final qtyString = qtyController.text;
              final qty = int.tryParse(qtyString) ?? 0;
              await ref
                  .read(stockRepositoryProvider)
                  .adjustStock(
                    productId: productId,
                    changeAmount: qty,
                    type: 'adjustment',
                    note: noteController.text,
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('SIMPAN'),
          ),
        ],
      ),
    );
  }

  void _showHistory(
    BuildContext context,
    WidgetRef ref,
    int productId,
    String productName,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Riwayat: $productName',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<StockHistoryItem>>(
                future: ref
                    .read(stockRepositoryProvider)
                    .getStockHistory(productId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final history = snapshot.data!;
                  return ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final h = history[index];
                      return ListTile(
                        leading: Icon(
                          h.changeAmount > 0
                              ? Icons.add_circle
                              : Icons.remove_circle,
                          color: h.changeAmount > 0 ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          '${h.changeAmount > 0 ? '+' : ''}${h.changeAmount} Unit',
                        ),
                        subtitle: Text(
                          '${h.type} • ${DateFormat('dd MMM HH:mm').format(h.createdAt)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () => _confirmDeleteHistory(
                            context,
                            ref,
                            h.id,
                            productId,
                            productName,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteHistory(
    BuildContext context,
    WidgetRef ref,
    int historyId,
    int productId,
    String productName,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Riwayat?'),
        content: const Text('Catatan riwayat ini akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(stockRepositoryProvider).deleteStockHistory(historyId);
      if (context.mounted) {
        Navigator.pop(context); // Close History BottomSheet to refresh
        _showHistory(context, ref, productId, productName); // Re-open
      }
    }
  }
}
