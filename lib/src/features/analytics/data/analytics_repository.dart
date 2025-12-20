import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final analyticsRepositoryProvider = Provider((ref) => AnalyticsRepository(FirebaseFirestore.instance));

class AnalyticsRepository {
  final FirebaseFirestore _firestore;

  AnalyticsRepository(this._firestore);

  // 1. Fetch sales invoices for a specific Date Range
  Stream<List<Map<String, dynamic>>> getSalesForRange(DateTime start, DateTime end) {
    return _firestore
        .collection('sales_invoices')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // 2. 👇 NEW: Fetch items for a specific Invoice ID
  Future<List<Map<String, dynamic>>> getInvoiceItems(String invoiceId) async {
    try {
      final query = await _firestore
          .collection('sales')
          .where('invoiceId', isEqualTo: invoiceId)
          .get();
      return query.docs.map((d) => d.data()).toList();
    } catch (e) {
      debugPrint("Error fetching invoice items: $e");
      return [];
    }
  }
}

// ... (DateRangeNotifier and salesReportProvider remain unchanged) ...
class DateRangeNotifier extends Notifier<DateTimeRange> {
  @override
  DateTimeRange build() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return DateTimeRange(start: start, end: end);
  }

  void setRange(DateTimeRange range) {
    state = range;
  }
}

final dateRangeProvider = NotifierProvider<DateRangeNotifier, DateTimeRange>(DateRangeNotifier.new);

final salesReportProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(analyticsRepositoryProvider);
  final range = ref.watch(dateRangeProvider);
  return repo.getSalesForRange(range.start, range.end);
});