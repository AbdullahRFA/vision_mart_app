import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 Added this for Timestamp
import '../data/analytics_repository.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Watch the Report Provider (It updates automatically when date changes)
    final salesAsync = ref.watch(salesReportProvider);
    final currentRange = ref.watch(dateRangeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Business Report")),
      body: Column(
        children: [
          // --- FILTER CONTROLS ---
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue.withOpacity(0.05),
            child: Column(
              children: [
                // Date Range Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Period:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      "${DateFormat('dd MMM').format(currentRange.start)} - ${DateFormat('dd MMM').format(currentRange.end)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Filter Buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterBtn(label: "Today", onTap: () => _setRange(ref, 'Today')),
                      const SizedBox(width: 8),
                      _FilterBtn(label: "This Week", onTap: () => _setRange(ref, 'Week')),
                      const SizedBox(width: 8),
                      _FilterBtn(label: "This Month", onTap: () => _setRange(ref, 'Month')),
                      const SizedBox(width: 8),
                      _FilterBtn(label: "Custom", icon: Icons.calendar_today, onTap: () => _pickDateRange(context, ref)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- REPORT CONTENT ---
          Expanded(
            child: salesAsync.when(
              data: (salesData) {
                // CALCULATE TOTALS
                double totalRevenue = 0;
                double totalProfit = 0;
                int totalItems = 0;

                for (var sale in salesData) {
                  totalRevenue += (sale['totalAmount'] ?? 0);
                  totalProfit += (sale['profit'] ?? 0);
                  totalItems += (sale['quantity'] as num).toInt();
                }

                if (salesData.isEmpty) {
                  return const Center(child: Text("No records found for this period."));
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // METRICS CARDS
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: "Revenue",
                              value: "৳${totalRevenue.toStringAsFixed(0)}",
                              color: Colors.blue,
                              icon: Icons.attach_money,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricCard(
                              title: "Net Profit",
                              value: "৳${totalProfit.toStringAsFixed(0)}",
                              color: Colors.green,
                              icon: Icons.trending_up,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: _MetricCard(
                          title: "Items Sold",
                          value: "$totalItems Units",
                          color: Colors.orange,
                          icon: Icons.shopping_bag,
                        ),
                      ),

                      const SizedBox(height: 25),
                      Text("Transactions (${salesData.length})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),

                      // LIST OF TRANSACTIONS
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: salesData.length,
                        itemBuilder: (context, index) {
                          final sale = salesData[index];
                          // Format Timestamp safely
                          final date = (sale['timestamp'] as Timestamp).toDate();
                          final dateStr = DateFormat('dd MMM, hh:mm a').format(date);

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade50,
                                child: const Icon(Icons.receipt_long, color: Colors.blue),
                              ),
                              title: Text(sale['productName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("$dateStr\nCustomer: ${sale['customerName']}"),
                              isThreeLine: true,
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("৳${sale['totalAmount']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(
                                    "Profit: ৳${(sale['profit'] as num).toStringAsFixed(0)}",
                                    style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text("Error: $e")),
            ),
          ),
        ],
      ),
    );
  }

  // --- LOGIC: DATE HELPERS ---

  void _setRange(WidgetRef ref, String type) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (type == 'Today') {
      start = DateTime(now.year, now.month, now.day, 0, 0, 0);
    } else if (type == 'Week') {
      start = now.subtract(Duration(days: now.weekday));
      start = DateTime(start.year, start.month, start.day, 0, 0, 0);
    } else if (type == 'Month') {
      start = DateTime(now.year, now.month, 1, 0, 0, 0);
    } else {
      return;
    }

    ref.read(dateRangeProvider.notifier).state = DateTimeRange(start: start, end: end);
  }

  Future<void> _pickDateRange(BuildContext context, WidgetRef ref) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      currentDate: DateTime.now(),
      saveText: 'DONE',
    );

    if (picked != null) {
      // Adjust times to cover the full days
      final adjustedStart = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
      final adjustedEnd = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);

      ref.read(dateRangeProvider.notifier).state = DateTimeRange(start: adjustedStart, end: adjustedEnd);
    }
  }
}

// --- HELPER WIDGETS ---

class _FilterBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  const _FilterBtn({required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: Colors.grey.shade700), const SizedBox(width: 4)],
            Text(label, style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricCard({required this.title, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}