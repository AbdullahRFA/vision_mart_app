import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/expense_model.dart';

// 1. PROVIDERS
final expenseRepositoryProvider = Provider((ref) => ExpenseRepository(FirebaseFirestore.instance, ref));

final expenseStreamProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(expenseRepositoryProvider).watchExpenses();
});

// 2. REPOSITORY CLASS
class ExpenseRepository {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  ExpenseRepository(this._firestore, this._ref);

  // Add New Expense (Single)
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
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // 👇 NEW: Add Batch Expenses
  Future<void> addBatchExpenses(List<Expense> expenses) async {
    final user = _ref.read(authServiceProvider).currentUser;
    if (user == null) throw Exception("User not logged in");

    final batch = _firestore.batch();

    for (var expense in expenses) {
      final docRef = _firestore.collection('expenses').doc();
      batch.set(docRef, {
        'category': expense.category,
        'amount': expense.amount,
        'note': expense.note,
        'date': Timestamp.fromDate(expense.date), // Specific date per expense
        'recordedBy': user.email,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
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

  // Update Existing Expense
  Future<void> updateExpense({
    required String id,
    required String category,
    required double amount,
    required String note,
    required DateTime date,
  }) async {
    final user = _ref.read(authServiceProvider).currentUser;

    await _firestore.collection('expenses').doc(id).update({
      'category': category,
      'amount': amount,
      'note': note,
      'date': Timestamp.fromDate(date),
      'lastUpdatedBy': user?.email ?? 'Admin',
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }
}