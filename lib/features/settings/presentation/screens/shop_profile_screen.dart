import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/local/db/app_database.dart';
import '../../../../data/repositories/shop_repository.dart';

class ShopProfileScreen extends ConsumerStatefulWidget {
  const ShopProfileScreen({super.key});

  @override
  ConsumerState<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends ConsumerState<ShopProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _taxController = TextEditingController();
  bool _isLoading = true;
  Shop? _shop;

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  Future<void> _loadShop() async {
    final shop = await ref.read(shopRepositoryProvider).getShop();
    if (shop != null) {
      setState(() {
        _shop = shop;
        _nameController.text = shop.name;
        _addressController.text = shop.address ?? '';
        _phoneController.text = shop.phone ?? '';
        _taxController.text = shop.taxRate.toString();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text;
    final address = _addressController.text;
    final phone = _phoneController.text;
    final taxRate = int.tryParse(_taxController.text) ?? 0;

    final companion = ShopsCompanion(
      id: drift.Value(_shop?.id ?? 1),
      name: drift.Value(name),
      address: drift.Value(address),
      phone: drift.Value(phone),
      taxRate: drift.Value(taxRate),
    );

    if (_shop != null) {
      await ref.read(shopRepositoryProvider).updateShop(companion);
    } else {
      await ref.read(shopRepositoryProvider).createShop(companion);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil Toko Berhasil Disimpan')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Toko'),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.check_rounded)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informasi Dasar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Toko',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.storefront_rounded),
                ),
                validator: (v) => v!.isEmpty ? 'Nama toko wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Alamat Toko',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_rounded),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Nomor Telepon',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 32),
              const Text(
                'Pengaturan Pajak',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _taxController,
                decoration: const InputDecoration(
                  labelText: 'PPN (%)',
                  hintText: 'Misal: 11',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.receipt_long_rounded),
                  suffixText: '%',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              const Text(
                'Pajak ini akan diterapkan secara otomatis pada setiap transaksi baru.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('SIMPAN PERUBAHAN'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
