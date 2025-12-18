// A simple Dart class to represent a Product
class Product {
  final String id;
  final String name;
  final String model;
  final String category;
  final String capacity; // e.g., "32 inch"
  final double marketPrice; // MRP
  final double commissionPercent;
  final double buyingPrice; // Calculated
  final int currentStock;

  Product({
    required this.id,
    required this.name,
    required this.model,
    required this.category,
    required this.capacity,
    required this.marketPrice,
    required this.commissionPercent,
    required this.buyingPrice,
    required this.currentStock,
  });

  // Convert from Firestore Map to Dart Object
  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      model: map['model'] ?? '',
      category: map['category'] ?? '',
      capacity: map['capacity'] ?? '',
      marketPrice: (map['marketPrice'] ?? 0).toDouble(),
      commissionPercent: (map['commissionPercent'] ?? 0).toDouble(),
      buyingPrice: (map['buyingPrice'] ?? 0).toDouble(),

      // 👇 CHANGED: Handles int, double, or String safely
      currentStock: (map['currentStock'] as num?)?.toInt() ?? 0,
    );
  }

  // Convert from Dart Object to Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'model': model,
      'category': category,
      'capacity': capacity,
      'marketPrice': marketPrice,
      'commissionPercent': commissionPercent,
      'buyingPrice': buyingPrice,
      'currentStock': currentStock,
      'lastUpdated': DateTime.now(), // Helpful for sorting
    };
  }
}