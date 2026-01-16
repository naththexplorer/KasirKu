import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../../data/repositories/shop_repository.dart';
import '../providers/dashboard_providers.dart';
import '../../../../data/repositories/transaction_repository.dart';
import '../../../../core/utils/currency_utils.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(shopRepositoryProvider).getShop();
    final user = ref.watch(authControllerProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF6366F1),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () => context.push('/settings'),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (user != null)
                        Text(
                          'Halo, ${user.name} 👋',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 16,
                          ),
                        ),
                      FutureBuilder(
                        future: shopAsync,
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data?.name ?? 'KasirKu',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                icon: const Icon(Icons.logout, color: Colors.white, size: 18),
                label: const Text(
                  'Keluar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  statsAsync.when(
                    data: (stats) =>
                        RepaintBoundary(child: _buildQuickStats(stats)),
                    loading: () => const _QuickStatsPlaceholder(),
                    error: (e, s) => const _QuickStatsError(),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Layanan Utama',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  RepaintBoundary(child: _buildMenuGrid(context)),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(TransactionTodayStats stats) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: 'Penjualan',
              value: CurrencyUtils.format(stats.totalRevenue),
              icon: Icons.shopping_bag,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Container(height: 40, width: 1, color: const Color(0xFFF1F5F9)),
          const SizedBox(width: 8),
          Expanded(
            child: _StatItem(
              label: 'Transaksi',
              value: stats.count.toString(),
              icon: Icons.receipt_long,
              color: Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _MenuCard(
          title: 'Kasir (POS)',
          icon: Icons.point_of_sale_rounded,
          color: const Color(0xFF6366F1),
          onTap: () => context.push('/pos'),
        ),
        _MenuCard(
          title: 'Produk',
          icon: Icons.inventory_2_rounded,
          color: const Color(0xFF3B82F6),
          onTap: () => context.push('/products'),
        ),
        _MenuCard(
          title: 'Manajemen Stok',
          icon: Icons.layers_rounded,
          color: const Color(0xFF10B981),
          onTap: () => context.push('/stock'),
        ),
        _MenuCard(
          title: 'Catat Pengeluaran',
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFFEF4444),
          onTap: () => context.push('/expenses'),
        ),
        _MenuCard(
          title: 'Pelanggan',
          icon: Icons.people_alt_rounded,
          color: const Color(0xFF8B5CF6),
          onTap: () => context.push('/customers'),
        ),
        _MenuCard(
          title: 'Laporan',
          icon: Icons.analytics_rounded,
          color: const Color(0xFFF59E0B),
          onTap: () => context.push('/reports'),
        ),
      ],
    );
  }
}

class _QuickStatsError extends StatelessWidget {
  const _QuickStatsError();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: Text(
          'Gagal memuat statistik hari ini',
          style: TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }
}

class _QuickStatsPlaceholder extends StatelessWidget {
  const _QuickStatsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF1E293B),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
