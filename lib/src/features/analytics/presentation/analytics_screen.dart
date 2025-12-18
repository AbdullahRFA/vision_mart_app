import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/analytics_repository.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySalesAsync = ref.watch(todaySalesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Business")),
      body: todaySalesAsync.when(
        data: (salesData) {
          // 1. Calculate Totals Locally
          double totalRevenue = 0;
          double totalProfit = 0;
          int totalItems = 0;

          for (var sale in salesData) {
            totalRevenue += (sale['totalAmount'] ?? 0);
            totalProfit += (sale['profit'] ?? 0);
            totalItems += (sale['quantity'] as num).toInt();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // METRICS ROW
                Row(
                  children: [
                    // 👇 FIX: Wrap in Expanded HERE, not inside the widget
                    Expanded(
                      child: _MetricCard(
                        title: "Total Sales",
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

                // 👇 FIX: Use full width here instead of Expanded
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
                const Text("Today's Transactions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                // TRANSACTION LIST
                if (salesData.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text("No sales yet today.")),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: salesData.length,
                    itemBuilder: (context, index) {
                      final sale = salesData[index];
                      return Card(
                        child: ListTile(
                          title: Text(sale['productName'] ?? 'Unknown'),
                          subtitle: Text("Sold to: ${sale['customerName']}"),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("৳${sale['totalAmount']}", style: const TextStyle(fontWeight: FontWeight.bold)),
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
    );
  }
}

// 👇 FIX: REMOVED 'Expanded' from inside this widget
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // Just return the Container. Let the parent decide sizing.
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