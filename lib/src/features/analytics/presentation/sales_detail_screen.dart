import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../sales/presentation/pdf_generator.dart';
import '../../sales/data/sales_repository.dart'; // For CartItem class
import '../../inventory/domain/product_model.dart'; // For Product class
import '../data/analytics_repository.dart';

class SalesDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> invoice;

  const SalesDetailScreen({super.key, required this.invoice});

  @override
  ConsumerState<SalesDetailScreen> createState() => _SalesDetailScreenState();
}

class _SalesDetailScreenState extends ConsumerState<SalesDetailScreen> {
  late Future<List<Map<String, dynamic>>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    final invoiceId = widget.invoice['id'] ?? widget.invoice['invoiceId'];
    _itemsFuture = ref.read(analyticsRepositoryProvider).getInvoiceItems(invoiceId);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final invoice = widget.invoice;

    // Parse Invoice Data
    final timestamp = invoice['timestamp'] as Timestamp?;
    final date = timestamp?.toDate() ?? DateTime.now();
    final invoiceId = invoice['id'] ?? 'Unknown';
    final customerName = invoice['customerName'] ?? 'Guest';
    final customerPhone = invoice['customerPhone'] ?? 'N/A';
    final customerAddress = invoice['customerAddress'] ?? 'N/A';

    // Financials
    final totalAmount = (invoice['totalAmount'] ?? 0).toDouble();
    final paidAmount = (invoice['paidAmount'] ?? 0).toDouble();
    final dueAmount = (invoice['dueAmount'] ?? 0).toDouble();
    final totalProfit = (invoice['totalProfit'] ?? 0).toDouble();
    final paymentStatus = invoice['paymentStatus'] ?? 'Cash';

    return Scaffold(
      appBar: AppBar(title: const Text("Invoice Details")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _printPdf(context, invoice, date),
        icon: const Icon(Icons.print),
        label: const Text("Print Invoice", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. INVOICE SUMMARY CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Text("Invoice #$invoiceId", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                  const SizedBox(height: 5),
                  Text(
                    "৳${totalAmount.toStringAsFixed(0)}",
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: dueAmount > 0 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      dueAmount > 0 ? "Due: ৳${dueAmount.toStringAsFixed(0)}" : "Fully Paid",
                      style: TextStyle(fontWeight: FontWeight.bold, color: dueAmount > 0 ? Colors.red : Colors.green),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(DateFormat('dd MMM yyyy • hh:mm a').format(date), style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. CUSTOMER INFO
            _DetailSection(
              title: "Customer Info",
              icon: Icons.person_outline,
              children: [
                _DetailRow(label: "Name", value: customerName),
                _DetailRow(label: "Phone", value: customerPhone),
                _DetailRow(label: "Address", value: customerAddress),
              ],
            ),
            const SizedBox(height: 16),

            // 3. PRODUCT ITEMS LIST (Fetched Async)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _itemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                final items = snapshot.data ?? [];

                return _DetailSection(
                  title: "Items Purchased (${items.length})",
                  icon: Icons.shopping_cart_outlined,
                  children: items.map((item) {
                    final pName = item['productModel'] ?? item['productName'] ?? 'Item';
                    final qty = item['quantity'] ?? 0;
                    final price = item['totalAmount'] ?? 0;
                    final mrp = item['mrp'] ?? 0;
                    final disc = item['discountPercent'] ?? 0;

                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text("${qty}x", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("$pName", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                  Text("MRP: ৳$mrp • Disc: $disc%", style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                                ],
                              ),
                            ),
                            Text("৳$price", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          ],
                        ),
                        Divider(color: isDark ? Colors.white10 : Colors.grey.shade100),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),

            // 4. FINANCIAL SUMMARY (Admin Only)
            _DetailSection(
              title: "Payment Details",
              icon: Icons.receipt_long_rounded,
              color: Colors.orange,
              children: [
                _DetailRow(label: "Total Amount", value: "৳${totalAmount.toStringAsFixed(0)}"),
                _DetailRow(label: "Paid Amount", value: "৳${paidAmount.toStringAsFixed(0)}"),
                _DetailRow(label: "Due Amount", value: "৳${dueAmount.toStringAsFixed(0)}", isBold: true, valueColor: dueAmount > 0 ? Colors.red : Colors.green),
                const Divider(color: Colors.white24),
                _DetailRow(label: "Net Profit (Est.)", value: "৳${totalProfit.toStringAsFixed(0)}", valueColor: Colors.green, isBold: true),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // Helper to re-construct CartItems for PDF
  Future<void> _printPdf(BuildContext context, Map<String, dynamic> invoice, DateTime date) async {
    final itemsData = await _itemsFuture;

    // Convert Map items back to CartItem objects for the PDF generator
    final cartItems = itemsData.map((data) {
      return CartItem(
          product: Product(
            id: data['productId'] ?? '',
            name: data['productName'] ?? '',
            model: data['productModel'] ?? '',
            category: data['category'] ?? '',
            capacity: '', // Info might not be in sale record
            marketPrice: (data['mrp'] ?? 0).toDouble(),
            commissionPercent: 0, // Not needed for customer invoice
            buyingPrice: 0, // Not needed for customer invoice
            currentStock: 0,
          ),
          quantity: (data['quantity'] ?? 1).toInt(),
          discountPercent: (data['discountPercent'] ?? 0).toDouble(),
          finalPrice: (data['totalAmount'] ?? 0).toDouble()
      );
    }).toList();

    if (context.mounted) {
      PdfGenerator.generateBatchInvoice(
        items: cartItems,
        customerName: invoice['customerName'] ?? '',
        customerPhone: invoice['customerPhone'] ?? '',
        customerAddress: invoice['customerAddress'] ?? '',
        paymentStatus: invoice['paymentStatus'] ?? 'Cash',
        paidAmount: (invoice['paidAmount'] ?? 0).toDouble(),
        dueAmount: (invoice['dueAmount'] ?? 0).toDouble(),
        saleDate: date,
      );
    }
  }
}

// ... Reusable Widgets ...
class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color? color;

  const _DetailSection({required this.title, required this.icon, required this.children, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          Row(children: [Icon(icon, size: 20, color: themeColor), const SizedBox(width: 8), Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: themeColor))]),
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
          Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600])),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: valueColor ?? (isDark ? Colors.white : Colors.black87), fontSize: 15)),
        ],
      ),
    );
  }
}