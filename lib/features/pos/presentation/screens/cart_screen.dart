import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../customers/presentation/providers/customer_providers.dart';
import '../../../../core/utils/currency_utils.dart';
import '../providers/pos_controller.dart';
import '../widgets/payment_sheet.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(posControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Detail Pesanan'),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        actions: [
          if (state.cart.isNotEmpty)
            TextButton.icon(
              onPressed: () => _confirmClearCart(context, ref),
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.red,
              ),
              label: const Text(
                'Hapus Semua',
                style: TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.cart.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      CustomerSelector(state: state),
                      const SizedBox(height: 16),
                      ...state.cart.map((item) => CartItemTile(item: item)),
                      const SizedBox(height: 16),
                      TaxSelector(state: state),
                      const SizedBox(height: 24),
                      // Summary
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _buildSummaryRow('Subtotal', state.subtotal),
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              'Pajak (${state.taxRate}%)',
                              state.taxAmount,
                            ),
                            const Divider(height: 24),
                            _buildSummaryRow(
                              'Total',
                              state.totalAmount,
                              isTotal: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: FilledButton(
                      onPressed: () => _showPaymentSheet(context, state),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: const Color(0xFF6366F1),
                      ),
                      child: const Text(
                        'Bayar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.black12,
          ),
          const SizedBox(height: 16),
          const Text('Keranjang Kosong', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, int amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.black : Colors.grey[600],
          ),
        ),
        Text(
          CurrencyUtils.format(amount),
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? const Color(0xFF6366F1) : Colors.black,
          ),
        ),
      ],
    );
  }

  void _confirmClearCart(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Keranjang?'),
        content: const Text('Semua barang akan dihapus dari keranjang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(posControllerProvider.notifier).clearCart();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showPaymentSheet(BuildContext context, PosState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentSheet(
        total: state.totalAmount,
        defaultMethod: state.defaultPaymentMethod,
        qrisImagePath: state.qrisImagePath,
      ),
    );
  }
}

class CartItemTile extends ConsumerWidget {
  final CartItem item;

  const CartItemTile({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            onPressed: () => ref
                .read(posControllerProvider.notifier)
                .removeFromCart(item.product),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  CurrencyUtils.format(item.product.price),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _CartActionButton(
                  icon: Icons.remove,
                  onPressed: () => ref
                      .read(posControllerProvider.notifier)
                      .updateQuantity(item.product, item.quantity - 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _CartActionButton(
                  icon: Icons.add,
                  onPressed: () => ref
                      .read(posControllerProvider.notifier)
                      .updateQuantity(item.product, item.quantity + 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CartActionButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, size: 16, color: const Color(0xFF64748B)),
      ),
    );
  }
}

class CustomerSelector extends ConsumerWidget {
  final PosState state;

  const CustomerSelector({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      leading: const CircleAvatar(
        radius: 16,
        backgroundColor: Color(0xFFF1F5F9),
        child: Icon(Icons.person, size: 16, color: Color(0xFF6366F1)),
      ),
      title: Text(
        state.selectedCustomer?.name ?? 'Pilih Pelanggan',
        style: TextStyle(
          fontWeight: state.selectedCustomer != null
              ? FontWeight.bold
              : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _showCustomerList(context, ref),
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
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Pilih Pelanggan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: async.when(
                  data: (list) => ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final c = list[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text(c.name[0])),
                        title: Text(c.name),
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

class TaxSelector extends ConsumerWidget {
  final PosState state;

  const TaxSelector({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      leading: const Icon(Icons.receipt_long, color: Colors.grey),
      title: const Text('Pajak (PPN)'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${state.taxRate}%',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      onTap: () => _showTaxDialog(context, ref, state.taxRate),
    );
  }

  void _showTaxDialog(BuildContext context, WidgetRef ref, int currentTax) {
    final controller = TextEditingController(text: currentTax.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atur Pajak (%)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(suffixText: '%'),
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
}
