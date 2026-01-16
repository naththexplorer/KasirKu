import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../data/local/db/app_database.dart';
import '../utils/currency_utils.dart';

class ReceiptService {
  /// Generates a Proportional High-Fidelity PDF receipt optimized for Thermal Printers.
  /// Normalized to physical mm to prevent memory exhaustion (Force Close).
  /// Uses a single page with dynamic height to avoid pagination cuts.
  static Future<Uint8List> generateReceiptPdf({
    required Shop shop,
    required Transaction transaction,
    required List<TransactionItem> items,
    bool is80mm = false,
  }) async {
    final pdf = pw.Document();

    // --- PHYSICAL NORMALIZATION (mm to points) ---
    // Standard 58mm or 80mm widths.
    // This prevents the "15-inch wide" OOM crash while keeping the design premium.
    final double paperWidth = (is80mm ? 80.0 : 58.0) * PdfPageFormat.mm;

    // Proportional Font Sizes (Scaled down from the 1080p target to physical mm)
    // Formula: (TargetSize / 1080) * paperWidth
    final double h1 = (72.0 / 1080.0) * paperWidth; // Shop Name
    final double h2 = (48.0 / 1080.0) * paperWidth; // Product Name
    final double std = (42.0 / 1080.0) * paperWidth; // Headers/Totals
    final double tiny = (34.0 / 1080.0) * paperWidth; // Metadata/Qty Info

    final font = pw.Font.courier();
    final fontBold = pw.Font.courierBold();

    // --- DYNAMIC HEIGHT CALCULATION (in mm/points) ---
    double calculateHeight() {
      double h = 0;
      h += (350 / 1080) * paperWidth; // Header
      h += (180 / 1080) * paperWidth; // Metadata
      h += items.length * ((110 / 1080) * paperWidth); // Items
      h += (300 / 1080) * paperWidth; // Totals
      h += (150 / 1080) * paperWidth; // Payment
      h += (450 / 1080) * paperWidth; // Footer + Barcode + Padding

      // Minimum height to avoid stubby receipts (equivalent to ~10cm)
      final minHeight = 100 * PdfPageFormat.mm;
      return h < minHeight ? minHeight : h;
    }

    final totalHeight = calculateHeight();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          paperWidth,
          totalHeight,
          marginAll: 5 * PdfPageFormat.mm, // standard 5mm margin
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // --- HEADER ---
              pw.Text(
                shop.name.toUpperCase(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: fontBold, fontSize: h1),
              ),
              if (shop.address != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text(
                    shop.address!,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: font, fontSize: std),
                  ),
                ),
              if (shop.phone != null)
                pw.Text(
                  shop.phone!,
                  style: pw.TextStyle(font: font, fontSize: std),
                ),

              pw.SizedBox(height: 15),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 10),

              // --- METADATA ---
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'INVOICE:',
                        style: pw.TextStyle(font: font, fontSize: tiny),
                      ),
                      pw.Text(
                        '${transaction.createdAt.day}/${transaction.createdAt.month}/${transaction.createdAt.year}',
                        style: pw.TextStyle(font: font, fontSize: tiny),
                      ),
                    ],
                  ),
                  pw.Text(
                    transaction.invoiceNumber,
                    style: pw.TextStyle(font: fontBold, fontSize: std),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),

              // --- ITEMS (Stacked Layout) ---
              ...items.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item.productName.toUpperCase(),
                        style: pw.TextStyle(font: fontBold, fontSize: h2),
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${item.quantity} x ${CurrencyUtils.format(item.priceAtTime)}',
                            style: pw.TextStyle(font: font, fontSize: tiny),
                          ),
                          pw.Text(
                            CurrencyUtils.format(
                              item.priceAtTime * item.quantity,
                            ),
                            style: pw.TextStyle(font: font, fontSize: std),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 10),

              // --- TOTALS ---
              _buildCleanRow(
                'SUBTOTAL',
                CurrencyUtils.format(transaction.subtotal),
                font,
                std,
              ),
              if (transaction.tax > 0)
                _buildCleanRow(
                  'PAJAK',
                  CurrencyUtils.format(transaction.tax),
                  font,
                  std,
                ),
              if (transaction.discount > 0)
                _buildCleanRow(
                  'DISKON',
                  '-${CurrencyUtils.format(transaction.discount)}',
                  font,
                  std,
                ),

              pw.SizedBox(height: 5),
              _buildCleanRow(
                'TOTAL',
                CurrencyUtils.format(transaction.totalAmount),
                fontBold,
                h1,
              ),

              pw.SizedBox(height: 15),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),

              // --- PAYMENT ---
              _buildCleanRow(
                'BAYAR (${transaction.paymentMethod.toUpperCase()})',
                CurrencyUtils.format(
                  transaction.cashReceived ?? transaction.totalAmount,
                ),
                font,
                std,
              ),
              if (transaction.changeAmount != null &&
                  transaction.changeAmount! > 0)
                _buildCleanRow(
                  'KEMBALI',
                  CurrencyUtils.format(transaction.changeAmount!),
                  fontBold,
                  std,
                ),

              pw.SizedBox(height: 30),

              // --- FOOTER ---
              pw.Text(
                'TERIMA KASIH',
                style: pw.TextStyle(font: fontBold, fontSize: std),
              ),
              pw.Text(
                'ATAS KUNJUNGAN ANDA',
                style: pw.TextStyle(font: font, fontSize: tiny),
              ),

              pw.SizedBox(height: 20),

              // Proportional Barcode
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: transaction.invoiceNumber,
                width: paperWidth * 0.6,
                height: 40,
                drawText: false,
              ),
              pw.SizedBox(height: 20),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildCleanRow(
    String label,
    String value,
    pw.Font font,
    double size,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: size),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(font: font, fontSize: size),
          ),
        ],
      ),
    );
  }

  /// Generates raw bytes for direct ESC/POS thermal printing.
  static Future<List<int>> generateRawEscPos({
    required Shop shop,
    required Transaction transaction,
    required List<TransactionItem> items,
    bool is80mm = false,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(
      is80mm ? PaperSize.mm80 : PaperSize.mm58,
      profile,
    );
    List<int> bytes = [];

    // Header
    bytes += generator.text(
      shop.name.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    if (shop.address != null) {
      bytes += generator.text(
        shop.address!,
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    if (shop.phone != null) {
      bytes += generator.text(
        shop.phone!,
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    bytes += generator.hr();
    bytes += generator.text('INV: ${transaction.invoiceNumber}');
    bytes += generator.text('TGL: ${transaction.createdAt}');
    bytes += generator.hr();

    // Items
    for (final item in items) {
      bytes += generator.text(
        item.productName.toUpperCase(),
        styles: const PosStyles(bold: true),
      );
      bytes += generator.row([
        PosColumn(
          text: '${item.quantity} x ${CurrencyUtils.format(item.priceAtTime)}',
          width: 9,
        ),
        PosColumn(
          text: CurrencyUtils.format(item.priceAtTime * item.quantity),
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();

    // Totals
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: CurrencyUtils.format(transaction.totalAmount),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    bytes += generator.hr();

    // Footer
    bytes += generator.text(
      'TERIMA KASIH',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'ATAS KUNJUNGAN ANDA',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.barcode(
      Barcode.code128(transaction.invoiceNumber.codeUnits),
    );

    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }
}
