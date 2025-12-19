import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/due_repository.dart';
import 'payment_receipt_generator.dart';

class DueScreen extends ConsumerWidget {
  const DueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This 'context' is the PARENT context. It stays alive even if items disappear.
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

          // Calculate Total OUTSTANDING
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
                  // 👇 CHANGED: Renamed 'context' to 'itemContext' to avoid confusion
                  itemBuilder: (itemContext, index) {
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 1. AVATAR
                            CircleAvatar(
                              backgroundColor: Colors.red.withOpacity(0.1),
                              radius: 24,
                              child: const Icon(Icons.history_edu, color: Colors.red),
                            ),

                            const SizedBox(width: 12),

                            // 2. CUSTOMER INFO
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
                                Text(
                                  "Due: ৳${remainingDue.toStringAsFixed(0)}",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                                Text(
                                  "Total: ৳${totalAmount.toStringAsFixed(0)}",
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),

                                // 👇 CHANGED: Passing the PARENT 'context', not 'itemContext'
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
        title: Text("Receive Payment\n${sale['customerName']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Remaining Due: ৳${remainingDue.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 15),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Enter Amount Received",
                border: OutlineInputBorder(),
                prefixText: "৳ ",
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _quickAmountBtn(amountController, 500),
                _quickAmountBtn(amountController, 1000),
                // FULL PAYMENT BUTTON
                InkWell(
                  onTap: () => amountController.text = remainingDue.toStringAsFixed(0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(5)),
                    child: const Text("FULL", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0 || amount > remainingDue) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invalid Amount! Check value.")),
                );
                return;
              }

              Navigator.pop(ctx); // Close Input Dialog

              try {
                // 1. Process Payment
                await ref.read(dueRepositoryProvider).receivePayment(
                  saleId: sale['saleId'],
                  currentPaidAmount: (sale['paidAmount'] ?? 0).toDouble(),
                  totalOrderAmount: (sale['totalAmount'] ?? 0).toDouble(),
                  amountPayingNow: amount,
                );

                // 2. Show Success & Ask to Print
                // using 'context' here is safe now because it refers to the Parent Scaffold,
                // which is still mounted even if the list item is gone.
                if (context.mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (printCtx) => AlertDialog(
                      title: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 10),
                          Text("Payment Successful!"),
                        ],
                      ),
                      content: Text(
                          amount >= (remainingDue - 0.1)
                              ? "The due has been FULLY CLEARED.\nGenerate Receipt?"
                              : "Partial payment recorded.\nGenerate Receipt?"
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(printCtx),
                          child: const Text("No"),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.print),
                          label: const Text("Print Receipt"),
                          onPressed: () {
                            Navigator.pop(printCtx);

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

  Widget _quickAmountBtn(TextEditingController controller, int amount) {
    return InkWell(
      onTap: () => controller.text = amount.toString(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(5)),
        child: Text("৳$amount"),
      ),
    );
  }
}