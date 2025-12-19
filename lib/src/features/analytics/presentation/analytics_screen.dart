import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/analytics_repository.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesReportProvider);
    final currentRange = ref.watch(dateRangeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Business Report")),
      body: Column(
        children: [
          // 1. HEADER & FILTERS
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                // Date Range Display
                InkWell(
                  onTap: () => _pickDateRange(context, ref),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, color: Theme.of(context).primaryColor, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              "Period",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                            ),
                          ],
                        ),
                        Text(
                          "${DateFormat('dd MMM').format(currentRange.start)} - ${DateFormat('dd MMM').format(currentRange.end)}",
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Filter Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(label: "Today", onTap: () => _setRange(ref, 'Today')),
                      const SizedBox(width: 8),
                      _FilterChip(label: "This Week", onTap: () => _setRange(ref, 'Week')),
                      const SizedBox(width: 8),
                      _FilterChip(label: "This Month", onTap: () => _setRange(ref, 'Month')),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. REPORT CONTENT
          Expanded(
            child: salesAsync.when(
              data: (salesData) {
                // CALCULATIONS
                double totalRevenue = 0;
                double totalProfit = 0;
                int totalItems = 0;

                for (var sale in salesData) {
                  totalRevenue += (sale['totalAmount'] ?? 0);
                  totalProfit += (sale['profit'] ?? 0);
                  totalItems += (sale['quantity'] as num).toInt();
                }

                if (salesData.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart_rounded, size: 80, color: Colors.grey.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text("No sales records found", style: TextStyle(color: Colors.grey.withOpacity(0.8))),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // METRICS ROW 1
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            title: "Net Profit",
                            value: "৳${totalProfit.toStringAsFixed(0)}",
                            color: Colors.green,
                            icon: Icons.trending_up,
                            isHighlighted: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // METRICS ROW 2
                    _MetricCard(
                      title: "Total Items Sold",
                      value: "$totalItems Units",
                      color: Colors.orange,
                      icon: Icons.shopping_bag_outlined,
                      isHorizontal: true,
                    ),

                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Recent Transactions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("${salesData.length} Records", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // TRANSACTIONS LIST
                    ...salesData.map((sale) {
                      final date = (sale['timestamp'] as Timestamp).toDate();
                      final dateStr = DateFormat('dd MMM, hh:mm a').format(date);

                      return _TransactionCard(
                        title: sale['productName'] ?? 'Unknown',
                        subtitle: sale['customerName'] ?? 'Guest',
                        date: dateStr,
                        amount: "৳${sale['totalAmount']}",
                        profit: "৳${(sale['profit'] as num).toStringAsFixed(0)}",
                      );
                    }),
                  ],
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
    );

    if (picked != null) {
      final adjustedStart = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
      final adjustedEnd = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      ref.read(dateRangeProvider.notifier).state = DateTimeRange(start: adjustedStart, end: adjustedEnd);
    }
  }
}

// --- WIDGETS ---

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final bool isHighlighted;
  final bool isHorizontal;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.isHighlighted = false,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlighted
            ? color
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: isHighlighted ? null : Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isHighlighted ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isHorizontal
          ? Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600], fontSize: 12)),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHighlighted ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: isHighlighted ? Colors.white : color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: isHighlighted ? Colors.white.withOpacity(0.9) : (isDark ? Colors.white60 : Colors.grey[600]),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isHighlighted ? Colors.white : (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String date;
  final String amount;
  final String profit;

  const _TransactionCard({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.amount,
    required this.profit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text("$subtitle • $date", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "+$profit",
                  style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}