import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/due_repository.dart';

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

          // Calculate Total Due Amount
          double totalDue = dues.fold(0, (sum, item) => sum + (item['totalAmount'] ?? 0));

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
                      "৳${totalDue.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ],
                ),
              ),

              // The List
              Expanded(
                child: ListView.builder(
                  itemCount: dues.length,
                  itemBuilder: (context, index) {
                    final sale = dues[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.redAccent,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(sale['customerName'] ?? 'Unknown'),
                        subtitle: Text("Ph: ${sale['customerPhone'] ?? 'N/A'}\nItem: ${sale['productName']}"),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min, // 👈 1. Important: Stop it from expanding
                          children: [
                            Text(
                              "৳${sale['totalAmount']}",
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red
                              ),
                            ),
                            const SizedBox(height: 2), // 👈 2. Reduced from 5 to 2
                            InkWell(
                              onTap: () => _confirmSettle(context, ref, sale['saleId'], sale['customerName'], sale['totalAmount']),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // 👈 3. Reduced vertical padding
                                decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(5)
                                ),
                                child: const Text(
                                    "MARK PAID",
                                    style: TextStyle(color: Colors.white, fontSize: 10)
                                ),
                              ),
                            )
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

  void _confirmSettle(BuildContext context, WidgetRef ref, String saleId, String name, double amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Payment"),
        content: Text("Did $name pay the full amount of ৳$amount?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              await ref.read(dueRepositoryProvider).settleDue(saleId, amount);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Received!")));
              }
            },
            child: const Text("Yes, Settle It"),
          )
        ],
      ),
    );
  }
}