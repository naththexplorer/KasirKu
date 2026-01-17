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
import 'qris_upload_screen.dart';
import '../../../../core/services/backup_service.dart';

// StateProvider untuk trigger refresh shop data
final _shopRefreshProvider = StateProvider<int>((ref) => 0);

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
          // Payment method dropdown with real-time update
          Consumer(
            builder: (context, ref, child) {
              // Watch the refresh trigger - when it changes, widget rebuilds
              ref.watch(_shopRefreshProvider);

              return FutureBuilder<Shop?>(
                future: ref.read(shopRepositoryProvider).getShop(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data == null) {
                    return const ListTile(
                      leading: Icon(Icons.payments_outlined),
                      title: Text('Metode Pembayaran Default'),
                      trailing: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  final shop = snapshot.data!;
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
                          // Increment state to trigger rebuild
                          ref.read(_shopRefreshProvider.notifier).state++;
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
          Consumer(
            builder: (context, ref, child) {
              ref.watch(_shopRefreshProvider);
              return FutureBuilder<Shop?>(
                future: ref.read(shopRepositoryProvider).getShop(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data == null) {
                    return const SizedBox.shrink();
                  }
                  final shop = snapshot.data!;
                  return ListTile(
                    leading: const Icon(Icons.print_outlined),
                    title: const Text('Ukuran Kertas Struk'),
                    subtitle: Text('${shop.printerPaperSize}mm (Thermal)'),
                    trailing: DropdownButton<int>(
                      value: shop.printerPaperSize,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 58, child: Text('58mm')),
                        DropdownMenuItem(value: 80, child: Text('80mm')),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          await ref
                              .read(shopRepositoryProvider)
                              .updatePrinterPaperSize(val);
                          ref.read(_shopRefreshProvider.notifier).state++;
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_2),
            title: const Text('QR Code QRIS'),
            subtitle: const Text('Upload QR pembayaran QRIS'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const QrisUploadScreen(),
                ),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Pencadangan Data',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download_rounded, color: Colors.green),
            title: const Text('Backup Data (CSV/Excel)'),
            subtitle: const Text('Export semua data transaksi & produk ke ZIP'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              try {
                // Show loading
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sedang menyiapkan data...')),
                );

                await ref.read(backupServiceProvider).exportData();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal backup: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
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
