import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../domain/expense_model.dart';

class ExpensePdfGenerator {
  static Future<void> generateExpenseReport({
    required List<Expense> expenses,
    required String periodName,
    required double totalAmount,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MMM-yyyy hh:mm a').format(now);

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
                  pw.Text("A & R Vision Mart", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Address: Damnash Bazar, Bagmara, Rajshahi"),
                  pw.Text("Mobile: 01718421902"),
                  pw.SizedBox(height: 8),
                  pw.Text("EXPENSE REPORT", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                  pw.SizedBox(height: 4),
                  pw.Text("Period: $periodName", style: const pw.TextStyle(fontSize: 12)),
                  pw.Divider(),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // --- REPORT INFO ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Generated: $dateStr", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.Text("Total Records: ${expenses.length}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
            pw.SizedBox(height: 10),

            // --- TABLE ---
            pw.Table.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: PdfColors.grey400),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FixedColumnWidth(80), // Date
                1: const pw.FlexColumnWidth(2),   // Category
                2: const pw.FlexColumnWidth(3),   // Note
                3: const pw.FixedColumnWidth(70), // Amount
              },
              headers: ['Date', 'Category', 'Note', 'Amount (Tk)'],
              data: expenses.map((e) {
                return [
                  DateFormat('dd-MMM-yy').format(e.date),
                  e.category,
                  e.note,
                  e.amount.toStringAsFixed(0),
                ];
              }).toList(),
            ),

            pw.SizedBox(height: 10),

            // --- TOTAL SUMMARY ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    color: PdfColors.grey200,
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text("Total Expense: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text("${totalAmount.toStringAsFixed(0)} Tk", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),

            pw.Spacer(),
            pw.Divider(),
            pw.Center(
              child: pw.Text("A & R Vision Mart - Accounts Department", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Expense_Report_${now.millisecondsSinceEpoch}',
    );
  }
}