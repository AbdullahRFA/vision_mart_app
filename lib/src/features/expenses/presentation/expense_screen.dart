import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/expense_repository.dart';
import '../domain/expense_model.dart';
import 'expense_pdf_generator.dart';
import 'add_batch_expense_screen.dart'; // 👈 Import new screen

class ExpenseScreen extends ConsumerStatefulWidget {
  const ExpenseScreen({super.key});

  @override
  ConsumerState<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends ConsumerState<ExpenseScreen> {
  String _selectedFilter = 'This Month'; // Default view
  DateTime? _customDate;

  final List<String> _filters = [
    'Today',
    'This Week',
    'This Month',
    'This Year',
    'Custom',
    'All Time'
  ];

  // Logic to filter expenses based on selection
  List<Expense> _applyFilter(List<Expense> allExpenses) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return allExpenses.where((e) {
      final date = e.date;
      final checkDate = DateTime(date.year, date.month, date.day);

      switch (_selectedFilter) {
        case 'Today':
          return checkDate == today;
        case 'This Week':
          final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
          return date.isAfter(startOfWeek.subtract(const Duration(seconds: 1)));
        case 'This Month':
          return date.year == now.year && date.month == now.month;
        case 'This Year':
          return date.year == now.year;
        case 'Custom':
          if (_customDate == null) return false;
          final target = DateTime(_customDate!.year, _customDate!.month, _customDate!.day);
          return checkDate == target;
        case 'All Time':
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _printExpenses() async {
    final expenseAsync = ref.read(expenseStreamProvider);

    expenseAsync.whenData((allExpenses) {
      final filtered = _applyFilter(allExpenses);
      if (filtered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No expenses to print for this period.")),
        );
        return;
      }

      double total = filtered.fold(0, (sum, e) => sum + e.amount);
      String periodLabel = _selectedFilter;
      if (_selectedFilter == 'Custom' && _customDate != null) {
        periodLabel = DateFormat('dd MMM yyyy').format(_customDate!);
      }

      ExpensePdfGenerator.generateExpenseReport(
        expenses: filtered,
        periodName: periodLabel,
        totalAmount: total,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final expenseAsync = ref.watch(expenseStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Business Expenses"),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: "Print Report",
            onPressed: _printExpenses,
          ),
        ],
      ),
      // 👇 CHANGED: Navigate to Batch Add Screen
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddBatchExpenseScreen())
        ),
        label: const Text("Add Expense"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. FILTERS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                String label = filter;
                if (filter == 'Custom' && _customDate != null) {
                  label = DateFormat('dd MMM').format(_customDate!);
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: Colors.red.withOpacity(0.2),
                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.redAccent : (isDark ? Colors.white60 : Colors.grey[700]),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(
                        color: isSelected ? Colors.redAccent : Colors.transparent
                    ),
                    onSelected: (bool selected) async {
                      if (filter == 'Custom') {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            _customDate = picked;
                            _selectedFilter = filter;
                          });
                        }
                      } else {
                        if (selected) setState(() => _selectedFilter = filter);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // 2. EXPENSE LIST & SUMMARY
          Expanded(
            child: expenseAsync.when(
              data: (allExpenses) {
                final filteredExpenses = _applyFilter(allExpenses);
                double totalAmount = 0;
                for (var e in filteredExpenses) totalAmount += e.amount;

                return Column(
                  children: [
                    // --- SUMMARY CARD ---
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFF991B1B)],
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
                          Text(
                              _selectedFilter == 'Custom' && _customDate != null
                                  ? "Total Expense (${DateFormat('dd MMM').format(_customDate!)})"
                                  : "Total Expense ($_selectedFilter)",
                              style: const TextStyle(color: Colors.white70, fontSize: 14)
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "৳${totalAmount.toStringAsFixed(0)}",
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    // --- LIST ---
                    Expanded(
                      child: filteredExpenses.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.money_off_rounded, size: 60, color: Colors.grey.withOpacity(0.3)),
                            const SizedBox(height: 10),
                            Text("No expenses found", style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      )
                          : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: _groupExpenses(filteredExpenses, isDark).entries.map((entry) {
                          final header = entry.key;
                          final items = entry.value;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
                                child: Text(
                                  header,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white54 : Colors.grey[700],
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              ...items.map((expense) => _buildExpenseCard(context, ref, expense, isDark)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
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

  // Card Builder
  Widget _buildExpenseCard(BuildContext context, WidgetRef ref, Expense expense, bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.withOpacity(0.1),
          child: Icon(_getIconForCategory(expense.category), color: Colors.red),
        ),
        title: Text(expense.category, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          "${DateFormat('hh:mm a').format(expense.date)} • ${expense.note}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "-৳${expense.amount.toStringAsFixed(0)}",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16),
            ),
            const SizedBox(width: 8),
            // Edit button still uses the single-edit dialog
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
              onPressed: () => _showEditExpenseDialog(context, ref, expense),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
              onPressed: () => _confirmDelete(context, ref, expense.id),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<Expense>> _groupExpenses(List<Expense> expenses, bool isDark) {
    final grouped = <String, List<Expense>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var expense in expenses) {
      final date = expense.date;
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
      grouped[header]!.add(expense);
    }
    return grouped;
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Shop Rent': return Icons.store;
      case 'Electric Bill': return Icons.bolt;
      case 'Transport Cost': return Icons.local_shipping;
      case 'Food Cost': return Icons.restaurant;
      case 'Salary': return Icons.people;
      default: return Icons.money_off;
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Expense?"),
        content: const Text("Are you sure? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
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

  // KEEPING EDIT DIALOG FOR SINGLE EDITS
  void _showEditExpenseDialog(BuildContext context, WidgetRef ref, Expense expense) {
    _showExpenseDialog(context, ref, expense);
  }

  void _showExpenseDialog(BuildContext context, WidgetRef ref, Expense? expense) {
    final isEditing = expense != null;
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController(text: isEditing ? expense.amount.toString() : '');
    final noteCtrl = TextEditingController(text: isEditing ? expense.note : '');

    String selectedCategory = isEditing ? expense.category : 'Shop Rent';
    DateTime selectedDate = isEditing ? expense.date : DateTime.now();

    final categories = ['Shop Rent', 'Electric Bill', 'Transport Cost', 'Food Cost', 'Salary', 'Maintenance', 'Other'];
    if (!categories.contains(selectedCategory)) selectedCategory = 'Other';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? "Edit Expense" : "Add Expense"),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => selectedCategory = v!),
                    decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Amount (Tk)", border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: "Note (Optional)", border: OutlineInputBorder()),
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
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                try {
                  await ref.read(expenseRepositoryProvider).updateExpense(
                    id: expense!.id,
                    category: selectedCategory,
                    amount: double.parse(amountCtrl.text),
                    note: noteCtrl.text.trim(),
                    date: selectedDate,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Expense Updated")));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }
}