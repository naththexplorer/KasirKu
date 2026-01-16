import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/customer_repository.dart';
import '../providers/customer_providers.dart';
import '../../../../data/local/db/app_database.dart';
import '../../../../core/utils/currency_utils.dart';

class CustomerScreen extends ConsumerStatefulWidget {
  const CustomerScreen({super.key});

  @override
  ConsumerState<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends ConsumerState<CustomerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pelanggan & Hutang'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Semua Pelanggan'),
            Tab(text: 'Daftar Hutang'),
          ],
        ),
      ),
      body: customersAsync.when(
        data: (customers) {
          return TabBarView(
            controller: _tabController,
            children: [
              RepaintBoundary(
                child: _buildCustomerList(context, ref, customers),
              ),
              RepaintBoundary(
                child: _buildCustomerList(
                  context,
                  ref,
                  customers.where((c) => c.totalDebt > 0).toList(),
                  isDaftarHutangTab: true,
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomerDialog(context, ref),
        label: const Text('Tambah Pelanggan'),
        icon: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildCustomerList(
    BuildContext context,
    WidgetRef ref,
    List<Customer> customers, {
    bool isDaftarHutangTab = false,
  }) {
    if (customers.isEmpty) {
      return const Center(child: Text('Belum ada pelanggan'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: customers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final c = customers[index];
        final bool hasDebt = c.totalDebt > 0;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
              child: Text(
                c.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              c.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              c.phone ?? 'No HP tidak ada',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  hasDebt ? CurrencyUtils.format(c.totalDebt) : 'Lunas',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: hasDebt ? Colors.red : Colors.green,
                  ),
                ),
                const Text(
                  'Saldo Hutang',
                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            onTap: () => _showDebtActionSheet(context, ref, c),
          ),
        );
      },
    );
  }

  void _showDebtActionSheet(BuildContext context, WidgetRef ref, Customer c) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
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
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  c.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Hutang Saat Ini: ${CurrencyUtils.format(c.totalDebt)}',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
            title: const Text('Tambah Hutang Baru'),
            onTap: () {
              Navigator.pop(context);
              _showAddDebtDialog(context, ref, c);
            },
          ),
          ListTile(
            leading: const Icon(Icons.payment, color: Colors.green),
            title: const Text('Bayar Hutang (Cicil/Lunas)'),
            onTap: () {
              Navigator.pop(context);
              _showPayDebtDialog(context, ref, c);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Hapus Pelanggan'),
            onTap: () async {
              Navigator.pop(context);
              _confirmDeleteCustomer(context, ref, c);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showAddDebtDialog(BuildContext context, WidgetRef ref, Customer c) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tambah Hutang: ${c.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Nominal Hutang',
                hintText: 'Misal: 50.000',
              ),
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
              final cleanText = controller.text.replaceAll('.', '');
              final amount = int.tryParse(cleanText) ?? 0;
              if (amount <= 0) return;
              await ref.read(customerRepositoryProvider).addDebt(c.id, amount);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('TAMBAH'),
          ),
        ],
      ),
    );
  }

  void _showPayDebtDialog(BuildContext context, WidgetRef ref, Customer c) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bayar Hutang: ${c.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Hutang: ${CurrencyUtils.format(c.totalDebt)}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Jumlah Bayar',
                hintText: 'Misal: 20.000',
              ),
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
              final cleanText = controller.text.replaceAll('.', '');
              final amount = int.tryParse(cleanText) ?? 0;
              if (amount <= 0) return;
              await ref.read(customerRepositoryProvider).payDebt(c.id, amount);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('BAYAR'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCustomer(
    BuildContext context,
    WidgetRef ref,
    Customer c,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pelanggan?'),
        content: Text('Hapus data ${c.name} secara permanen?'),
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
      await ref.read(customerRepositoryProvider).deleteCustomer(c.id);
    }
  }

  void _showAddCustomerDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pelanggan Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nama Lengkap'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor HP'),
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
              if (nameController.text.isEmpty) return;
              await ref
                  .read(customerRepositoryProvider)
                  .createCustomer(
                    CustomersCompanion(
                      name: drift.Value(nameController.text),
                      phone: drift.Value(phoneController.text),
                    ),
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('SIMPAN'),
          ),
        ],
      ),
    );
  }
}
