import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../customers/presentation/providers/customer_providers.dart';
import '../../../products/presentation/providers/product_controller.dart';
import '../providers/pos_controller.dart';
import '../../../../data/repositories/shop_repository.dart';
import 'receipt_preview_screen.dart';
import 'dart:io';
import '../../../../data/repositories/product_repository.dart';
import '../../../../core/utils/currency_utils.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  bool _isSelectingProduct = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDefaultTax();
    });
  }

  Future<void> _loadDefaultTax() async {
    final shop = await ref.read(shopRepositoryProvider).getShop();
    if (shop != null && mounted) {
      ref.read(posControllerProvider.notifier).setTaxRate(shop.taxRate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final posState = ref.watch(posControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_isSelectingProduct ? 'Pilih Produk' : 'Kasir'),
        leading: _isSelectingProduct
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _isSelectingProduct = false),
              )
            : null,
      ),
      body: _isSelectingProduct
          ? _buildSelectionView()
          : _buildCartView(posState),
      bottomNavigationBar: _isSelectingProduct
          ? null
          : _buildBottomBar(posState),
    );
  }

  Widget _buildSelectionView() {
    final productsAsync = ref.watch(
      productListProvider(_searchController.text),
    );

    return Column(
      children: [
        _buildSearchField(),
        Expanded(
          child: productsAsync.when(
            data: (products) => _buildProductGrid(products),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildCartView(PosState state) {
    if (state.cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Keranjang Masih Kosong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Klik tombol di bawah untuk mulai\nmenambahkan produk',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 220,
              height: 64,
              child: FilledButton.icon(
                onPressed: () => setState(() => _isSelectingProduct = true),
                icon: const Icon(Icons.add),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                label: const Text(
                  'TAMBAH PRODUK',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _CustomerSelectorInCart(),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              Text(
                'Daftar Pesanan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: state.cart.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = state.cart[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Text(
                    item.product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${CurrencyUtils.format(item.product.price)} x ${item.quantity}',
                    style: const TextStyle(color: Color(0xFF6366F1)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _QtyButton(
                        icon: Icons.remove,
                        onPressed: () => ref
                            .read(posControllerProvider.notifier)
                            .updateQuantity(item.product, item.quantity - 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _QtyButton(
                        icon: Icons.add,
                        onPressed: () => ref
                            .read(posControllerProvider.notifier)
                            .updateQuantity(item.product, item.quantity + 1),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _isSelectingProduct = true),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF6366F1)),
                foregroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('TAMBAH PRODUK LAGI'),
            ),
          ),
        ),
        _buildTaxAdjustment(state),
      ],
    );
  }

  Widget _buildTaxAdjustment(PosState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: InkWell(
        onTap: () => _showTaxDialog(context, ref, state.taxRate),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Pajak (PPN)',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                '${state.taxRate}%',
                style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaxDialog(BuildContext context, WidgetRef ref, int currentTax) {
    final controller = TextEditingController(text: currentTax.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atur Pajak (PPN)'),
        content: TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Persentase (%)',
            suffixText: '%',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 0;
              ref.read(posControllerProvider.notifier).setTaxRate(val);
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Cari produk atau scan...',
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

  Widget _buildProductGrid(List<ProductWithCategory> products) {
    if (products.isEmpty) {
      return const Center(child: Text('Produk tidak ditemukan'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final item = products[index];
        return _ProductCard(
          name: item.product.name,
          price: item.product.price,
          stock: item.product.stock,
          imagePath: item.product.imagePath,
          onTap: () {
            ref.read(posControllerProvider.notifier).addToCart(item.product);
            setState(() => _isSelectingProduct = false);
          },
        );
      },
    );
  }

  Widget _buildBottomBar(PosState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Pembayaran',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
                Text(
                  CurrencyUtils.format(state.totalAmount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: state.cart.isEmpty
                  ? null
                  : () => _showPaymentDialog(
                      context,
                      ref,
                      state.totalAmount,
                      state.defaultPaymentMethod,
                    ),
              child: const Text('Proses Bayar'),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    int total,
    String defaultMethod,
  ) {
    showDialog(
      context: context,
      builder: (context) =>
          _PaymentDialog(total: total, defaultMethod: defaultMethod),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _QtyButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: const Color(0xFF1E293B)),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String name;
  final int price;
  final int stock;
  final String? imagePath;
  final VoidCallback onTap;

  const _ProductCard({
    required this.name,
    required this.price,
    required this.stock,
    this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imagePath != null && imagePath!.isNotEmpty
                        ? Image.file(File(imagePath!), fit: BoxFit.cover)
                        : const Icon(
                            Icons.inventory_2_rounded,
                            color: Color(0xFFCBD5E1),
                            size: 40,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                CurrencyUtils.format(price),
                style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Stok: $stock',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerSelectorInCart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(posControllerProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: InkWell(
        onTap: () => _showCustomerList(context, ref),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pelanggan',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    Text(
                      state.selectedCustomer?.name ?? 'Pilih Pelanggan',
                      style: TextStyle(
                        color: state.selectedCustomer == null
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF1E293B),
                        fontWeight: state.selectedCustomer == null
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomerList(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final async = ref.watch(customerListProvider);
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Pilih Pelanggan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: async.when(
                  data: (list) => ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: list.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final c = list[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFF1F5F9),
                          child: Text(
                            c.name[0],
                            style: const TextStyle(color: Color(0xFF6366F1)),
                          ),
                        ),
                        title: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(c.phone ?? ''),
                        onTap: () {
                          ref
                              .read(posControllerProvider.notifier)
                              .setCustomer(c);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text('Error: $e'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentDialog extends ConsumerStatefulWidget {
  final int total;
  final String defaultMethod;
  const _PaymentDialog({required this.total, required this.defaultMethod});

  @override
  ConsumerState<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<_PaymentDialog> {
  late String _selectedMethod;
  final _cashController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.defaultMethod;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pembayaran'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total: ${CurrencyUtils.format(widget.total)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 16),
            const Text(
              'Metode Pembayaran:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('CASH'),
                    selected: _selectedMethod == 'cash',
                    onSelected: (val) =>
                        setState(() => _selectedMethod = 'cash'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('QRIS'),
                    selected: _selectedMethod == 'qris',
                    onSelected: (val) =>
                        setState(() => _selectedMethod = 'qris'),
                  ),
                ),
              ],
            ),
            if (_selectedMethod == 'cash') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _cashController,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Uang Diterima',
                  hintText: 'Misal: 10.000',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () async {
            int cash = widget.total;
            if (_selectedMethod == 'cash') {
              final cleanText = _cashController.text.replaceAll('.', '');
              cash = int.tryParse(cleanText) ?? 0;
              if (cash < widget.total) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Uang kurang!')));
                return;
              }
            } else if (_selectedMethod == 'qris') {
              // For QRIS, we assume exact payment for now.
              cash = widget.total;
            }

            final transactionId = await ref
                .read(posControllerProvider.notifier)
                .checkout(_selectedMethod, cash);

            if (transactionId != null && context.mounted) {
              Navigator.pop(context); // Dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ReceiptPreviewScreen(transactionId: transactionId),
                ),
              );
            }
          },
          child: const Text('Lanjutkan'),
        ),
      ],
    );
  }
}
