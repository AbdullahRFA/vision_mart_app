import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/expense_repository.dart';
import '../domain/expense_model.dart';

class ExpenseScreen extends ConsumerWidget {
  const ExpenseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseAsync = ref.watch(expenseStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate Totals for Header
    double totalExpense = 0;
    expenseAsync.whenData((expenses) {
      for (var e in expenses) totalExpense += e.amount;
    });

    return Scaffold(
      appBar: AppBar(title: const Text("Business Expenses")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(context, ref),
        label: const Text("Add Expense"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. Summary Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFF991B1B)], // Red Gradient
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5)),
              ],
            ),
            child: Column(
              children: [
                const Text("Total Expenses Recorded",
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 5),
                Text(
                  "৳${totalExpense.toStringAsFixed(0)}",
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ],
            ),
          ),

          // 2. Grouped Expense List
          Expanded(
            child: expenseAsync.when(
              data: (expenses) {
                if (expenses.isEmpty) {
                  return Center(
                      child: Text("No expenses found.",
                          style: TextStyle(color: Colors.grey[600])));
                }

                // 👇 Group the expenses by date
                final groupedExpenses = _groupExpenses(expenses);

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: groupedExpenses.entries.map((entry) {
                    final dateHeader = entry.key;
                    final dailyExpenses = entry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- DATE HEADER ---
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
                          child: Text(
                            dateHeader,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white54 : Colors.grey[700],
                              letterSpacing: 1,
                            ),
                          ),
                        ),

                        // --- EXPENSE ITEMS FOR THIS DATE ---
                        ...dailyExpenses.map((expense) {
                          return Card(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red.withOpacity(0.1),
                                child: Icon(_getIconForCategory(expense.category),
                                    color: Colors.red),
                              ),
                              title: Text(expense.category,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                // Show Time instead of Date here since Date is in header
                                "${DateFormat('hh:mm a').format(expense.date)} • ${expense.note}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "-৳${expense.amount.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                        fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  // Edit
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        size: 20, color: Colors.blue),
                                    onPressed: () => _showEditExpenseDialog(
                                        context, ref, expense),
                                  ),
                                  // Delete
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 20, color: Colors.grey),
                                    onPressed: () => _confirmDelete(
                                        context, ref, expense.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  // 👇 GROUPING LOGIC
  Map<String, List<Expense>> _groupExpenses(List<Expense> expenses) {
    final grouped = <String, List<Expense>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    for (var expense in expenses) {
      final date = expense.date;
      final checkDate = DateTime(date.year, date.month, date.day);

      String header;
      if (checkDate == today) {
        header = "Today";
      } else if (checkDate == yesterday) {
        header = "Yesterday";
      } else if (checkDate == tomorrow) {
        header = "Tomorrow";
      } else {
        header = DateFormat('dd MMM yyyy').format(date);
      }

      if (grouped[header] == null) {
        grouped[header] = [];
      }
      grouped[header]!.add(expense);
    }
    return grouped;
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Shop Rent':
        return Icons.store;
      case 'Electric Bill':
        return Icons.bolt;
      case 'Transport Cost':
        return Icons.local_shipping;
      case 'Food Cost':
        return Icons.restaurant;
      case 'Salary':
        return Icons.people;
      default:
        return Icons.money_off;
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Expense?"),
        content: const Text("Are you sure? This cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              ref.read(expenseRepositoryProvider).deleteExpense(id);
              Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context, WidgetRef ref) {
    _showExpenseDialog(context, ref, null);
  }

  void _showEditExpenseDialog(BuildContext context, WidgetRef ref, Expense expense) {
    _showExpenseDialog(context, ref, expense);
  }

  // 👇 Unified Dialog for Add & Edit
  void _showExpenseDialog(BuildContext context, WidgetRef ref, Expense? expense) {
    final isEditing = expense != null;
    final formKey = GlobalKey<FormState>();

    // Controllers
    final amountCtrl = TextEditingController(text: isEditing ? expense.amount.toString() : '');
    final noteCtrl = TextEditingController(text: isEditing ? expense.note : '');

    String selectedCategory = isEditing ? expense.category : 'Shop Rent';
    DateTime selectedDate = isEditing ? expense.date : DateTime.now();

    final categories = [
      'Shop Rent', 'Electric Bill', 'Transport Cost',
      'Food Cost', 'Salary', 'Maintenance', 'Other'
    ];

    // Handle "Other" categories if custom data was saved previously
    if (!categories.contains(selectedCategory)) {
      selectedCategory = 'Other';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? "Edit Expense" : "Add New Expense"),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedCategory = v!),
                    decoration: const InputDecoration(
                        labelText: "Category", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: "Amount (Tk)", border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                        labelText: "Note (Optional)", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text("Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}"),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030), // Allow future dates
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                try {
                  if (isEditing) {
                    await ref.read(expenseRepositoryProvider).updateExpense(
                      id: expense.id,
                      category: selectedCategory,
                      amount: double.parse(amountCtrl.text),
                      note: noteCtrl.text.trim(),
                      date: selectedDate,
                    );
                  } else {
                    await ref.read(expenseRepositoryProvider).addExpense(
                      category: selectedCategory,
                      amount: double.parse(amountCtrl.text),
                      note: noteCtrl.text.trim(),
                      date: selectedDate,
                    );
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isEditing ? "Expense Updated" : "Expense Added")));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                  }
                }
              },
              child: Text(isEditing ? "Update" : "Save"),
            ),
          ],
        ),
      ),
    );
  }
}