import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../../../data/local/db/app_database.dart';
import '../../../../core/providers/shop_setup_provider.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../../data/repositories/shop_repository.dart';
import '../providers/settings_provider.dart';
import 'shop_profile_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider);
    // Check if truly signed in via Google (for backup features)

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Akun',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(user?.name ?? 'Admin'),
            subtitle: Text(user?.role ?? 'Owner'),
          ),
          ListTile(
            leading: const Icon(Icons.storefront),
            title: const Text('Profil Toko'),
            subtitle: const Text('Nama, Alamat, No HP, Pajak'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ShopProfileScreen(),
              ),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Aplikasi',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ),
          Consumer(
            builder: (context, ref, _) {
              final settings = ref.watch(settingsProvider);
              return SwitchListTile(
                secondary: const Icon(Icons.volume_up),
                title: const Text('Suara Scan'),
                subtitle: const Text('Bunyikan bip saat berhasil scan'),
                value: settings.isSoundEnabled,
                onChanged: (val) =>
                    ref.read(settingsProvider.notifier).setSoundEnabled(val),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Versi Aplikasi'),
            trailing: const Text('1.0.0'),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Pembayaran',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ),
          FutureBuilder<Shop?>(
            future: ref.read(shopRepositoryProvider).getShop(),
            builder: (context, snapshot) {
              final shop = snapshot.data;
              if (shop == null) return const SizedBox.shrink();

              return ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Metode Pembayaran Default'),
                subtitle: Text(
                  'Metode terpilih: ${shop.defaultPaymentMethod.toUpperCase()}',
                ),
                trailing: DropdownButton<String>(
                  value: shop.defaultPaymentMethod,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('CASH')),
                    DropdownMenuItem(value: 'qris', child: Text('QRIS')),
                  ],
                  onChanged: (val) async {
                    if (val != null) {
                      await ref
                          .read(shopRepositoryProvider)
                          .updateDefaultPaymentMethod(val);
                      // Invalidate isShopSetup to trigger UI refresh if needed,
                      // or just use a local setState inside a StatefulWidget
                      // But since this is a ConsumerWidget, we could use a provider to watch shop.
                    }
                  },
                ),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Pencadangan (Cloud)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.indigo.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_sync,
                    size: 48,
                    color: Colors.indigo.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Fitur Cloud Sync',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fitur pencadangan otomatis sedang dalam pengembangan.\nData Anda saat ini tersimpan aman secara lokal di perangkat ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'SOON',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Zona Bahaya',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Reset Aplikasi',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Hapus semua data dan mulai dari awal'),
            onTap: () => _confirmReset(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Aplikasi?'),
        content: const Text(
          'SEMUA DATA AKAN DIHAPUS PERMANEN (Produk, Transaksi, Laporan, dll).\n\nAplikasi akan kembali ke pengaturan awal.',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESET SEKARANG'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Execute reset
      final db = ref.read(databaseProvider);
      // Delete tables
      await db.delete(db.transactionItems).go();
      await db.delete(db.transactions).go();
      await db.delete(db.products).go();
      await db.delete(db.categories).go();
      await db.delete(db.customers).go();
      await db.delete(db.expenses).go();
      await db.delete(db.stockHistory).go();
      await db.delete(db.users).go(); // Logout effectively
      await db.delete(db.shops).go(); // Needs re-onboarding

      // Force Logout and Redirect
      ref.read(authControllerProvider.notifier).logout();
      ref.invalidate(isShopSetupProvider);

      if (context.mounted) context.go('/onboarding');
    }
  }
}
