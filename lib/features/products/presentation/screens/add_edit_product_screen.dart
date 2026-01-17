import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../data/local/db/app_database.dart';
import '../providers/product_controller.dart';
import '../../../../data/repositories/product_repository.dart';
import '../../../../core/utils/currency_formatter.dart';

class AddEditProductScreen extends ConsumerStatefulWidget {
  final int? productId; // null = Add Mode

  const AddEditProductScreen({super.key, this.productId});

  @override
  ConsumerState<AddEditProductScreen> createState() =>
      _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController();
  final _barcodeController = TextEditingController();

  int? _selectedCategoryId;
  String? _imagePath;
  bool _isInit = true;
  Product? _existingProduct;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit && widget.productId != null) {
      _loadProduct();
      _isInit = false;
    }
  }

  Future<void> _loadProduct() async {
    final repo = ref.read(productRepositoryProvider);
    try {
      final product = await repo.getProduct(widget.productId!);
      if (product != null && mounted) {
        setState(() {
          _existingProduct = product;
          _nameController.text = product.name;
          _priceController.text = CurrencyInputFormatter.format(product.price);
          _costController.text = product.cost != null
              ? CurrencyInputFormatter.format(product.cost!)
              : '';
          _stockController.text = product.stock.toString();
          _barcodeController.text = product.barcode ?? '';
          _selectedCategoryId = product.categoryId;
          _imagePath = product.imagePath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat produk: $e')));
      }
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final price = CurrencyInputFormatter.parse(_priceController.text);
      final costText = _costController.text.trim();
      final cost = costText.isEmpty
          ? null
          : CurrencyInputFormatter.parse(_costController.text);
      final stock = int.tryParse(_stockController.text) ?? 0;
      final barcode = _barcodeController.text.isEmpty
          ? null
          : _barcodeController.text;

      // Logic Check: Cost > Price
      if (cost != null && cost > price) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cek Harga Modal'),
            content: Text(
              'Harga Modal (${CurrencyInputFormatter.format(cost)}) lebih tinggi dari Harga Jual (${CurrencyInputFormatter.format(price)}).\n\nIni berarti Anda akan merugi. Lanjutkan?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Perbaiki'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Lanjutkan'),
              ),
            ],
          ),
        );

        if (proceed != true) return;
      }

      bool success;
      if (widget.productId == null) {
        // ADD
        final newProduct = ProductsCompanion(
          name: drift.Value(name),
          price: drift.Value(price),
          cost: drift.Value(cost),
          stock: drift.Value(stock),
          barcode: drift.Value(barcode),
          categoryId: drift.Value(_selectedCategoryId),
          imagePath: drift.Value(_imagePath),
        );
        success = await ref
            .read(productControllerProvider.notifier)
            .addProduct(newProduct);
      } else {
        // EDIT
        if (_existingProduct == null) return;

        final updatedProduct = _existingProduct!.copyWith(
          name: name,
          price: price,
          cost: drift.Value(cost),
          stock: stock,
          barcode: drift.Value(barcode),
          categoryId: drift.Value(_selectedCategoryId),
          imagePath: drift.Value(_imagePath),
        );

        success = await ref
            .read(productControllerProvider.notifier)
            .editProduct(updatedProduct);
      }

      if (success && mounted) {
        context.pop();
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _imagePath = image.path;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryListProvider);
    final isEditing = widget.productId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Produk' : 'Tambah Produk'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildImagePicker(),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Produk*'),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Harga Jual*',
                      ),
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Stok Awal'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Harga Modal',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              categoriesAsync.when(
                data: (categories) => Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey(_selectedCategoryId),
                        initialValue: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                        ),
                        items: categories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCategoryId = v),
                        validator: (v) =>
                            v == null ? 'Kategori wajib dipilih' : null,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      color: Colors.indigo,
                      tooltip: 'Atur Kategori',
                      onPressed: () =>
                          _showManageCategoriesDialog(context, ref),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: Colors.indigo,
                      tooltip: 'Tambah Kategori',
                      onPressed: () => _showAddCategoryDialog(context, ref),
                    ),
                  ],
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => const Text('Gagal memuat kategori'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: 'Barcode / SKU',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code),
                    onPressed: () async {
                      final result = await context.push<String>('/scanner');
                      if (result != null) {
                        _barcodeController.text = result;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('SIMPAN PRODUK'),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          image: _imagePath != null
              ? DecorationImage(
                  image: FileImage(File(_imagePath!)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: _imagePath == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_rounded, color: Color(0xFF64748B)),
                  SizedBox(height: 8),
                  Text(
                    'Tambah Foto',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Produk?'),
        content: const Text('Produk ini akan dihapus permanen dari sistem.'),
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
      final success = await ref
          .read(productControllerProvider.notifier)
          .deleteProduct(widget.productId!);
      if (success && mounted) {
        if (context.mounted) {
          context.pop();
        }
      }
    }
  }

  Future<void> _showManageCategoriesDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atur Kategori'),
        content: SizedBox(
          width: double.maxFinite,
          child: ref
              .watch(categoryListProvider)
              .when(
                data: (categories) => ListView.separated(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return ListTile(
                      title: Text(cat.name),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () =>
                            _confirmDeleteCategory(context, ref, cat),
                      ),
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('Error: $e'),
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCategory(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori?'),
        content: Text(
          'Hapus kategori "${category.name}"? Produk dalam kategori ini akan menjadi tidak berkategori.',
        ),
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
      await ref.read(productRepositoryProvider).deleteCategory(category.id);
      if (mounted) {
        if (_selectedCategoryId == category.id) {
          setState(() => _selectedCategoryId = null);
        }
      }
    }
  }

  Future<void> _showAddCategoryDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Kategori'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nama Kategori'),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await ref
                  .read(productRepositoryProvider)
                  .createCategory(
                    CategoriesCompanion(
                      name: drift.Value(controller.text.trim()),
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
