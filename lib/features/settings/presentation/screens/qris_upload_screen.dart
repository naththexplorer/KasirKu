import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../../data/repositories/shop_repository.dart';

class QrisUploadScreen extends ConsumerStatefulWidget {
  const QrisUploadScreen({super.key});

  @override
  ConsumerState<QrisUploadScreen> createState() => _QrisUploadScreenState();
}

class _QrisUploadScreenState extends ConsumerState<QrisUploadScreen> {
  String? _qrisImagePath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentQris();
  }

  Future<void> _loadCurrentQris() async {
    final shop = await ref.read(shopRepositoryProvider).getShop();
    if (mounted) {
      setState(() {
        _qrisImagePath = shop?.qrisImagePath;
      });
    }
  }

  Future<void> _pickAndCropImage() async {
    setState(() => _isLoading = true);

    try {
      // Pick image from gallery
      final picker = ImagePicker();
      final XFile? pickedFile;
      try {
        pickedFile = await picker.pickImage(source: ImageSource.gallery);
      } catch (e) {
        throw Exception('Gagal membuka galeri: $e');
      }

      if (pickedFile == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Crop image to square
      final CroppedFile? croppedFile;
      try {
        croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          compressQuality: 90,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Potong QR Code',
              toolbarColor: Colors.indigo,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Potong QR Code',
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
            ),
          ],
        );
      } catch (e) {
        throw Exception('Gagal memotong gambar: $e');
      }

      if (croppedFile == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Save to app directory
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'qris_${DateTime.now().millisecondsSinceEpoch}.png';
      final savedPath = path.join(appDir.path, fileName);
      await File(croppedFile.path).copy(savedPath);

      // Delete old image if exists
      if (_qrisImagePath != null && File(_qrisImagePath!).existsSync()) {
        await File(_qrisImagePath!).delete();
      }

      // Update database
      await ref.read(shopRepositoryProvider).updateQrisImagePath(savedPath);

      setState(() {
        _qrisImagePath = savedPath;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Code berhasil disimpan')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal upload: $e')));
      }
    }
  }

  Future<void> _removeQris() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus QR QRIS?'),
        content: const Text('QR Code akan dihapus dari sistem.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete file
        if (_qrisImagePath != null && File(_qrisImagePath!).existsSync()) {
          await File(_qrisImagePath!).delete();
        }

        // Update database
        await ref.read(shopRepositoryProvider).updateQrisImagePath(null);

        setState(() => _qrisImagePath = null);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR Code berhasil dihapus')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal hapus: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Code QRIS')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info card
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Informasi',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'QR Code ini akan otomatis ditampilkan saat pelanggan memilih metode pembayaran QRIS.',
                            style: TextStyle(color: Colors.blue.shade900),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // QR Preview
                  if (_qrisImagePath != null)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'QR Code Saat Ini',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_qrisImagePath!),
                              width: 250,
                              height: 250,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(48),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.qr_code_2,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada QR Code',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Upload button
                  FilledButton.icon(
                    onPressed: _pickAndCropImage,
                    icon: _qrisImagePath == null
                        ? const Icon(Icons.upload)
                        : const Icon(Icons.edit),
                    label: Text(
                      _qrisImagePath == null
                          ? 'Upload QR Code'
                          : 'Ganti QR Code',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.indigo,
                    ),
                  ),

                  // Remove button (if QR exists)
                  if (_qrisImagePath != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _removeQris,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Hapus QR Code'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
