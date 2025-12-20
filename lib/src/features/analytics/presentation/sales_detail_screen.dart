import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../sales/presentation/pdf_generator.dart';

class SalesDetailScreen extends StatelessWidget {
  final Map<String, dynamic> sale;

  const SalesDetailScreen({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Parse Data
    final date = (sale['timestamp'] as Timestamp).toDate();
    final productName = sale['productName'] ?? 'Unknown Product';
    final customerName = sale['customerName'] ?? 'Guest';
    final customerPhone = sale['customerPhone'] ?? 'N/A';
    // 👈 Retrieve Address (Handle null safely)
    final customerAddress = sale['customerAddress'] ?? 'N/A';

    final totalAmount = (sale['totalAmount'] ?? 0).toDouble();
    final profit = (sale['profit'] ?? 0).toDouble();
    final quantity = (sale['quantity'] ?? 1).toInt();
    final unitPrice = (sale['unitPrice'] ?? 0).toDouble();
    final buyingPrice = (sale['buyingPrice'] ?? 0).toDouble();
    final discount = (sale['discount'] ?? 0).toDouble();
    final invoiceId = sale['invoiceId'] ?? 'INV-${date.millisecondsSinceEpoch}';

    return Scaffold(
      appBar: AppBar(title: const Text("Transaction Details")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          try {
            PdfGenerator.generateInvoice(
              invoiceId: invoiceId,
              customerName: customerName,
              customerPhone: customerPhone,
              customerAddress: customerAddress, // 👈 Pass Address to PDF
              products: [
                {
                  'name': productName,
                  'model': sale['productModel'] ?? '',
                  'qty': quantity,
                  'price': unitPrice,
                  'total': totalAmount + discount,
                }
              ],
              totalAmount: totalAmount,
              paidAmount: totalAmount,
              dueAmount: 0,
              discount: discount,
              date: date,
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error generating PDF: $e")),
            );
          }
        },
        icon: const Icon(Icons.print),
        // 1. WHITE: Button Text
        label: const Text("Print Memo", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green, // Always Green button
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Header Card (Total & Date)
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  // 1. WHITE (faint): Label
                  Text("Total Received", style: TextStyle(color: isDark ? Colors.white60 : Colors.grey)),
                  const SizedBox(height: 8),
                  // 3. GREEN: Total Amount
                  Text(
                    "৳${totalAmount.toStringAsFixed(0)}",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: isDark ? Colors.greenAccent : Colors.green.shade700),
                  ),
                  const SizedBox(height: 8),
                  // 2. YELLOW: Date
                  Text(
                    DateFormat('dd MMM yyyy • hh:mm a').format(date),
                    style: TextStyle(color: isDark ? Colors.yellowAccent : Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Product Details
            _DetailSection(
              title: "Product Info",
              icon: Icons.inventory_2_outlined,
              children: [
                _DetailRow(label: "Product", value: productName),
                _DetailRow(label: "Model", value: sale['productModel'] ?? 'N/A'),
                _DetailRow(label: "Category", value: sale['productCategory'] ?? 'N/A'),
                const Divider(color: Colors.white24),
                _DetailRow(label: "Quantity Sold", value: "$quantity Units"),
                _DetailRow(label: "Selling Price (Unit)", value: "৳${unitPrice.toStringAsFixed(0)}"),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Customer Details
            _DetailSection(
              title: "Customer Info",
              icon: Icons.person_outline,
              children: [
                _DetailRow(label: "Name", value: customerName),
                _DetailRow(label: "Phone", value: customerPhone),
                // 👈 Show Address Row
                _DetailRow(label: "Address", value: customerAddress),
              ],
            ),
            const SizedBox(height: 16),

            // 4. Financial Details
            _DetailSection(
              title: "Financial Analysis (Admin)",
              icon: Icons.analytics_outlined,
              color: isDark ? Colors.orangeAccent : Colors.orange,
              children: [
                _DetailRow(label: "Buying Price (Unit)", value: "৳${buyingPrice.toStringAsFixed(0)}"),
                _DetailRow(label: "Total Cost", value: "৳${(buyingPrice * quantity).toStringAsFixed(0)}"),
                const Divider(color: Colors.white24),
                _DetailRow(
                    label: "Net Profit",
                    value: "৳${profit.toStringAsFixed(0)}",
                    // 3. GREEN: Profit Value
                    valueColor: isDark ? Colors.greenAccent : Colors.green,
                    isBold: true
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color? color;

  const _DetailSection({required this.title, required this.icon, required this.children, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 2. YELLOW: Section Headers (or specific color passed)
    final themeColor = color ?? (isDark ? Colors.yellowAccent : Theme.of(context).primaryColor);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: themeColor),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _DetailRow({required this.label, required this.value, this.valueColor, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. WHITE (faint): Label text
          Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600])),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  // 1. WHITE: Value Text (unless specific color like Green/Red is passed)
                  color: valueColor ?? (isDark ? Colors.white : Colors.black87),
                  fontSize: 15
              ),
            ),
          ),
        ],
      ),
    );
  }
}