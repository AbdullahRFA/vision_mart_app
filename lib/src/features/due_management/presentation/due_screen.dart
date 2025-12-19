import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/due_repository.dart';
import 'payment_receipt_generator.dart';

class DueScreen extends ConsumerWidget {
  const DueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueListAsync = ref.watch(dueStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Due List (Khata)")),
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

          // Calculate Total OUTSTANDING
          double totalOutstanding = 0;
          for (var item in dues) {
            double total = (item['totalAmount'] ?? 0).toDouble();
            double paid = (item['paidAmount'] ?? 0).toDouble();
            totalOutstanding += (total - paid);
          }

          return Column(
            children: [
              // 1. FINANCIAL SUMMARY CARD
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFB91C1C)], // Red 500 -> Red 700
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

              // 2. THE LIST
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: dues.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final sale = dues[index];
                    final double totalAmount = (sale['totalAmount'] ?? 0).toDouble();
                    final double paidAmount = (sale['paidAmount'] ?? 0).toDouble();
                    final double remainingDue = totalAmount - paidAmount;

                    return _DueCard(
                      sale: sale,
                      remainingDue: remainingDue,
                      totalAmount: totalAmount,
                      onPay: () => _showPaymentDialog(context, ref, sale, remainingDue),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
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
                      "Remaining Due: ৳${remainingDue.toStringAsFixed(0)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
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
                  onTap: () => amountController.text = remainingDue.toStringAsFixed(0),
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
              if (amount <= 0 || amount > remainingDue) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invalid Amount! Check value."), behavior: SnackBarBehavior.floating),
                );
                return;
              }

              Navigator.pop(ctx);

              try {
                await ref.read(dueRepositoryProvider).receivePayment(
                  saleId: sale['saleId'],
                  currentPaidAmount: (sale['paidAmount'] ?? 0).toDouble(),
                  totalOrderAmount: (sale['totalAmount'] ?? 0).toDouble(),
                  amountPayingNow: amount,
                );

                if (context.mounted) {
                  _showSuccessDialog(context, amount, remainingDue, sale);
                }
              } catch (e) {
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

  void _showSuccessDialog(BuildContext context, double amount, double remainingDue, Map<String, dynamic> sale) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (printCtx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
        title: const Text("Payment Successful!"),
        content: Text(
          amount >= (remainingDue - 0.1)
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
                productName: sale['productName'],
                totalDueBefore: remainingDue,
                amountPaid: amount,
                remainingDue: remainingDue - amount,
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
  final VoidCallback onPay;

  const _DueCard({
    required this.sale,
    required this.remainingDue,
    required this.totalAmount,
    required this.onPay,
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.red.withOpacity(0.1),
              child: const Icon(Icons.history_edu_rounded, color: Colors.red),
            ),
            const SizedBox(width: 16),

            // Info
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
                    "Item: ${sale['productName']}",
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.grey[400]),
                  ),
                ],
              ),
            ),

            // Money & Action
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