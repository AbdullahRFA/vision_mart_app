import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String category; // Rent, Electric, Transport, Food, etc.
  final double amount;
  final String note; // Optional description
  final DateTime date;
  final String recordedBy;

  Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.note,
    required this.date,
    required this.recordedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'amount': amount,
      'note': note,
      'date': Timestamp.fromDate(date),
      'recordedBy': recordedBy,
    };
  }

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      category: map['category'] ?? 'Other',
      amount: (map['amount'] ?? 0).toDouble(),
      note: map['note'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      recordedBy: map['recordedBy'] ?? '',
    );
  }
}