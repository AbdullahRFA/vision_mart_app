import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dueRepositoryProvider = Provider((ref) => DueRepository(FirebaseFirestore.instance));

class DueRepository {
  final FirebaseFirestore _firestore;

  DueRepository(this._firestore);

  // 1. Get all INVOICES that are NOT fully paid
  Stream<List<Map<String, dynamic>>> watchDueCustomers() {
    return _firestore
        .collection('sales_invoices') // 👈 Changed to invoices
        .where('paymentStatus', whereIn: ['Due', 'Partial'])
        .orderBy('timestamp', descending: true) // Sort by date
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['saleId'] = doc.id; // This is now the Invoice ID
        return data;
      }).toList();
    });
  }

  // 2. Receive a Payment (Updates Invoice)
  Future<void> receivePayment({
    required String saleId, // This is Invoice ID
    required double currentPaidAmount,
    required double totalOrderAmount,
    required double amountPayingNow,
  }) async {
    final newTotalPaid = currentPaidAmount + amountPayingNow;
    final remainingDue = totalOrderAmount - newTotalPaid;

    // Determine new status
    // Use a small epsilon (0.5) to handle tiny floating point diffs safely
    String newStatus = remainingDue <= 0.5 ? 'Cash' : 'Partial';

    final batch = _firestore.batch();

    // Target the INVOICE document
    final invoiceRef = _firestore.collection('sales_invoices').doc(saleId);

    // A. Update the Invoice Record
    batch.update(invoiceRef, {
      'paidAmount': newTotalPaid,
      'dueAmount': remainingDue < 0 ? 0 : remainingDue, // Ensure no negative due
      'paymentStatus': newStatus,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    // B. Create a Payment History Record (Subcollection of Invoice)
    final paymentRef = invoiceRef.collection('payments').doc();
    batch.set(paymentRef, {
      'amount': amountPayingNow,
      'date': FieldValue.serverTimestamp(),
      'recordedBy': 'Admin',
    });

    // NOTE: We are NOT updating individual 'sales' items here to save write costs/complexity.
    // The Invoice is now the master record for Due Management.

    await batch.commit();
  }

  // 3. 👇 NEW: Update Payment Deadline (For Countdown Feature)
  Future<void> updatePaymentDeadline(String saleId, DateTime? deadline) async {
    await _firestore.collection('sales_invoices').doc(saleId).update({
      'paymentDeadline': deadline != null ? Timestamp.fromDate(deadline) : null,
    });
  }
}

final dueStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(dueRepositoryProvider).watchDueCustomers();
});