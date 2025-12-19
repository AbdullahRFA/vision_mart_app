import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../data/sales_repository.dart'; // Import for CartItem

class PdfGenerator {

  // Existing Single Invoice (Keep or Remove)
  static Future<void> generateInvoice({
    required String customerName,
    required String customerPhone,
    required String productName,
    required String productModel,
    required int quantity,
    required double mrp,
    required double discountPercent,
    required double finalPrice,
    required String paymentStatus,
  }) async {
    // ... (Existing code) ...
    // Since we are moving to batch, you can technically route this to the batch function too
  }

  // 👇 NEW: Batch Invoice Generator
  static Future<void> generateBatchInvoice({
    required List<CartItem> items,
    required String customerName,
    required String customerPhone,
    required String paymentStatus,
  }) async {
    final pdf = pw.Document();
    final date = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());
    final invoiceId = DateTime.now().millisecondsSinceEpoch.toString().substring(6);

    double grandTotal = 0;
    for (var i in items) grandTotal += i.finalPrice;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text("A & R Vision Mart", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Authorized Dealer: Vision Electronics"),
                  pw.Text("Address: Damnash Bazar, Bagmara, Rajshahi"),
                  pw.Text("Mobile: 01718421902"),
                  pw.Divider(),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Invoice Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Date: $date"),
                pw.Text("Invoice #: $invoiceId", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 10),

            // Customer Info
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
              child: pw.Row(
                  children: [
                    pw.Text("Customer: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(customerName),
                    pw.Spacer(),
                    pw.Text("Phone: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(customerPhone.isEmpty ? "N/A" : customerPhone),
                  ]
              ),
            ),
            pw.SizedBox(height: 20),

            // Items Table
            pw.Table.fromTextArray(
              context: context,
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
              headers: ['SL', 'Product', 'Model', 'Qty', 'MRP', 'Disc', 'Total'],
              columnWidths: {
                0: const pw.FixedColumnWidth(30),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FixedColumnWidth(40),
                4: const pw.FixedColumnWidth(50),
                5: const pw.FixedColumnWidth(40),
                6: const pw.FixedColumnWidth(60),
              },
              data: List<List<dynamic>>.generate(items.length, (index) {
                final item = items[index];
                return [
                  '${index + 1}',
                  item.product.name,
                  item.product.model,
                  item.quantity.toString(),
                  item.product.marketPrice.toStringAsFixed(0),
                  '${item.discountPercent.toStringAsFixed(0)}%',
                  item.finalPrice.toStringAsFixed(0),
                ];
              }),
            ),

            pw.SizedBox(height: 10),

            // Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Grand Total:  ${grandTotal.toStringAsFixed(0)} Tk", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 5),
                    pw.Text("Payment Status:  $paymentStatus",
                        style: pw.TextStyle(
                            color: paymentStatus == 'Due' ? PdfColors.red : PdfColors.green,
                            fontWeight: pw.FontWeight.bold
                        )
                    ),
                  ],
                ),
              ],
            ),

            pw.Spacer(),

            // Footer
            pw.Divider(),
            pw.Center(
              child: pw.Text("Thank you for choosing A & R Vision Mart!", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_$invoiceId',
    );
  }
}