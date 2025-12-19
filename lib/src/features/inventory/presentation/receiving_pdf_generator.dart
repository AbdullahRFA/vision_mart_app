import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class ReceivingPdfGenerator {
  static Future<void> generateReceivingMemo({
    required String productName,
    required String model,
    required String category,
    required int quantity,
    required double mrp,
    required double buyingPrice,
    required String receivedBy, // e.g., "Admin" or email
  }) async {
    final pdf = pw.Document();
    final date = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5, // A5 is good for internal memos
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // --- HEADER ---
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text("A & R Vision Mart", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                      pw.Text("INWARD CHALLAN / RECEIVING MEMO", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Text("Date: $date", style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.Divider(),

                // --- PRODUCT DETAILS ---
                pw.SizedBox(height: 10),
                pw.Text("Product Details:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                pw.SizedBox(height: 10),

                _buildRow("Product Name:", productName),
                _buildRow("Model Number:", model),
                _buildRow("Category:", category),
                _buildRow("Quantity Received:", "$quantity Units"),

                pw.SizedBox(height: 10),
                // 👇 CHANGED: Removed 'style' parameter. Using standard divider.
                pw.Divider(color: PdfColors.grey, thickness: 0.5),
                pw.SizedBox(height: 10),

                // --- PRICING (INTERNAL USE) ---
                pw.Text("Costing Details (Internal):", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                pw.SizedBox(height: 10),

                _buildRow("Market Price (MRP):", "${mrp.toStringAsFixed(0)} Tk"),
                _buildRow("Unit Buying Price:", "${buyingPrice.toStringAsFixed(0)} Tk"),
                pw.SizedBox(height: 5),
                _buildRow("Total Stock Value:", "${(buyingPrice * quantity).toStringAsFixed(0)} Tk", isBold: true),

                pw.Spacer(),

                // --- FOOTER ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Received By:", style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(receivedBy, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Container(width: 80, height: 1, color: PdfColors.black),
                        pw.Text("Store Manager Sig.", style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Stock_In_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  static pw.Widget _buildRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 12)),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}