import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/due_repository.dart';
import 'payment_receipt_generator.dart'; // 👈 1. Import This
class DueScreen extends ConsumerWidget {
  const DueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueListAsync = ref.watch(dueStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Due List (Khata)")),
      body: dueListAsync.when(
        data: (dues) {
          if (dues.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 60, color: Colors.green),
                  SizedBox(height: 10),
                  Text("No pending dues! Great job.", style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          // Calculate Total OUTSTANDING (Not just total sales)
          double totalOutstanding = 0;
          for (var item in dues) {
            double total = (item['totalAmount'] ?? 0).toDouble();
            double paid = (item['paidAmount'] ?? 0).toDouble();
            totalOutstanding += (total - paid);
          }

          return Column(
            children: [
              // Summary Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: Colors.red.shade50,
                child: Column(
                  children: [
                    const Text("Total Outstanding Amount", style: TextStyle(color: Colors.red)),
                    Text(
                      "৳${totalOutstanding.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ],
                ),
              ),

              // The List
              Expanded(
                child: ListView.builder(
                  itemCount: dues.length,
                  // ... inside ListView.builder
                  itemBuilder: (context, index) {
                    final sale = dues[index];

                    final double totalAmount = (sale['totalAmount'] ?? 0).toDouble();
                    final double paidAmount = (sale['paidAmount'] ?? 0).toDouble();
                    final double remainingDue = totalAmount - paidAmount;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center, // Vertically center content
                          children: [
                            // 1. AVATAR
                            CircleAvatar(
                              backgroundColor: Colors.red.withOpacity(0.1),
                              radius: 24,
                              child: const Icon(Icons.history_edu, color: Colors.red),
                            ),

                            const SizedBox(width: 12),

                            // 2. CUSTOMER INFO (Expanded to take available width)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sale['customerName'] ?? 'Unknown',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text("Ph: ${sale['customerPhone'] ?? 'N/A'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text("Item: ${sale['productName']}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),

                            // 3. RIGHT SIDE: MONEY & BUTTON
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Money Info
                                Text(
                                  "Due: ৳${remainingDue.toStringAsFixed(0)}",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                                Text(
                                  "Total: ৳${totalAmount.toStringAsFixed(0)}",
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),

                                // "Receive Pay" Button
                                InkWell(
                                  onTap: () => _showPaymentDialog(context, ref, sale, remainingDue),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.payment, color: Colors.white, size: 14),
                                        SizedBox(width: 4),
                                        Text("PAY NOW", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
                  },
// ...
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
      builder: (ctx) => AlertDialog(
        title: Text("Receive Payment from ${sale['customerName']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Remaining Due: ৳$remainingDue"),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Enter Amount",
                border: OutlineInputBorder(),
                prefixText: "৳ ",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0 || amount > remainingDue) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invalid Amount! Cannot be more than due.")),
                );
                return;
              }

              Navigator.pop(ctx); // Close Input Dialog logic

              // 1. Process Payment in Firebase
              await ref.read(dueRepositoryProvider).receivePayment(
                saleId: sale['saleId'],
                currentPaidAmount: (sale['paidAmount'] ?? 0).toDouble(),
                totalOrderAmount: (sale['totalAmount'] ?? 0).toDouble(),
                amountPayingNow: amount,
              );

              // 2. Show Success & Ask to Print
              if (context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (printCtx) => AlertDialog(
                    title: const Text("Payment Received!"),
                    content: const Text("Do you want to print the Money Receipt?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(printCtx), // Close
                        child: const Text("No"),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print),
                        label: const Text("Print Receipt"),
                        onPressed: () {
                          Navigator.pop(printCtx); // Close Dialog

                          // 3. Generate PDF
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
            },
            child: const Text("Confirm Payment"),
          )
        ],
      ),
    );
  }
}




