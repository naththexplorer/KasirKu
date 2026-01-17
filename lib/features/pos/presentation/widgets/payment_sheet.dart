import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../../../core/utils/currency_utils.dart';
import '../providers/pos_controller.dart';
import '../screens/receipt_preview_screen.dart';

class PaymentSheet extends ConsumerStatefulWidget {
  final int total;
  final String defaultMethod;
  final String? qrisImagePath;

  const PaymentSheet({
    super.key,
    required this.total,
    required this.defaultMethod,
    this.qrisImagePath,
  });

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  late String _selectedMethod;
  final _cashController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.defaultMethod;
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Konfirmasi Pembayaran',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              CurrencyUtils.format(widget.total),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 24),

            // Payment Methods
            Row(
              children: [
                Expanded(child: _buildMethodCard('cash', 'Tunai', Icons.money)),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMethodCard('qris', 'QRIS', Icons.qr_code_2),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content based on method
            if (_selectedMethod == 'cash')
              _buildCashInput()
            else
              _buildQrisDisplay(),

            const SizedBox(height: 24),

            FilledButton(
              onPressed: _processPayment,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Bayar Sekarang',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodCard(String id, String label, IconData icon) {
    final isSelected = _selectedMethod == id;
    return InkWell(
      onTap: () => setState(() => _selectedMethod = id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withValues(alpha: 0.1)
              : const Color(0xFFF8FAFC),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashInput() {
    return Column(
      children: [
        TextField(
          controller: _cashController,
          keyboardType: TextInputType.number,
          autofocus: true,
          inputFormatters: [ThousandsSeparatorInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'Uang Diterima',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            prefixText: 'Rp ',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            _QuickMoneyChip(
              amount: widget.total,
              label: 'Uang Pas',
              onTap: (v) => _cashController.text = CurrencyUtils.format(
                v,
              ).replaceAll('Rp', '').trim(),
            ),
            _QuickMoneyChip(
              amount: 50000,
              label: '50rb',
              onTap: (v) => _cashController.text = CurrencyUtils.format(
                v,
              ).replaceAll('Rp', '').trim(),
            ),
            _QuickMoneyChip(
              amount: 100000,
              label: '100rb',
              onTap: (v) => _cashController.text = CurrencyUtils.format(
                v,
              ).replaceAll('Rp', '').trim(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQrisDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (widget.qrisImagePath != null &&
              File(widget.qrisImagePath!).existsSync())
            Image.file(
              File(widget.qrisImagePath!),
              height: 200,
              width: 200,
              fit: BoxFit.contain,
            )
          else
            const Column(
              children: [
                Icon(Icons.broken_image, size: 60, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'QRIS belum diupload',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          const SizedBox(height: 12),
          const Text(
            'Scan QRIS di atas untuk membayar',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment() async {
    int cash = widget.total;
    if (_selectedMethod == 'cash') {
      final cleanText = _cashController.text.replaceAll('.', '');
      cash = int.tryParse(cleanText) ?? 0;
      if (cash < widget.total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Uang kurang!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final transactionId = await ref
        .read(posControllerProvider.notifier)
        .checkout(_selectedMethod, cash);

    if (transactionId != null && mounted) {
      Navigator.pop(context); // Close sheet
      // Find the root navigator or use the existing context to push replacement
      // BUT we want to push the receipt screen.
      // The user wants: "DARI PREVIEW TADI BARU MUNCUL BAYAR/LANJUTKAN DAN BARULAHMUNCUL MENU KONFIRMASI PEMBAYARAN"
      // After payment -> Receipt.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ReceiptPreviewScreen(transactionId: transactionId),
        ),
      );
    }
  }
}

class _QuickMoneyChip extends StatelessWidget {
  final int amount;
  final String label;
  final Function(int) onTap;

  const _QuickMoneyChip({
    required this.amount,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: () => onTap(amount));
  }
}
