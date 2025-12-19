import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dueRepositoryProvider = Provider((ref) => DueRepository(FirebaseFirestore.instance));

class DueRepository {
  final FirebaseFirestore _firestore;

  DueRepository(this._firestore);

  // 1. Get all sales that are NOT fully paid (Status 'Due' or 'Partial')
  Stream<List<Map<String, dynamic>>> watchDueCustomers() {
    return _firestore
        .collection('sales')
        .where('paymentStatus', whereIn: ['Due', 'Partial']) // 👈 Changed to support Partial
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['saleId'] = doc.id;
        return data;
      }).toList();
    });
  }

  // 2. Receive a Payment (Partial or Full)
  Future<void> receivePayment({
    required String saleId,
    required double currentPaidAmount, // How much they already paid before this
    required double totalOrderAmount,  // The total bill
    required double amountPayingNow,   // How much they are giving TODAY
  }) async {
    final newTotalPaid = currentPaidAmount + amountPayingNow;

    // Determine new status
    // If they paid everything (or more), mark as Cash (Closed). Otherwise, 'Partial'.
    // We use a small epsilon (0.1) to handle tiny floating point errors.
    String newStatus = newTotalPaid >= (totalOrderAmount - 0.1) ? 'Cash' : 'Partial';

    final batch = _firestore.batch();
    final saleRef = _firestore.collection('sales').doc(saleId);

    // A. Update the Sale Record
    batch.update(saleRef, {
      'paidAmount': newTotalPaid,
      'paymentStatus': newStatus,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    // B. Create a Payment History Record (For receipts/audit)
    // This allows you to see: "Paid 500 on Monday", "Paid 200 on Friday"
    final paymentRef = saleRef.collection('payments').doc();
    batch.set(paymentRef, {
      'amount': amountPayingNow,
      'date': FieldValue.serverTimestamp(),
      'recordedBy': 'Admin', // In future, use actual user email
    });

    await batch.commit();
  }
}

final dueStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(dueRepositoryProvider).watchDueCustomers();
});