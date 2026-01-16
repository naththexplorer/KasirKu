import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../data/local/db/app_database.dart';
import '../utils/currency_utils.dart';

class ReceiptService {
  /// Generates a PNG image of the receipt (for sharing via WhatsApp, Instagram, etc.)
  /// Uses a fixed pixel width with dynamic height to prevent cropping.
  static Future<Uint8List> generateReceiptImage({
    required Shop shop,
    required Transaction transaction,
    required List<TransactionItem> items,
    bool is80mm = false,
  }) async {
    // Generate PDF first
    final pdfBytes = await generateReceiptPdf(
      shop: shop,
      transaction: transaction,
      items: items,
      is80mm: is80mm,
    );

    // Convert PDF to image using thermal printer DPI (203 standard)
    // Using 300 DPI causes black images - 203 DPI is correct for thermal printers
    final pagesStream = Printing.raster(pdfBytes, dpi: 203);

    // Get the first (and only) page from the stream
    final page = await pagesStream.first;
    final image = await page.toPng();

    return image;
  }

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

    // --- PHYSICAL MM-BASED DIMENSIONS ---
    // Use exact thermal printer paper sizes in millimeters
    final double paperWidthMm = is80mm ? 80.0 : 58.0;
    final double paperWidth = paperWidthMm * PdfPageFormat.mm;

    // Font sizes in mm (scaled proportionally to paper width)
    // Reference: 58mm width as baseline
    final double h1 =
        (3.6 / 58.0) * paperWidthMm * PdfPageFormat.mm; // Shop name
    final double h2 =
        (2.4 / 58.0) * paperWidthMm * PdfPageFormat.mm; // Product name
    final double std =
        (2.1 / 58.0) * paperWidthMm * PdfPageFormat.mm; // Headers/totals
    final double tiny =
        (1.8 / 58.0) * paperWidthMm * PdfPageFormat.mm; // Metadata

    final font = pw.Font.courier();
    final fontBold = pw.Font.courierBold();

    // Load KasirKu logo
    final logoData = await rootBundle.load('lib/core/constants/KasirKu.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    // --- DYNAMIC HEIGHT CALCULATION (in mm) ---
    double calculateHeight() {
      double h = 0;
      h += 20 * PdfPageFormat.mm; // Logo + spacing
      h += 25 * PdfPageFormat.mm; // Header section
      h += 15 * PdfPageFormat.mm; // Metadata section
      h += items.length * (8 * PdfPageFormat.mm); // Items (dynamic)
      h += 20 * PdfPageFormat.mm; // Totals section
      h += 12 * PdfPageFormat.mm; // Payment section
      h += 30 * PdfPageFormat.mm; // Footer + Barcode + Padding

      // Minimum height for short receipts (~100mm)
      final minHeight = 100 * PdfPageFormat.mm;
      return h < minHeight ? minHeight : h;
    }

    final totalHeight = calculateHeight();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          paperWidth,
          totalHeight,
          marginAll: 0, // No margin - prevents all cropping
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // --- KASIRKU LOGO ---
              pw.Image(
                logoImage,
                width:
                    paperWidthMm * 0.4 * PdfPageFormat.mm, // 40% of paper width
                height: paperWidthMm * 0.4 * PdfPageFormat.mm,
              ),
              pw.SizedBox(height: 3 * PdfPageFormat.mm),

              // --- HEADER ---
              pw.Text(
                shop.name.toUpperCase(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: fontBold, fontSize: h1),
              ),
              if (shop.address != null)
                pw.Padding(
                  padding: pw.EdgeInsets.only(top: 2 * PdfPageFormat.mm),
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

              pw.SizedBox(height: 4 * PdfPageFormat.mm),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 3 * PdfPageFormat.mm),

              // --- METADATA ---
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'INV:',
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

              pw.SizedBox(height: 3 * PdfPageFormat.mm),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 3 * PdfPageFormat.mm),

              // --- ITEMS (Stacked Layout) ---
              ...items.map(
                (item) => pw.Padding(
                  padding: pw.EdgeInsets.only(bottom: 2 * PdfPageFormat.mm),
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

              pw.SizedBox(height: 3 * PdfPageFormat.mm),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 3 * PdfPageFormat.mm),

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

              pw.SizedBox(height: 2 * PdfPageFormat.mm),
              _buildCleanRow(
                'TOTAL',
                CurrencyUtils.format(transaction.totalAmount),
                fontBold,
                h1,
              ),

              pw.SizedBox(height: 4 * PdfPageFormat.mm),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 3 * PdfPageFormat.mm),

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

              pw.SizedBox(height: 6 * PdfPageFormat.mm),

              // --- FOOTER ---
              pw.Text(
                'TERIMA KASIH',
                style: pw.TextStyle(font: fontBold, fontSize: std),
              ),
              pw.Text(
                'ATAS KUNJUNGAN ANDA',
                style: pw.TextStyle(font: font, fontSize: tiny),
              ),

              pw.SizedBox(height: 5 * PdfPageFormat.mm),

              // Proportional Barcode
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: transaction.invoiceNumber,
                width: paperWidthMm * 0.7 * PdfPageFormat.mm,
                height: 8 * PdfPageFormat.mm,
                drawText: false,
              ),
              pw.SizedBox(height: 4 * PdfPageFormat.mm),
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
