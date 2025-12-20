import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/expense_model.dart';

// 1. PROVIDERS (This fixes the "undefined getter" errors)
final expenseRepositoryProvider = Provider((ref) => ExpenseRepository(FirebaseFirestore.instance, ref));

final expenseStreamProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(expenseRepositoryProvider).watchExpenses();
});

// 2. REPOSITORY CLASS
class ExpenseRepository {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  ExpenseRepository(this._firestore, this._ref);

  // Add New Expense
  Future<void> addExpense({
    required String category,
    required double amount,
    required String note,
    required DateTime date,
  }) async {
    final user = _ref.read(authServiceProvider).currentUser;
    if (user == null) throw Exception("User not logged in");

    await _firestore.collection('expenses').add({
      'category': category,
      'amount': amount,
      'note': note,
      'date': Timestamp.fromDate(date),
      'recordedBy': user.email,
      'timestamp': FieldValue.serverTimestamp(), // For sorting
    });
  }

  // Delete Expense
  Future<void> deleteExpense(String id) async {
    await _firestore.collection('expenses').doc(id).delete();
  }

  // Get Expenses (Ordered by Date Newest First)
  Stream<List<Expense>> watchExpenses() {
    return _firestore
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Expense.fromMap(doc.id, doc.data());
      }).toList();
    });
  }
}