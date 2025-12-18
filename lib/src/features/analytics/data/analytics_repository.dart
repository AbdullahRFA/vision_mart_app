import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final analyticsRepositoryProvider = Provider((ref) => AnalyticsRepository(FirebaseFirestore.instance));

class AnalyticsRepository {
  final FirebaseFirestore _firestore;

  AnalyticsRepository(this._firestore);

  // Get all sales for a specific day (Real-time stream)
// ... inside AnalyticsRepository

  Stream<List<Map<String, dynamic>>> getSalesForDate(DateTime date) {
    // 👇 DEBUG: Commenting out date logic to check if ANY data exists
    // final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    // final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _firestore
        .collection('sales')
    // 👇 REMOVE FILTERS TEMPORARILY
    // .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
    // .where('timestamp', isLessThanOrEqualTo: endOfDay)
        .snapshots()
        .map((snapshot) {

      // 👇 ADD PRINT TO DEBUG CONSOLE
      print("📊 ANALYTICS DEBUG: Found ${snapshot.docs.length} sales documents.");

      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }
}

// Provider to get "Today's Stats" automatically
final todaySalesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getSalesForDate(DateTime.now());
});