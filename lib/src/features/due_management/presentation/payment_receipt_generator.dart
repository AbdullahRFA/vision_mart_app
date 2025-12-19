import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PaymentReceiptGenerator {
  static Future<void> generateReceipt({
    required String customerName,
    required String customerPhone,
    required String productName,
    required double totalDueBefore,
    required double amountPaid,
    required double remainingDue,
  }) async {
    final pdf = pw.Document();
    final date = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6, // Smaller paper size (A6) for receipts
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(10),
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
                      pw.Text("A & R Vision Mart", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text("MONEY RECEIPT", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                      pw.SizedBox(height: 5),
                      pw.Text("Date: $date", style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.Divider(),

                // --- CUSTOMER INFO ---
                pw.Text("Received From: $customerName", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("Phone: $customerPhone"),
                pw.SizedBox(height: 5),
                pw.Text("Ref Product: $productName", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(height: 10),

                // --- PAYMENT DETAILS TABLE ---
                pw.Table.fromTextArray(
                  context: context,
                  border: pw.TableBorder.all(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1),
                  },
                  headers: ['Description', 'Amount (Tk)'],
                  data: [
                    ['Previous Due Amount', totalDueBefore.toStringAsFixed(0)],
                    ['PAID NOW', amountPaid.toStringAsFixed(0)],
                    ['Remaining Balance', remainingDue.toStringAsFixed(0)],
                  ],
                ),

                pw.SizedBox(height: 10),

                // --- AMOUNT IN WORDS (Optional simple logic) ---
                pw.Text("Paid Amount: ${amountPaid.toStringAsFixed(0)} Tk", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),

                pw.Spacer(),

                // --- SIGNATURE ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Container(width: 50, height: 1, color: PdfColors.black),
                        pw.Text("Customer", style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Container(width: 50, height: 1, color: PdfColors.black),
                        pw.Text("Authorized Signature", style: const pw.TextStyle(fontSize: 8)),
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
      name: 'Receipt_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}