import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/analytics_repository.dart';
import 'sales_detail_screen.dart';

// 👇 Changed to ConsumerStatefulWidget to hold local filter state
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  // 👇 State for Profit/Loss Filter
  String _profitFilter = 'All'; // Options: 'All', 'Profit', 'Loss'

  void _setRange(WidgetRef ref, String type) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (type == 'Today') {
      start = DateTime(now.year, now.month, now.day, 0, 0, 0);
    } else if (type == 'Week') {
      start = now.subtract(Duration(days: now.weekday - 1));
      start = DateTime(start.year, start.month, start.day, 0, 0, 0);
    } else if (type == 'Month') {
      start = DateTime(now.year, now.month, 1, 0, 0, 0);
    } else if (type == 'Year') {
      start = DateTime(now.year, 1, 1, 0, 0, 0);
    } else if (type == 'All') {
      start = DateTime(2020, 1, 1, 0, 0, 0);
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
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.yellow,
              onPrimary: Colors.black,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final adjustedStart = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
      final adjustedEnd = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      ref.read(dateRangeProvider.notifier).state = DateTimeRange(start: adjustedStart, end: adjustedEnd);
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesReportProvider);
    final currentRange = ref.watch(dateRangeProvider);

    // Enforcing Dark Background to support White/Yellow text
    const backgroundColor = Color(0xFF0F172A);
    const cardColor = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Business Report", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: backgroundColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. HEADER & FILTERS
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: const BoxDecoration(
              color: cardColor,
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              children: [
                // Date Range Display
                InkWell(
                  onTap: () => _pickDateRange(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.yellow.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.yellow.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, color: Colors.yellow, size: 20),
                            SizedBox(width: 10),
                            Text("Period", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.yellow)),
                          ],
                        ),
                        Text(
                          "${DateFormat('dd MMM').format(currentRange.start)} - ${DateFormat('dd MMM').format(currentRange.end)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Filter Pills (Date)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(label: "Today", onTap: () => _setRange(ref, 'Today')),
                      const SizedBox(width: 8),
                      _FilterChip(label: "This Week", onTap: () => _setRange(ref, 'Week')),
                      const SizedBox(width: 8),
                      _FilterChip(label: "This Month", onTap: () => _setRange(ref, 'Month')),
                      const SizedBox(width: 8),
                      _FilterChip(label: "This Year", onTap: () => _setRange(ref, 'Year')),
                      const SizedBox(width: 8),
                      _FilterChip(label: "All Time", onTap: () => _setRange(ref, 'All')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 👇 NEW: Profit/Loss Filter Toggles
                Row(
                  children: [
                    Expanded(
                      child: _ProfitFilterButton(
                        label: "All Sales",
                        isSelected: _profitFilter == 'All',
                        color: Colors.blue,
                        onTap: () => setState(() => _profitFilter = 'All'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ProfitFilterButton(
                        label: "Profit Only",
                        isSelected: _profitFilter == 'Profit',
                        color: Colors.green,
                        onTap: () => setState(() => _profitFilter = 'Profit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ProfitFilterButton(
                        label: "Loss Only",
                        isSelected: _profitFilter == 'Loss',
                        color: Colors.red,
                        onTap: () => setState(() => _profitFilter = 'Loss'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. REPORT CONTENT
          Expanded(
            child: salesAsync.when(
              data: (allInvoices) {
                // Filter 1: Only show fully paid (existing logic)
                var invoices = allInvoices.where((invoice) {
                  final due = (invoice['dueAmount'] ?? 0).toDouble();
                  return due <= 0.5;
                }).toList();

                // 👇 Filter 2: Profit/Loss Toggle
                if (_profitFilter != 'All') {
                  invoices = invoices.where((invoice) {
                    final profit = (invoice['totalProfit'] ?? 0).toDouble();
                    if (_profitFilter == 'Profit') return profit > 0;
                    if (_profitFilter == 'Loss') return profit <= 0; // Assuming 0 or less is loss/break-even
                    return true;
                  }).toList();
                }

                double totalRevenue = 0;
                double totalProfit = 0;
                int totalOrders = invoices.length;

                for (var invoice in invoices) {
                  totalRevenue += (invoice['totalAmount'] ?? 0);
                  totalProfit += (invoice['totalProfit'] ?? 0);
                }

                if (invoices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 80, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text(
                            _profitFilter == 'All'
                                ? "No fully paid records found"
                                : "No $_profitFilter records found",
                            style: TextStyle(color: Colors.white.withOpacity(0.5))
                        ),
                      ],
                    ),
                  );
                }

                final groupedTransactions = _groupTransactions(invoices);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // METRICS ROW 1
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            title: "Revenue (Cash)",
                            // 👇 Changed to 2 decimal places
                            value: "৳${totalRevenue.toStringAsFixed(2)}",
                            color: Colors.green, // Revenue is Green
                            icon: Icons.attach_money,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            title: "Net Profit",
                            // 👇 Changed to 2 decimal places
                            value: "৳${totalProfit.toStringAsFixed(2)}",
                            color: totalProfit < 0 ? Colors.red : Colors.green, // Green/Red Logic
                            icon: totalProfit < 0 ? Icons.trending_down : Icons.trending_up,
                            isHighlighted: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // METRICS ROW 2
                    _MetricCard(
                      title: "Completed Orders",
                      value: "$totalOrders",
                      color: Colors.yellow, // Count is Yellow
                      icon: Icons.receipt_long,
                      isHorizontal: true,
                    ),

                    const SizedBox(height: 25),

                    // RENDER TRANSACTIONS
                    ...groupedTransactions.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.yellow // Header Yellow
                              ),
                            ),
                          ),
                          ...entry.value.map((invoice) {
                            final date = (invoice['timestamp'] as Timestamp).toDate();
                            final timeStr = DateFormat('hh:mm a').format(date);
                            final itemCount = invoice['itemCount'] ?? 1;

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SalesDetailScreen(invoice: invoice),
                                  ),
                                );
                              },
                              child: _TransactionCard(
                                title: invoice['customerName'] ?? 'Unknown',
                                subtitle: "Invoice #...${invoice['id'].toString().substring(invoice['id'].toString().length - 4)} • $itemCount items",
                                date: timeStr,
                                // 👇 Changed to 2 decimal places
                                amount: "৳${(invoice['totalAmount'] as num).toDouble().toStringAsFixed(2)}",
                                // 👇 Changed to 2 decimal places
                                profit: "৳${(invoice['totalProfit'] as num).toDouble().toStringAsFixed(2)}",
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                    const SizedBox(height: 20),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.yellow)),
              error: (e, s) => Center(child: Text("Error: $e", style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Group by Date
  Map<String, List<Map<String, dynamic>>> _groupTransactions(List<Map<String, dynamic>> sales) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var sale in sales) {
      final date = (sale['timestamp'] as Timestamp).toDate();
      final checkDate = DateTime(date.year, date.month, date.day);

      String headerKey;
      if (checkDate == today) headerKey = "Today";
      else if (checkDate == yesterday) headerKey = "Yesterday";
      else headerKey = DateFormat('dd MMM yyyy').format(date);

      if (grouped[headerKey] == null) grouped[headerKey] = [];
      grouped[headerKey]!.add(sale);
    }
    return grouped;
  }
}

// 👇 NEW: Filter Button Widget
class _ProfitFilterButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ProfitFilterButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.white24,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.white60,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: isHighlighted ? Border.all(color: color, width: 2) : Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
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
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
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
              color: isHighlighted ? color : Colors.white,
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
    // Parse profit string to double for coloring
    final double profitVal = double.tryParse(profit.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0;
    final isLoss = profitVal < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.yellow, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                const SizedBox(height: 2),
                Text("$subtitle • $date", style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isLoss ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  // Show +/- sign based on profit value
                  "${profitVal > 0 ? '+' : ''}${profit}",
                  style: TextStyle(
                    fontSize: 10,
                    color: isLoss ? Colors.red.shade400 : Colors.green.shade400,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}