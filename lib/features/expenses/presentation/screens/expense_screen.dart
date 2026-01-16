import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../data/local/db/app_database.dart';
import '../../../../data/repositories/expense_repository.dart';
import '../providers/expense_providers.dart';
import '../../../../core/utils/currency_utils.dart';

class ExpenseScreen extends ConsumerWidget {
  const ExpenseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesStream = ref.watch(expenseListProvider);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Pengeluaran')),
      body: expensesStream.when(
        data: (expenses) => RepaintBoundary(
          child: _buildExpenseList(context, ref, expenses, dateFormat),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(context, ref),
        label: const Text('Catat Pengeluaran'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildExpenseList(
    BuildContext context,
    WidgetRef ref,
    List<ExpenseItem> expenses,
    DateFormat dateFormat,
  ) {
    if (expenses.isEmpty) {
      return const Center(child: Text('Belum ada data pengeluaran'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: expenses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = expenses[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.money_off_rounded, color: Colors.red),
            ),
            title: Text(
              item.description,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${dateFormat.format(item.date)} • ${item.category}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            trailing: Text(
              CurrencyUtils.format(item.amount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            onLongPress: () => _showDeleteConfirm(context, ref, item.id),
          ),
        );
      },
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus?'),
        content: const Text('Data pengeluaran akan dihapus permanen.'),
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
      await ref.read(expenseRepositoryProvider).deleteExpense(id);
    }
  }

  void _showAddExpenseDialog(BuildContext context, WidgetRef ref) {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String category = 'Operasional';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Catat Baru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Keterangan'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(labelText: 'Jumlah (Rp)'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: ['Operasional', 'Gaji', 'Sewa', 'Bahan Baku', 'Lainnya']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => category = v!),
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
                final desc = descController.text;
                final cleanAmount = amountController.text.replaceAll('.', '');
                final amount = int.tryParse(cleanAmount) ?? 0;
                if (desc.isEmpty || amount <= 0) return;
                await ref
                    .read(expenseRepositoryProvider)
                    .addExpense(
                      ExpensesCompanion(
                        description: drift.Value(desc),
                        amount: drift.Value(amount),
                        category: drift.Value(category),
                      ),
                    );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('SIMPAN'),
            ),
          ],
        ),
      ),
    );
  }
}
