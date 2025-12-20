import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../analytics/presentation/sales_detail_screen.dart'; // 👈 Import Detail Screen
import '../data/due_repository.dart';
import 'payment_receipt_generator.dart';

class DueScreen extends ConsumerWidget {
  const DueScreen({super.key});

  @override
  Widget build(BuildContext parentContext, WidgetRef ref) {
    final dueListAsync = ref.watch(dueStreamProvider);
    final isDark = Theme.of(parentContext).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Due List (Invoices)")),
      body: dueListAsync.when(
        data: (dues) {
          if (dues.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.green.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    "No pending dues!",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey[800]),
                  ),
                  Text(
                    "All payments are clear.",
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white30 : Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Calculate Total Outstanding
          double totalOutstanding = 0;
          for (var item in dues) {
            final double due = (item['dueAmount'] ?? 0).toDouble();
            totalOutstanding += due;
          }

          return Column(
            children: [
              // SUMMARY CARD
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      "Total Outstanding Amount",
                      style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "৳${totalOutstanding.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // THE LIST
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: dues.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (itemContext, index) {
                    final invoice = dues[index];
                    final double totalAmount = (invoice['totalAmount'] ?? 0).toDouble();
                    final double paidAmount = (invoice['paidAmount'] ?? 0).toDouble();
                    final double remainingDue = (invoice['dueAmount'] ?? (totalAmount - paidAmount)).toDouble();

                    final int itemCount = (invoice['itemCount'] ?? 1).toInt();
                    final Timestamp? ts = invoice['timestamp'];
                    final dateStr = ts != null ? DateFormat('dd MMM yyyy').format(ts.toDate()) : 'Unknown Date';

                    return _DueCard(
                      sale: invoice,
                      remainingDue: remainingDue,
                      totalAmount: totalAmount,
                      itemCount: itemCount,
                      dateStr: dateStr,
                      // 👇 Navigate to Detail Screen on Tap
                      onTap: () {
                        Navigator.push(
                          parentContext,
                          MaterialPageRoute(
                            builder: (context) => SalesDetailScreen(
                              // Ensure 'id' is passed correctly for the detail screen to fetch items
                              invoice: {
                                ...invoice,
                                'id': invoice['saleId'] ?? invoice['id'],
                              },
                            ),
                          ),
                        );
                      },
                      onPay: () => _showPaymentDialog(parentContext, ref, invoice, remainingDue),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) {
          debugPrint("Due List Error: $e");
          return Center(child: Text('Error: $e'));
        },
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> sale, double remainingDue) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Receive Payment"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Remaining Due: ৳${remainingDue.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: "Amount Received",
                prefixText: "৳ ",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _QuickAmountChip(label: "500", onTap: () => amountController.text = "500"),
                _QuickAmountChip(label: "1000", onTap: () => amountController.text = "1000"),
                _QuickAmountChip(
                  label: "FULL DUE",
                  onTap: () => amountController.text = remainingDue.toStringAsFixed(2),
                  isPrimary: true,
                ),
              ],
            )
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;

              if (amount <= 0 || amount > (remainingDue + 1.0)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Invalid Amount! Max: ${remainingDue.toStringAsFixed(2)}"), behavior: SnackBarBehavior.floating),
                );
                return;
              }

              Navigator.pop(ctx);

              try {
                final isFullPayment = amount >= (remainingDue - 0.1);
                final amountToPay = isFullPayment ? remainingDue : amount;

                await ref.read(dueRepositoryProvider).receivePayment(
                  saleId: sale['saleId'],
                  currentPaidAmount: (sale['paidAmount'] ?? 0).toDouble(),
                  totalOrderAmount: (sale['totalAmount'] ?? 0).toDouble(),
                  amountPayingNow: amountToPay,
                );

                if (context.mounted) {
                  _showSuccessDialog(context, amountToPay, remainingDue, sale);
                }
              } catch (e) {
                debugPrint("Payment Error: $e");
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: const Text("Confirm & Print"),
          )
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, double amountPaid, double totalDueBefore, Map<String, dynamic> sale) {
    double remainingAfter = totalDueBefore - amountPaid;
    if (remainingAfter < 0) remainingAfter = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (printCtx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
        title: const Text("Payment Successful!"),
        content: Text(
          remainingAfter == 0
              ? "The due has been FULLY CLEARED.\nGenerate Receipt?"
              : "Partial payment recorded.\nGenerate Receipt?",
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(printCtx),
            child: const Text("No, Close"),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.print_rounded),
            label: const Text("Print Receipt"),
            onPressed: () {
              Navigator.pop(printCtx);
              PaymentReceiptGenerator.generateReceipt(
                customerName: sale['customerName'],
                customerPhone: sale['customerPhone'] ?? '',
                productName: "Batch Invoice Items",
                totalDueBefore: totalDueBefore,
                amountPaid: amountPaid,
                remainingDue: remainingAfter,
              );
            },
          )
        ],
      ),
    );
  }
}

class _DueCard extends StatelessWidget {
  final Map<String, dynamic> sale;
  final double remainingDue;
  final double totalAmount;
  final int itemCount;
  final String dateStr;
  final VoidCallback onPay;
  final VoidCallback onTap; // 👈 NEW

  const _DueCard({
    required this.sale,
    required this.remainingDue,
    required this.totalAmount,
    required this.itemCount,
    required this.dateStr,
    required this.onPay,
    required this.onTap, // 👈 NEW
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // 👇 Wrap with Material & InkWell for Tap
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap, // 👈 Handle Tap
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.red.withOpacity(0.1),
                  child: const Icon(Icons.receipt_long_rounded, color: Colors.red),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sale['customerName'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone_android_rounded, size: 14, color: isDark ? Colors.white54 : Colors.grey),
                          const SizedBox(width: 4),
                          Text(sale['customerPhone'] ?? 'N/A', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$dateStr • $itemCount items (Batch)",
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Due: ৳${remainingDue.toStringAsFixed(0)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                    ),
                    Text(
                      "Total: ৳${totalAmount.toStringAsFixed(0)}",
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: onPay,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).primaryColor.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.payment_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              "PAY NOW",
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _QuickAmountChip({required this.label, required this.onTap, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: isPrimary ? Border.all(color: Colors.red.withOpacity(0.3)) : null,
        ),
        child: Text(
          isPrimary ? label : "৳$label",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPrimary ? Colors.red : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}