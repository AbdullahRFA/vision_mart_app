import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../domain/product_model.dart';

class ReceivingPdfGenerator {

  // 1. SINGLE ITEM (Legacy/Optional)
  static Future<void> generateReceivingMemo({
    required String productName,
    required String model,
    required String category,
    required int quantity,
    required double mrp,
    required double buyingPrice,
    required String receivedBy,
    required DateTime date, // 👈 Added Date
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd-MMM-yyyy hh:mm a').format(date);

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
                      pw.Text("INWARD CHALLAN", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text("Address: Damnash Bazar, Bagmara, Rajshahi", style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 5),
                      pw.Text("Date: $dateStr", style: const pw.TextStyle(fontSize: 10)),
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
      name: 'Stock_In_${date.millisecondsSinceEpoch}',
    );
  }

  // 2. BATCH GENERATOR (Main)
  static Future<void> generateBatchReceivingMemo({
    required List<Product> products,
    required String receivedBy,
    required DateTime receivingDate, // 👈 NEW: Enforce passed date
  }) async {
    final pdf = pw.Document();
    // Use the passed date for the PDF text
    final dateStr = DateFormat('dd-MMM-yyyy hh:mm a').format(receivingDate);

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
            // --- HEADER ---
            pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text("A & R Vision Mart", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Authorized Dealer: Vision Electronics"),
                    pw.Text("Address: Damnash Bazar, Bagmara, Rajshahi"),
                    pw.Text("Mobile: 01718421902"),
                    pw.SizedBox(height: 5),
                    pw.Text("BATCH INWARD CHALLAN", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Divider(),
                  ],
                )
            ),
            pw.SizedBox(height: 10),

            // Date Row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // 👈 Using the passed dateStr
                pw.Text("Receiving Date: $dateStr"),
                pw.Text("User: $receivedBy", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 20),

            // --- TABLE ---
            pw.Table.fromTextArray(
              context: context,
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.center,
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
              headers: ['SL', 'Category', 'Model / Name', 'Qty', 'MRP', 'Comm %', 'Unit Cost', 'Total'],
              data: List<List<dynamic>>.generate(products.length, (index) {
                final p = products[index];
                final lineTotal = p.buyingPrice * p.currentStock;
                return [
                  '${index + 1}',
                  p.category,
                  '${p.model}\n${p.name}',
                  '${p.currentStock}',
                  p.marketPrice.toStringAsFixed(0),
                  '${p.commissionPercent.toStringAsFixed(0)}%',
                  p.buyingPrice.toStringAsFixed(0),
                  lineTotal.toStringAsFixed(0),
                ];
              }),
            ),

            pw.SizedBox(height: 10),

            // --- TOTALS ---
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

            pw.Spacer(),

            // --- SIGNATURES ---
            pw.SizedBox(height: 30),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _buildSignatureLine("Received By"),
                _buildSignatureLine("Store In-Charge"),
                _buildSignatureLine("Authorized Signature"),
              ],
            ),

            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Center(
              child: pw.Text("Inventory Management System - A & R Vision Mart", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700, fontSize: 10)),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Batch_Challan_${receivingDate.millisecondsSinceEpoch}',
    );
  }

  static pw.Widget _buildSignatureLine(String title) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 100,
          height: 1,
          color: PdfColors.black,
        ),
        pw.SizedBox(height: 5),
        pw.Text(
            title,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)
        ),
      ],
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