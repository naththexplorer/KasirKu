import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../data/repositories/transaction_repository.dart';
import '../../../../data/repositories/expense_repository.dart';
import '../../../../core/utils/currency_utils.dart';
import 'transaction_detail_screen.dart';

// Provider for transaction history
final transactionHistoryProvider =
    StreamProvider.autoDispose<List<TransactionWithItems>>((ref) {
      final repo = ref.watch(transactionRepositoryProvider);
      return repo.watchTransactions();
    });

// Helper model for P&L
class ProfitLossData {
  final int revenue;
  final int cogs;
  final int expenses;
  int get grossProfit => revenue - cogs;
  int get netProfit => grossProfit - expenses;

  ProfitLossData({
    required this.revenue,
    required this.cogs,
    required this.expenses,
  });
}

final profitLossProvider = FutureProvider.autoDispose
    .family<ProfitLossData, DateTimeRange?>((ref, range) async {
      final transRepo = ref.watch(transactionRepositoryProvider);
      final expenseRepo = ref.watch(expenseRepositoryProvider);

      final summary = await transRepo.getTransactionSummary(
        start: range?.start,
        end: range?.end,
      );
      final expenses = await expenseRepo.getTotalExpenses(
        start: range?.start,
        end: range?.end,
      );

      return ProfitLossData(
        revenue: summary.totalRevenue,
        cogs: summary.totalCost,
        expenses: expenses,
      );
    });

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Date Filter State
  String _filterLabel = 'Semua Waktu';
  DateTimeRange? _selectedRange;

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

  void _updateFilter(String label, DateTimeRange? range) {
    setState(() {
      _filterLabel = label;
      _selectedRange = range;
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Filter Periode',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('Semua Waktu'),
              onTap: () {
                _updateFilter('Semua Waktu', null);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('Hari Ini'),
              onTap: () {
                final now = DateTime.now();
                final start = DateTime(now.year, now.month, now.day);
                final end = start
                    .add(const Duration(days: 1))
                    .subtract(const Duration(seconds: 1));
                _updateFilter(
                  'Hari Ini',
                  DateTimeRange(start: start, end: end),
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Bulan Ini'),
              onTap: () {
                final now = DateTime.now();
                final start = DateTime(now.year, now.month, 1);
                final end = DateTime(
                  now.year,
                  now.month + 1,
                  1,
                ).subtract(const Duration(seconds: 1));
                _updateFilter(
                  'Bulan Ini',
                  DateTimeRange(start: start, end: end),
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Riwayat Transaksi'),
            Tab(text: 'Laba Rugi'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _showFilterSheet,
            icon: const Icon(
              Icons.calendar_today,
              color: Colors.white,
              size: 16,
            ),
            label: Text(
              _filterLabel,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RepaintBoundary(child: _TransactionHistoryTab(range: _selectedRange)),
          RepaintBoundary(child: _ProfitLossTab(range: _selectedRange)),
        ],
      ),
    );
  }
}

class _TransactionHistoryTab extends ConsumerWidget {
  final DateTimeRange? range;
  const _TransactionHistoryTab({this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(transactionHistoryProvider);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return historyAsync.when(
      data: (transactions) {
        final filtered = range == null
            ? transactions
            : transactions.where((t) {
                final date = t.transaction.createdAt;
                return date.isAfter(range!.start) && date.isBefore(range!.end);
              }).toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Text('Belum ada transaksi pada periode ini'),
          );
        }

        final totalRevenue = filtered.fold(
          0,
          (sum, t) => sum + t.transaction.totalAmount,
        );

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.indigo.shade50,
              child: Column(
                children: [
                  Text(
                    'Total Pendapatan',
                    style: TextStyle(color: Colors.indigo.shade800),
                  ),
                  Text(
                    CurrencyUtils.format(totalRevenue),
                    style: const TextStyle(
                      color: Colors.indigo,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final item = filtered[filtered.length - 1 - index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.info_outline,
                      color: Colors.indigo.withValues(alpha: 0.7),
                    ),
                    title: Text(
                      item.transaction.invoiceNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      dateFormat.format(item.transaction.createdAt),
                    ),
                    trailing: Text(
                      CurrencyUtils.format(item.transaction.totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TransactionDetailScreen(
                            transactionId: item.transaction.id,
                          ),
                        ),
                      );
                    },
                    onLongPress: () => _confirmDeleteTransaction(
                      context,
                      ref,
                      item.transaction.id,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  void _confirmDeleteTransaction(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: const Text('Data transaksi ini akan dihapus permanen.'),
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
      await ref.read(transactionRepositoryProvider).deleteTransaction(id);
    }
  }
}

class _ProfitLossTab extends ConsumerWidget {
  final DateTimeRange? range;
  const _ProfitLossTab({this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plAsync = ref.watch(profitLossProvider(range));

    return plAsync.when(
      data: (data) {
        final isProfit = data.netProfit >= 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- NET PROFIT HERO CARD ---
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isProfit
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: (isProfit ? Colors.green : Colors.red).withValues(
                        alpha: 0.3,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      isProfit
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'LABA BERSIH',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyUtils.format(data.netProfit),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // --- SECTION TITLE ---
              const Text(
                'Rincian Laba Rugi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),

              // --- REVENUE ---
              _PremiumStatCard(
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFF3B82F6),
                label: 'Omzet Penjualan',
                value: data.revenue,
                isPositive: true,
              ),

              const SizedBox(height: 12),

              // --- COGS ---
              _PremiumStatCard(
                icon: Icons.inventory_2_outlined,
                iconColor: const Color(0xFFF59E0B),
                label: 'Harga Pokok Penjualan (HPP)',
                value: data.cogs,
                isPositive: false,
              ),

              const SizedBox(height: 12),

              // --- GROSS PROFIT ---
              _PremiumStatCard(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFF14B8A6),
                label: 'Laba Kotor',
                value: data.grossProfit,
                isPositive: data.grossProfit >= 0,
                isHighlighted: true,
              ),

              const SizedBox(height: 12),

              // --- EXPENSES ---
              _PremiumStatCard(
                icon: Icons.receipt_long_outlined,
                iconColor: const Color(0xFFEF4444),
                label: 'Total Pengeluaran',
                value: data.expenses,
                isPositive: false,
              ),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }
}

class _PremiumStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int value;
  final bool isPositive;
  final bool isHighlighted;

  const _PremiumStatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isPositive,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted ? iconColor.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? iconColor : const Color(0xFFE2E8F0),
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isPositive ? '' : '-'}${CurrencyUtils.format(value.abs())}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isHighlighted ? iconColor : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
