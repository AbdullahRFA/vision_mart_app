import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../sales/presentation/pdf_generator.dart';
import '../../sales/data/sales_repository.dart';
import '../../inventory/domain/product_model.dart';
import '../data/analytics_repository.dart';
import '../../sales/presentation/sell_product_screen.dart';

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

  void _navigateToEdit() async {
    final items = await _itemsFuture;
    if (!mounted) return;

    Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SellProductScreen(
            existingInvoice: widget.invoice,
            existingItems: items
        ))
    );
  }

  // 👇 NEW: Confirm & Delete Logic
  void _confirmDelete() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Invoice?"),
        content: const Text("This will permanently remove this sale record and RESTORE stock quantity to inventory.\n\nAre you sure?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white60 : Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteInvoice();
            },
            child: const Text("Delete & Restore Stock"),
          )
        ],
      ),
    );
  }

  Future<void> _deleteInvoice() async {
    try {
      final invoiceId = widget.invoice['id'] ?? widget.invoice['invoiceId'];
      // Call Repository to delete and restore stock
      await ref.read(salesRepositoryProvider).deleteInvoice(invoiceId);

      if (mounted) {
        Navigator.pop(context); // Exit Detail Screen
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invoice Deleted & Stock Restored")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final invoice = widget.invoice;

    final timestamp = invoice['timestamp'] as Timestamp?;
    final date = timestamp?.toDate() ?? DateTime.now();
    final invoiceId = invoice['id'] ?? 'Unknown';
    final customerName = invoice['customerName'] ?? 'Guest';
    final customerPhone = invoice['customerPhone'] ?? 'N/A';
    final customerAddress = invoice['customerAddress'] ?? 'N/A';

    final totalAmount = (invoice['totalAmount'] ?? 0).toDouble();
    final paidAmount = (invoice['paidAmount'] ?? 0).toDouble();
    final dueAmount = (invoice['dueAmount'] ?? 0).toDouble();
    final totalProfit = (invoice['totalProfit'] ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Invoice Details"),
        actions: [
          // Edit Button
          IconButton(
            icon: const Icon(Icons.edit_note, color: Colors.orange),
            tooltip: "Correct Mistake (Edit)",
            onPressed: _navigateToEdit,
          ),
          // 👇 NEW: Delete Button
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            tooltip: "Delete Sale",
            onPressed: _confirmDelete,
          ),
        ],
      ),
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
                  // 👇 Updated to 2 decimal places
                  Text(
                    "৳${totalAmount.toStringAsFixed(2)}",
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: dueAmount > 0.01 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    // 👇 Updated to 2 decimal places
                    child: Text(
                      dueAmount > 0.01 ? "Due: ৳${dueAmount.toStringAsFixed(2)}" : "Fully Paid",
                      style: TextStyle(fontWeight: FontWeight.bold, color: dueAmount > 0.01 ? Colors.red : Colors.green),
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
                    final price = (item['totalAmount'] ?? 0).toDouble();
                    final mrp = (item['mrp'] ?? 0).toDouble();
                    // 👇 Ensure Double for Formatting
                    final disc = (item['discountPercent'] ?? 0).toDouble();

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
                                  // 👇 Updated MRP and Discount to 2 decimal places
                                  Text("MRP: ৳${mrp.toStringAsFixed(2)} • Disc: ${disc.toStringAsFixed(2)}%", style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                                ],
                              ),
                            ),
                            // 👇 Updated Item Price to 2 decimal places
                            Text("৳${price.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
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

            // 4. FINANCIAL SUMMARY
            _DetailSection(
              title: "Payment Details",
              icon: Icons.receipt_long_rounded,
              color: Colors.orange,
              children: [
                // 👇 Updated all summary rows to 2 decimal places
                _DetailRow(label: "Total Amount", value: "৳${totalAmount.toStringAsFixed(2)}"),
                _DetailRow(label: "Paid Amount", value: "৳${paidAmount.toStringAsFixed(2)}"),
                _DetailRow(label: "Due Amount", value: "৳${dueAmount.toStringAsFixed(2)}", isBold: true, valueColor: dueAmount > 0.01 ? Colors.red : Colors.green),
                const Divider(color: Colors.white24),
                _DetailRow(label: "Net Profit (Est.)", value: "৳${totalProfit.toStringAsFixed(2)}", valueColor: Colors.green, isBold: true),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Future<void> _printPdf(BuildContext context, Map<String, dynamic> invoice, DateTime date) async {
    final itemsData = await _itemsFuture;

    final cartItems = itemsData.map((data) {
      return CartItem(
          product: Product(
            id: data['productId'] ?? '',
            name: data['productName'] ?? '',
            model: data['productModel'] ?? '',
            category: data['category'] ?? '',
            capacity: '',
            marketPrice: (data['mrp'] ?? 0).toDouble(),
            commissionPercent: 0,
            buyingPrice: 0,
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