import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfGenerator {
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
    final pdf = pw.Document();
    final date = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text("A & R Vision Mart", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Authorized Dealer: Vision Electronics"),
                    pw.Text("Address: Damnash Bazar, Bagmara, Rajshahi"), // Placeholder
                    pw.Text("Mobile: 01718421902"), // Placeholder
                    pw.Divider(),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // --- INVOICE DETAILS ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Date: $date"),
                  pw.Text("Invoice #: ${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}"),
                ],
              ),
              pw.SizedBox(height: 15),

              // --- CUSTOMER INFO ---
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

              // --- PRODUCT TABLE ---
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
                headers: ['Product', 'Model', 'Qty', 'MRP', 'Discount', 'Total'],
                data: [
                  [
                    productName,
                    productModel,
                    quantity.toString(),
                    mrp.toStringAsFixed(0),
                    '${discountPercent.toStringAsFixed(0)}%',
                    finalPrice.toStringAsFixed(0)
                  ]
                ],
              ),

              pw.SizedBox(height: 20),

              // --- TOTALS ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Grand Total:  ${finalPrice.toStringAsFixed(0)} Tk",
                          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
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

              // --- FOOTER ---
              pw.Divider(),
              pw.Center(
                child: pw.Text("Thank you for choosing A & R Vision Mart!",
                    style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
              ),
            ],
          );
        },
      ),
    );

    // This opens the Print Preview / Share Sheet
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}