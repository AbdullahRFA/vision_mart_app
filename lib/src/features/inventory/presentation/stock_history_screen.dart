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
          final filteredBatches = batches.where((batch) {
            if (batch['type'] != 'INWARD_CHALLAN') return false;
            if (_selectedRange == null) return true;
            final Timestamp? ts = batch['timestamp'];
            final date = ts?.toDate() ?? DateTime.now();
            return date.isAfter(_selectedRange!.start.subtract(const Duration(seconds: 1))) &&
                date.isBefore(_selectedRange!.end.add(const Duration(days: 1)));
          }).toList();

          if (filteredBatches.isEmpty) {
            return const Center(child: Text("No Stock History found."));
          }

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
                          child: const Icon(Icons.move_to_inbox_rounded, color: Colors.purple),
                        ),
                        title: Text("Received at $timeStr", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        subtitle: Text("$itemCount items by $createdBy", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600])),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_note, color: Colors.blue),
                              tooltip: "View/Edit Items",
                              onPressed: () => _showBatchItems(context, batch['id']),
                            ),
                            IconButton(
                              icon: const Icon(Icons.print, color: Colors.green),
                              tooltip: "Print Memo",
                              onPressed: () => _printBatch(context, ref, batch['id'], createdBy, date),
                            ),
                          ],
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

  void _showBatchItems(BuildContext context, String batchId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BatchItemsSheet(batchId: batchId),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupBatchesByDate(List<Map<String, dynamic>> batches) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var batch in batches) {
      final Timestamp? ts = batch['timestamp'];
      final date = ts?.toDate() ?? DateTime.now();
      final checkDate = DateTime(date.year, date.month, date.day);

      String header;
      if (checkDate == today) header = "Today";
      else if (checkDate == yesterday) header = "Yesterday";
      else header = DateFormat('dd MMM yyyy').format(date);

      if (grouped[header] == null) grouped[header] = [];
      grouped[header]!.add(batch);
    }
    return grouped;
  }

  Future<void> _printBatch(BuildContext context, WidgetRef ref, String batchId, String user, DateTime date) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final items = await ref.read(inventoryRepositoryProvider).getHistoryBatchItems(batchId);
      if (mounted) Navigator.pop(context);
      if (items.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No items found.")));
        return;
      }
      await ReceivingPdfGenerator.generateBatchReceivingMemo(products: items, receivedBy: user, receivingDate: date);
    } catch (e) {
      debugPrint("Error printing batch: $e");
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}

class _BatchItemsSheet extends ConsumerWidget {
  final String batchId;
  const _BatchItemsSheet({required this.batchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.grey.shade50;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          color: bgColor,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: ref.read(inventoryRepositoryProvider).watchHistoryBatchLogs(batchId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text("No items found", style: TextStyle(color: isDark ? Colors.white : Colors.black)));

              final items = snapshot.data!;
              return ListView.separated(
                controller: scrollController,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, index) {
                  final item = items[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                    ),
                    child: ListTile(
                      title: Text(
                        "${item['productModel']} - ${item['productName']}",
                        style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                      ),
                      subtitle: Text(
                        "Qty: ${item['quantityAdded']} | MRP: ${item['marketPrice']} | Comm: ${item['commissionPercent']}%",
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showCorrectionDialog(context, ref, item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(context, ref, item),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  // --- DELETE FUNCTIONALITY ---
  void _confirmDelete(BuildContext context, WidgetRef ref, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Delete Entry?", style: TextStyle(color: Colors.white)),
        content: Text(
          "Deleting this will remove ${item['quantityAdded']} units from stock.\nThis action fails if you have already sold these items.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx); // Close confirmation dialog
              try {
                await ref.read(inventoryRepositoryProvider).deleteStockEntry(
                  logId: item['logId'],
                  productId: item['productId'],
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Entry deleted successfully")),
                  );
                }
              } catch (e) {
                debugPrint("Error deleting stock entry: $e");
                // 👇 SHOW REJECTION POPUP
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (errCtx) => AlertDialog(
                      backgroundColor: const Color(0xFF1E293B),
                      icon: const Icon(Icons.error_outline, color: Colors.red, size: 40),
                      title: const Text("Delete Failed", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      content: Text(
                        e.toString().replaceAll('Exception:', '').trim(),
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(errCtx),
                            child: const Text("OK", style: TextStyle(color: Colors.blue))
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text("Confirm Delete"),
          ),
        ],
      ),
    );
  }

  // --- EDIT FUNCTIONALITY ---
  void _showCorrectionDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> item) {
    final nameCtrl = TextEditingController(text: item['productName']);
    final modelCtrl = TextEditingController(text: item['productModel']);
    final mrpCtrl = TextEditingController(text: item['marketPrice'].toString());
    final commCtrl = TextEditingController(text: item['commissionPercent'].toString());
    final qtyCtrl = TextEditingController(text: item['quantityAdded'].toString());

    InputDecoration getDecor(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.yellow),
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.green), borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.black26,
      );
    }

    final inputStyle = const TextStyle(color: Colors.white, fontWeight: FontWeight.bold);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Correct Mistake", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: modelCtrl, style: inputStyle, decoration: getDecor("Model")),
              const SizedBox(height: 10),
              TextFormField(controller: nameCtrl, style: inputStyle, decoration: getDecor("Name")),
              const SizedBox(height: 10),
              TextFormField(controller: qtyCtrl, style: inputStyle, decoration: getDecor("Quantity"), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: mrpCtrl, style: inputStyle, decoration: getDecor("MRP"), keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: commCtrl, style: inputStyle, decoration: getDecor("Comm %"), keyboardType: TextInputType.number)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.redAccent))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              final newMrp = double.tryParse(mrpCtrl.text) ?? 0;
              final newComm = double.tryParse(commCtrl.text) ?? 0;
              final newQty = int.tryParse(qtyCtrl.text) ?? 0;
              final newBuy = newMrp - (newMrp * (newComm / 100));

              try {
                await ref.read(inventoryRepositoryProvider).correctStockEntry(
                  logId: item['logId'],
                  productId: item['productId'],
                  newName: nameCtrl.text.trim(),
                  newModel: modelCtrl.text.trim(),
                  newMrp: newMrp,
                  newComm: newComm,
                  newBuyingPrice: newBuy,
                  newQuantity: newQty,
                );
                if (context.mounted) {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entry Corrected! Re-open to see changes.")));
                }
              } catch (e) {
                debugPrint("Error correcting stock entry: $e");
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: ${e.toString().replaceAll('Exception:', '')}"), backgroundColor: Colors.red)
                  );
                }
              }
            },
            child: const Text("Save Correction"),
          ),
        ],
      ),
    );
  }
}