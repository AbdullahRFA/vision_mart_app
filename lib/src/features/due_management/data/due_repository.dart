import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dueRepositoryProvider = Provider((ref) => DueRepository(FirebaseFirestore.instance));

class DueRepository {
  final FirebaseFirestore _firestore;

  DueRepository(this._firestore);

  // 1. Get all sales where paymentStatus is 'Due'
  Stream<List<Map<String, dynamic>>> watchDueCustomers() {
    return _firestore
        .collection('sales')
        .where('paymentStatus', isEqualTo: 'Due')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['saleId'] = doc.id; // We need the ID to update it later
        return data;
      }).toList();
    });
  }

  // 2. Settle a Due (Mark as Paid)
  Future<void> settleDue(String saleId, double amount) async {
    // In a complex app, you would add a 'payments' sub-collection to track partial payments.
    // For now, we will mark the whole sale as 'Cash' (Paid).

    await _firestore.collection('sales').doc(saleId).update({
      'paymentStatus': 'Cash', // Status changes to Paid
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }
}

final dueStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(dueRepositoryProvider).watchDueCustomers();
});