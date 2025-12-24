import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/inventory_repository.dart';
import 'receiving_pdf_generator.dart';

class StockHistoryScreen extends ConsumerStatefulWidget {
  const StockHistoryScreen({super.key});

  @override
  ConsumerState<StockHistoryScreen> createState() => _StockHistoryScreenState();
}

class _StockHistoryScreenState extends ConsumerState<StockHistoryScreen> {
  DateTimeRange? _selectedRange;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(stockHistoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Stock History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedRange = picked);
            },
            tooltip: "Filter by Date",
          ),
          if (_selectedRange != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _selectedRange = null),
            )
        ],
      ),
      body: historyAsync.when(
        data: (batches) {
          // 1. Client-side Filtering
          final filteredBatches = batches.where((batch) {
            if (batch['type'] != 'INWARD_CHALLAN') return false;
            if (_selectedRange == null) return true;

            final Timestamp? ts = batch['timestamp'];
            final date = ts?.toDate() ?? DateTime.now();

            return date.isAfter(
                _selectedRange!.start.subtract(const Duration(seconds: 1))) &&
                date.isBefore(
                    _selectedRange!.end.add(const Duration(days: 1)));
          }).toList();

          if (filteredBatches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off,
                      size: 60, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 10),
                  const Text("No Stock History found"),
                ],
              ),
            );
          }

          // 2. Group by Date
          final groupedBatches = _groupBatchesByDate(filteredBatches);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedBatches.length,
            itemBuilder: (context, index) {
              final dateHeader = groupedBatches.keys.elementAt(index);
              final dayBatches = groupedBatches[dateHeader]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
                    child: Text(
                      dateHeader,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.grey[700],
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  // List of Batches for this Date
                  ...dayBatches.map((batch) {
                    final Timestamp? ts = batch['timestamp'];
                    final date = ts?.toDate() ?? DateTime.now();
                    final timeStr = DateFormat('hh:mm a').format(date);
                    final itemCount = batch['itemCount'] ?? 0;
                    final createdBy = batch['createdBy'] ?? 'Admin';

                    return Card(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple.withOpacity(0.1),
                          child:
                          const Icon(Icons.move_to_inbox_rounded, color: Colors.purple),
                        ),
                        title: Text(
                          "Received at $timeStr",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87),
                        ),
                        subtitle: Text(
                          "$itemCount items by $createdBy",
                          style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.grey[600]),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.print, color: Colors.green),
                          tooltip: "Print Memo",
                          onPressed: () async {
                            _printBatch(
                                context, ref, batch['id'], createdBy, date);
                          },
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text("Error: $e")),
      ),
    );
  }

  // Helper to group items map keys
  Map<String, List<Map<String, dynamic>>> _groupBatchesByDate(
      List<Map<String, dynamic>> batches) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var batch in batches) {
      final Timestamp? ts = batch['timestamp'];
      final date = ts?.toDate() ?? DateTime.now();
      final checkDate = DateTime(date.year, date.month, date.day);

      String header;
      if (checkDate == today) {
        header = "Today";
      } else if (checkDate == yesterday) {
        header = "Yesterday";
      } else {
        header = DateFormat('dd MMM yyyy').format(date);
      }

      if (grouped[header] == null) grouped[header] = [];
      grouped[header]!.add(batch);
    }
    return grouped;
  }

  Future<void> _printBatch(BuildContext context, WidgetRef ref, String batchId,
      String user, DateTime date) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final items = await ref
          .read(inventoryRepositoryProvider)
          .getHistoryBatchItems(batchId);

      if (mounted) Navigator.pop(context); // Close loader

      if (items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No items found for this batch.")));
        }
        return;
      }

      await ReceivingPdfGenerator.generateBatchReceivingMemo(
        products: items,
        receivedBy: user,
        receivingDate: date,
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loader
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}