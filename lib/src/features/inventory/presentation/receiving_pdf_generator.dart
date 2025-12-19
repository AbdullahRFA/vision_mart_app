import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../domain/product_model.dart';

class ReceivingPdfGenerator {

  // Existing single item generator (unchanged)
  static Future<void> generateReceivingMemo({
    required String productName,
    required String model,
    required String category,
    required int quantity,
    required double mrp,
    required double buyingPrice,
    required String receivedBy,
  }) async {
    final pdf = pw.Document();
    final date = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
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
                pw.SizedBox(height: 10),
                _buildRow("Product Name:", productName),
                _buildRow("Model Number:", model),
                _buildRow("Category:", category),
                _buildRow("Quantity Received:", "$quantity Units", isBold: true),
                pw.Divider(color: PdfColors.grey, thickness: 0.5),
                _buildRow("Total Stock Value:", "${(buyingPrice * quantity).toStringAsFixed(0)} Tk", isBold: true),
                pw.Spacer(),
                pw.Text("Received By: $receivedBy", style: const pw.TextStyle(fontSize: 10)),
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

  // 👇 UPDATED: Batch Generator with MRP & Commission columns
  static Future<void> generateBatchReceivingMemo({
    required List<Product> products,
    required String receivedBy,
  }) async {
    final pdf = pw.Document();
    final date = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());

    // Calculate Totals
    int totalQty = 0;
    double totalValue = 0;
    for (var p in products) {
      totalQty += p.currentStock;
      totalValue += (p.buyingPrice * p.currentStock);
    }

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
                    pw.Text("A & R Vision Mart", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.Text("BATCH INWARD CHALLAN", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 5),
                    pw.Text("Date: $date"),
                  ],
                )
            ),
            pw.SizedBox(height: 20),

            // Table
            pw.Table.fromTextArray(
              context: context,
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.center,
              // Adjusted widths to fit new columns
              columnWidths: {
                0: const pw.FixedColumnWidth(25), // SL
                1: const pw.FlexColumnWidth(1.5), // Category
                2: const pw.FlexColumnWidth(2.5), // Model/Name
                3: const pw.FixedColumnWidth(30), // Qty
                4: const pw.FixedColumnWidth(40), // MRP
                5: const pw.FixedColumnWidth(35), // Comm %
                6: const pw.FixedColumnWidth(45), // Unit Cost
                7: const pw.FixedColumnWidth(55), // Total
              },
              // Updated Headers
              headers: ['SL', 'Category', 'Model / Name', 'Qty', 'MRP', 'Comm %', 'Unit Cost', 'Total'],
              // Updated Data Mapping
              data: List<List<dynamic>>.generate(products.length, (index) {
                final p = products[index];
                final lineTotal = p.buyingPrice * p.currentStock;
                return [
                  '${index + 1}',
                  p.category,
                  '${p.model}\n${p.name}',
                  '${p.currentStock}',
                  p.marketPrice.toStringAsFixed(0),        // MRP
                  '${p.commissionPercent.toStringAsFixed(0)}%', // Commission
                  p.buyingPrice.toStringAsFixed(0),        // Unit Price (Buying Price)
                  lineTotal.toStringAsFixed(0),            // Total
                ];
              }),
            ),

            pw.SizedBox(height: 10),

            // Footer Totals
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Total Quantity:  $totalQty Units", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Text("Grand Total Value:  ${totalValue.toStringAsFixed(0)} Tk", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    ],
                  )
                ]
            ),

            pw.SizedBox(height: 50),

            // Signatures
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Received By: $receivedBy", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Container(width: 150, height: 1, color: PdfColors.black, margin: const pw.EdgeInsets.only(top: 5)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text("Authorized Signature", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Container(width: 150, height: 1, color: PdfColors.black, margin: const pw.EdgeInsets.only(top: 5)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Batch_Challan_${DateTime.now().millisecondsSinceEpoch}',
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