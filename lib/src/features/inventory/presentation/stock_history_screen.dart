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
  DateTimeRange? _selectedRange; // Null means "All Time" by default or handle specialized filtering

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
          // Client-side Date Filtering
          final filteredBatches = batches.where((batch) {
            if (_selectedRange == null) return true;
            final Timestamp? ts = batch['timestamp'];
            if (ts == null) return false;
            final date = ts.toDate();
            // Check if date is within start and end (inclusive)
            return date.isAfter(_selectedRange!.start.subtract(const Duration(seconds: 1))) &&
                date.isBefore(_selectedRange!.end.add(const Duration(days: 1)));
          }).toList();

          if (filteredBatches.isEmpty) {
            return const Center(child: Text("No Stock History found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredBatches.length,
            itemBuilder: (context, index) {
              final batch = filteredBatches[index];
              final Timestamp? ts = batch['timestamp'];
              final date = ts?.toDate() ?? DateTime.now();
              final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(date);
              final itemCount = batch['itemCount'] ?? 0;
              final createdBy = batch['createdBy'] ?? 'Admin';

              return Card(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: const Icon(Icons.history, color: Colors.blue),
                  ),
                  title: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("$itemCount items received by $createdBy"),
                  trailing: IconButton(
                    icon: const Icon(Icons.print, color: Colors.green),
                    tooltip: "Print Memo",
                    onPressed: () async {
                      // Fetch details and Print
                      _printBatch(context, ref, batch['id'], createdBy, date);
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text("Error: $e")),
      ),
    );
  }

  Future<void> _printBatch(BuildContext context, WidgetRef ref, String batchId, String user, DateTime date) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch the items exactly as they were recorded
      final items = await ref.read(inventoryRepositoryProvider).getHistoryBatchItems(batchId);

      if (mounted) Navigator.pop(context); // Close loader

      await ReceivingPdfGenerator.generateBatchReceivingMemo(
        products: items,
        receivedBy: user,
        receivingDate: date,
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loader
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}