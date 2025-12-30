import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../analytics/presentation/sales_detail_screen.dart';
import '../data/due_repository.dart';
import 'payment_receipt_generator.dart';

// 👇 Converted to Stateful Widget for Search State
class DueScreen extends ConsumerStatefulWidget {
  const DueScreen({super.key});

  @override
  ConsumerState<DueScreen> createState() => _DueScreenState();
}

class _DueScreenState extends ConsumerState<DueScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 👇 NEW: Handle Deadline Logic (Set, Edit, Delete)
  void _handleDeadline(String saleId, DateTime? currentDeadline) async {
    final now = DateTime.now();
    final initialDate = currentDeadline ?? now;

    // 1. If deadline exists, ask to Edit or Delete
    if (currentDeadline != null) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Manage Deadline"),
          content: Text("Current Deadline:\n${DateFormat('dd MMM yyyy, hh:mm a').format(currentDeadline)}"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: const Text("Delete Deadline", style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'edit'),
              child: const Text("Change Date"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
          ],
        ),
      );

      if (action == 'delete') {
        await ref.read(dueRepositoryProvider).updatePaymentDeadline(saleId, null);
        return;
      }
      if (action != 'edit') return;
    }

    // 2. Pick Date
    if (!mounted) return;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;

    // 3. Pick Time
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (pickedTime == null) return;

    // 4. Combine & Save
    final finalDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    await ref.read(dueRepositoryProvider).updatePaymentDeadline(saleId, finalDateTime);
  }

  @override
  Widget build(BuildContext context) {
    final dueListAsync = ref.watch(dueStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Due List (Invoices)")),
      body: dueListAsync.when(
        data: (allDues) {
          // 1. FILTER LOGIC
          var dues = allDues;
          if (_searchQuery.isNotEmpty) {
            dues = allDues.where((item) {
              final name = (item['customerName'] ?? '').toString().toLowerCase();
              final phone = (item['customerPhone'] ?? '').toString().toLowerCase();
              final id = (item['saleId'] ?? item['id'] ?? '').toString().toLowerCase();
              return name.contains(_searchQuery) || phone.contains(_searchQuery) || id.contains(_searchQuery);
            }).toList();
          }

          // 2. EMPTY STATE (No Dues at all)
          if (allDues.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.green.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    "No pending dues!",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey[800]),
                  ),
                  Text(
                    "All payments are clear.",
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white30 : Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Calculate Total Outstanding (Based on filtered results)
          double totalOutstanding = 0;
          for (var item in dues) {
            final double due = (item['dueAmount'] ?? 0).toDouble();
            totalOutstanding += due;
          }

          return Column(
            children: [
              // SEARCH BAR
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search Name, Phone or ID...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                ),
              ),

              // SUMMARY CARD
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      _searchQuery.isNotEmpty ? "Outstanding (Filtered)" : "Total Outstanding Amount",
                      style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "৳${totalOutstanding.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // THE LIST
              Expanded(
                child: dues.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 60, color: isDark ? Colors.white24 : Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text("No results found", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                    ],
                  ),
                )
                    : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: dues.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (itemContext, index) {
                    final invoice = dues[index];
                    final double totalAmount = (invoice['totalAmount'] ?? 0).toDouble();
                    final double paidAmount = (invoice['paidAmount'] ?? 0).toDouble();
                    final double remainingDue = (invoice['dueAmount'] ?? (totalAmount - paidAmount)).toDouble();

                    final int itemCount = (invoice['itemCount'] ?? 1).toInt();
                    final Timestamp? ts = invoice['timestamp'];
                    final dateStr = ts != null ? DateFormat('dd MMM yyyy').format(ts.toDate()) : 'Unknown Date';

                    // 👇 Extract Deadline from Firestore Timestamp
                    final Timestamp? deadlineTs = invoice['paymentDeadline'];
                    final DateTime? deadline = deadlineTs?.toDate();

                    return _DueCard(
                      sale: invoice,
                      remainingDue: remainingDue,
                      totalAmount: totalAmount,
                      itemCount: itemCount,
                      dateStr: dateStr,
                      deadline: deadline, // Pass deadline
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SalesDetailScreen(
                              invoice: {
                                ...invoice,
                                'id': invoice['saleId'] ?? invoice['id'],
                              },
                            ),
                          ),
                        );
                      },
                      onPay: () => _showPaymentDialog(context, ref, invoice, remainingDue),
                      onManageDeadline: () => _handleDeadline(invoice['saleId'] ?? invoice['id'], deadline), // Pass callback
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) {
          debugPrint("Due List Error: $e");
          return Center(child: Text('Error: $e'));
        },
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> sale, double remainingDue) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Receive Payment"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Remaining Due: ৳${remainingDue.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: "Amount Received",
                prefixText: "৳ ",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _QuickAmountChip(label: "500", onTap: () => amountController.text = "500"),
                _QuickAmountChip(label: "1000", onTap: () => amountController.text = "1000"),
                _QuickAmountChip(
                  label: "FULL DUE",
                  onTap: () => amountController.text = remainingDue.toStringAsFixed(2),
                  isPrimary: true,
                ),
              ],
            )
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;

              if (amount <= 0 || amount > (remainingDue + 1.0)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Invalid Amount! Max: ${remainingDue.toStringAsFixed(2)}"), behavior: SnackBarBehavior.floating),
                );
                return;
              }

              Navigator.pop(ctx);

              try {
                final isFullPayment = amount >= (remainingDue - 0.1);
                final amountToPay = isFullPayment ? remainingDue : amount;

                await ref.read(dueRepositoryProvider).receivePayment(
                  saleId: sale['saleId'],
                  currentPaidAmount: (sale['paidAmount'] ?? 0).toDouble(),
                  totalOrderAmount: (sale['totalAmount'] ?? 0).toDouble(),
                  amountPayingNow: amountToPay,
                );

                if (context.mounted) {
                  _showSuccessDialog(context, amountToPay, remainingDue, sale);
                }
              } catch (e) {
                debugPrint("Payment Error: $e");
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: const Text("Confirm & Print"),
          )
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, double amountPaid, double totalDueBefore, Map<String, dynamic> sale) {
    double remainingAfter = totalDueBefore - amountPaid;
    if (remainingAfter < 0) remainingAfter = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (printCtx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
        title: const Text("Payment Successful!"),
        content: Text(
          remainingAfter == 0
              ? "The due has been FULLY CLEARED.\nGenerate Receipt?"
              : "Partial payment recorded.\nGenerate Receipt?",
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(printCtx),
            child: const Text("No, Close"),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.print_rounded),
            label: const Text("Print Receipt"),
            onPressed: () {
              Navigator.pop(printCtx);
              PaymentReceiptGenerator.generateReceipt(
                customerName: sale['customerName'],
                customerPhone: sale['customerPhone'] ?? '',
                productName: "Batch Invoice Items",
                totalDueBefore: totalDueBefore,
                amountPaid: amountPaid,
                remainingDue: remainingAfter,
              );
            },
          )
        ],
      ),
    );
  }
}

class _DueCard extends StatelessWidget {
  final Map<String, dynamic> sale;
  final double remainingDue;
  final double totalAmount;
  final int itemCount;
  final String dateStr;
  final DateTime? deadline; // 👈 NEW Parameter
  final VoidCallback onPay;
  final VoidCallback onTap;
  final VoidCallback onManageDeadline; // 👈 NEW Callback

  const _DueCard({
    required this.sale,
    required this.remainingDue,
    required this.totalAmount,
    required this.itemCount,
    required this.dateStr,
    this.deadline,
    required this.onPay,
    required this.onTap,
    required this.onManageDeadline,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.red.withOpacity(0.1),
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.red),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale['customerName'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.phone_android_rounded, size: 14, color: isDark ? Colors.white54 : Colors.grey),
                              const SizedBox(width: 4),
                              Text(sale['customerPhone'] ?? 'N/A', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$dateStr • $itemCount items (Batch)",
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Due: ৳${remainingDue.toStringAsFixed(0)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                        ),
                        Text(
                          "Total: ৳${totalAmount.toStringAsFixed(0)}",
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),

                const Divider(height: 24, color: Colors.grey),

                // 👇 BOTTOM ACTION ROW: Countdown & Pay Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // DEADLINE TIMER SECTION
                    Expanded(
                      child: InkWell(
                        onTap: onManageDeadline,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                          child: deadline == null
                              ? Row(
                            children: [
                              Icon(Icons.timer_outlined, size: 18, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                "Set Deadline",
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          )
                              : _CountdownTimer(deadline: deadline!),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // PAY BUTTON
                    InkWell(
                      onTap: onPay,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).primaryColor.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.payment_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              "PAY NOW",
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 👇 NEW: Real-time Countdown Widget with requested formatting
class _CountdownTimer extends StatefulWidget {
  final DateTime deadline;
  const _CountdownTimer({required this.deadline});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Timer _timer;
  late Duration _diff;

  @override
  void initState() {
    super.initState();
    _calculateDiff();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _calculateDiff();
    });
  }

  void _calculateDiff() {
    setState(() {
      _diff = widget.deadline.difference(DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_diff.isNegative) {
      return Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
          const SizedBox(width: 6),
          const Text(
            "Overdue",
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      );
    }

    // --- CUSTOM CALCULATION FOR YEAR/MONTH/DAY ---
    // Standard Duration does not support Years/Months directly.
    // We calculate the calendar difference accurately.
    DateTime now = DateTime.now();
    DateTime target = widget.deadline;

    int years = target.year - now.year;
    int months = target.month - now.month;
    int days = target.day - now.day;

    if (days < 0) {
      months--;
      // Approximate days in previous month
      final prevMonth = DateTime(target.year, target.month - 1);
      final daysInPrevMonth = DateUtils.getDaysInMonth(prevMonth.year, prevMonth.month);
      days += daysInPrevMonth;
    }

    if (months < 0) {
      years--;
      months += 12;
    }

    // Time parts
    int hours = _diff.inHours % 24;
    int minutes = _diff.inMinutes % 60;
    int seconds = _diff.inSeconds % 60;

    // Build the string: "2 years 3 month 20 day 6 hours 45 minutes and 30 seconds left"
    List<String> parts = [];
    if (years > 0) parts.add("$years years");
    if (months > 0) parts.add("$months month");
    if (days > 0) parts.add("$days day");
    if (hours > 0) parts.add("$hours hours");
    if (minutes > 0) parts.add("$minutes minutes");

    // Always show seconds if it's less than a month away, otherwise optional, but requested format implies full detail.
    String lastPart = "and $seconds seconds left";

    // Just show top 3 significant units to avoid too long string?
    // User requested full string. Let's try to fit it or use wrap.
    String fullString = "";
    if (parts.isNotEmpty) {
      fullString = "${parts.join(' ')} $lastPart";
    } else {
      fullString = "$seconds seconds left";
    }

    return Row(
      children: [
        const Icon(Icons.av_timer_rounded, size: 18, color: Colors.orange),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            fullString,
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2, // Allow wrapping for long duration string
          ),
        ),
      ],
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _QuickAmountChip({required this.label, required this.onTap, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: isPrimary ? Border.all(color: Colors.red.withOpacity(0.3)) : null,
        ),
        child: Text(
          isPrimary ? label : "৳$label",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPrimary ? Colors.red : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}