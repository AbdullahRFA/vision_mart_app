import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String model;
  final String category;
  final String capacity;
  final String color;
  final double marketPrice;
  final double commissionPercent;
  final double buyingPrice;
  final int currentStock;
  final DateTime? lastUpdated; // Acts as "Stored Date"

  Product({
    required this.id,
    required this.name,
    required this.model,
    required this.category,
    required this.capacity,
    this.color = '',
    required this.marketPrice,
    required this.commissionPercent,
    required this.buyingPrice,
    required this.currentStock,
    this.lastUpdated,
  });

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      model: map['model'] ?? '',
      category: map['category'] ?? '',
      capacity: map['capacity'] ?? '',
      color: map['color'] ?? '',
      marketPrice: (map['marketPrice'] ?? 0).toDouble(),
      commissionPercent: (map['commissionPercent'] ?? 0).toDouble(),
      buyingPrice: (map['buyingPrice'] ?? 0).toDouble(),
      currentStock: (map['currentStock'] as num?)?.toInt() ?? 0,
      // Retrieve Timestamp
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'model': model,
      'category': category,
      'capacity': capacity,
      'color': color,
      'marketPrice': marketPrice,
      'commissionPercent': commissionPercent,
      'buyingPrice': buyingPrice,
      'currentStock': currentStock,
      // 👇 FIXED: Use existing date if available, otherwise Now.
      // This prevents overwriting the "Received Date" on every save.
      'lastUpdated': lastUpdated ?? DateTime.now(),
    };
  }
}