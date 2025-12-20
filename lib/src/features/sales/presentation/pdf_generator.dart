import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../data/sales_repository.dart'; // Import for CartItem

class PdfGenerator {

  // 1. RE-PRINT INVOICE (From Sales History)
  // Matches the call from SalesDetailScreen
  static Future<void> generateInvoice({
    required String invoiceId,
    required String customerName,
    required String customerPhone,
    String customerAddress = '', // Optional for history re-print
    required List<Map<String, dynamic>> products, // Accepts List of Maps
    required double totalAmount,
    required double paidAmount,
    required double dueAmount,
    required double discount,
    required DateTime date,
  }) async {
    final pdf = pw.Document();
    final formattedDate = DateFormat('dd-MMM-yyyy hh:mm a').format(date);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // --- Header ---
            _buildHeader(),
            pw.SizedBox(height: 10),

            // --- Invoice Info ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Date: $formattedDate"),
                pw.Text("Invoice #: $invoiceId", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 10),

            // --- Customer Info ---
            _buildCustomerSection(customerName, customerPhone, customerAddress),
            pw.SizedBox(height: 20),

            // --- Items Table ---
            pw.Table.fromTextArray(
              context: context,
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
              headers: ['SL', 'Product', 'Model', 'Qty', 'Price', 'Total'],
              columnWidths: {
                0: const pw.FixedColumnWidth(30),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FixedColumnWidth(40),
                4: const pw.FixedColumnWidth(60),
                5: const pw.FixedColumnWidth(70),
              },
              data: List<List<dynamic>>.generate(products.length, (index) {
                final item = products[index];
                return [
                  '${index + 1}',
                  item['name'] ?? '',
                  item['model'] ?? '',
                  item['qty'].toString(),
                  (item['price'] as double).toStringAsFixed(0),
                  (item['total'] as double).toStringAsFixed(0),
                ];
              }),
            ),

            pw.SizedBox(height: 10),

            // --- Totals ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (discount > 0)
                      pw.Text("Discount:  - ${discount.toStringAsFixed(0)} Tk"),

                    pw.SizedBox(height: 5),
                    pw.Text("Grand Total:  ${totalAmount.toStringAsFixed(0)} Tk", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),

                    pw.SizedBox(height: 5),
                    pw.Text("Paid:  ${paidAmount.toStringAsFixed(0)} Tk"),

                    if (dueAmount > 0)
                      pw.Text("Due:  ${dueAmount.toStringAsFixed(0)} Tk", style: pw.TextStyle(color: PdfColors.red, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),

            pw.Spacer(),
            pw.SizedBox(height: 30),

            // --- Signatures ---
            _buildSignatureSection(),

            pw.SizedBox(height: 20),
            pw.Divider(),
            _buildFooter(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_$invoiceId',
    );
  }

  // 2. BATCH INVOICE (New Sale)
  // Matches the call from SellProductScreen
  static Future<void> generateBatchInvoice({
    required List<CartItem> items,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String paymentStatus,
    DateTime? saleDate, // 👈 New Parameter for Manual Date
  }) async {
    final pdf = pw.Document();

    // 👇 Use the passed saleDate if available, otherwise use now.
    final dateToUse = saleDate ?? DateTime.now();
    final dateStr = DateFormat('dd-MMM-yyyy hh:mm a').format(dateToUse);

    // Generate Invoice ID based on the specific date/time
    final invoiceId = dateToUse.millisecondsSinceEpoch.toString().substring(6);

    double grandTotal = 0;
    for (var i in items) grandTotal += i.finalPrice;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            _buildHeader(),
            pw.SizedBox(height: 10),

            // Invoice Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Date: $dateStr"), // Display the selected date
                pw.Text("Invoice #: $invoiceId", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 10),

            // Customer Info
            _buildCustomerSection(customerName, customerPhone, customerAddress),
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
            pw.SizedBox(height: 30),

            // Signatures
            _buildSignatureSection(),

            pw.SizedBox(height: 20),
            pw.Divider(),
            _buildFooter(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_$invoiceId',
    );
  }

  // --- Common Widgets ---

  static pw.Widget _buildHeader() {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text("A & R Vision Mart", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.Text("Authorized Dealer: Vision Electronics"),
          pw.Text("Address: Damnash Bazar, Bagmara, Rajshahi"),
          pw.Text("Mobile: 01718421902"),
          pw.Divider(),
        ],
      ),
    );
  }

  static pw.Widget _buildCustomerSection(String name, String phone, String address) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text("Customer: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(name),
              pw.Spacer(),
              pw.Text("Phone: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(phone.isEmpty ? "N/A" : phone),
            ],
          ),
          if (address.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Row(
              children: [
                pw.Text("Address: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(address),
              ],
            ),
          ]
        ],
      ),
    );
  }

  static pw.Widget _buildSignatureSection() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _buildSignatureLine("Customer Signature"),
        _buildSignatureLine("Sales Operator"),
        _buildSignatureLine("Sales Manager"),
      ],
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Center(
      child: pw.Text("Thank you for choosing A & R Vision Mart!", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
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
}