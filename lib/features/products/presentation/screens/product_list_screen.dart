import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/product_controller.dart';
import '../../../../data/repositories/product_repository.dart';
import '../../../../data/local/db/app_database.dart';
import '../../../../core/utils/currency_utils.dart';

import 'dart:io';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(productSearchProvider);
    final productsAsync = ref.watch(productListProvider(searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produk & Kategori'),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Color(0xFF6366F1),
            ),
            onPressed: () => context.push('/products/add'),
          ),
          const SizedBox(width: 16),
        ],
        bottom: const _PremiumSearchBar(),
      ),
      body: productsAsync.when(
        data: (products) => RepaintBoundary(child: _buildProductList(products)),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildProductList(List<ProductWithCategory> products) {
    if (products.isEmpty) {
      return const Center(child: Text('Belum ada produk'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: products.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
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
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                child: item.product.imagePath != null
                    ? Image.file(
                        File(item.product.imagePath!),
                        fit: BoxFit.cover,
                      )
                    : const Icon(
                        Icons.inventory_2_rounded,
                        color: Color(0xFF6366F1),
                      ),
              ),
            ),
            title: Text(
              item.product.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  item.category?.name ?? 'Tanpa Kategori',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyUtils.format(item.product.price),
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StockBadge(stock: item.product.stock),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                  onPressed: () =>
                      _confirmDeleteProduct(context, ref, item.product),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
              ],
            ),
            onTap: () => context.push('/products/edit/${item.product.id}'),
          ),
        );
      },
    );
  }

  void _confirmDeleteProduct(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Produk?'),
        content: Text('Hapus "${product.name}" permanen dari sistem?'),
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
      await ref
          .read(productControllerProvider.notifier)
          .deleteProduct(product.id);
    }
  }
}

final productSearchProvider = StateProvider<String>((ref) => '');

class _PremiumSearchBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  const _PremiumSearchBar();

  @override
  ConsumerState<_PremiumSearchBar> createState() => _PremiumSearchBarState();

  @override
  Size get preferredSize => const Size.fromHeight(80);
}

class _PremiumSearchBarState extends ConsumerState<_PremiumSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(productSearchProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Cari produk atau scan...',
            prefixIcon: IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF6366F1)),
              onPressed: () async {
                final code = await context.push<String>('/scanner');
                if (code != null) {
                  _controller.text = code;
                  ref.read(productSearchProvider.notifier).state = code;
                }
              },
            ),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Color(0xFF94A3B8)),
                    onPressed: () {
                      _controller.clear();
                      ref.read(productSearchProvider.notifier).state = '';
                      setState(() {});
                    },
                  )
                : const Icon(Icons.search, color: Color(0xFF64748B)),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onChanged: (v) {
            ref.read(productSearchProvider.notifier).state = v;
            setState(() {});
          },
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final int stock;
  const _StockBadge({required this.stock});

  @override
  Widget build(BuildContext context) {
    final bool low = stock < 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: low
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$stock Unit',
        style: TextStyle(
          color: low ? Colors.red : Colors.green,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
