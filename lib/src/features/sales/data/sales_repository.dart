import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../../inventory/domain/product_model.dart';

final salesRepositoryProvider = Provider((ref) => SalesRepository(FirebaseFirestore.instance, ref));

class SalesRepository {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  SalesRepository(this._firestore, this._ref);

  Future<void> sellProduct({
    required Product product,
    required String customerName,
    required String customerPhone,
    required int quantity,
    required double discountPercent,
    required String paymentStatus, // 'Cash' or 'Due'
  }) async {
    final user = _ref.read(authServiceProvider).currentUser;
    if (user == null) throw Exception("User not logged in");

    // 1. Validation (Double Check)
    if (product.currentStock < quantity) {
      throw Exception("Insufficient Stock. Only ${product.currentStock} available.");
    }

    // 2. Financial Calculations
    final double sellingPriceUnit = product.marketPrice - (product.marketPrice * (discountPercent / 100));
    final double totalSellingPrice = sellingPriceUnit * quantity;
    final double totalBuyingPrice = product.buyingPrice * quantity;

    // ⚠️ PROFIT (The Secret Metric)
    final double totalProfit = totalSellingPrice - totalBuyingPrice;

    // 3. Database Transaction (Atomic)
    final batch = _firestore.batch();

    // A. Create Sales Record
    final saleRef = _firestore.collection('sales').doc();
    batch.set(saleRef, {
      'type': 'SELL',
      'productId': product.id,
      'productName': product.name,
      'productModel': product.model,
      'category': product.category,

      'customerName': customerName,
      'customerPhone': customerPhone,

      'quantity': quantity,
      'mrp': product.marketPrice,
      'discountPercent': discountPercent,
      'sellingPriceUnit': sellingPriceUnit,
      'totalAmount': totalSellingPrice,
      'paymentStatus': paymentStatus,

      'profit': totalProfit, // Hidden from customer, visible to Admin

      'soldBy': user.email,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // B. Decrease Stock
    final productRef = _firestore.collection('products').doc(product.id);
    batch.update(productRef, {
      'currentStock': FieldValue.increment(-quantity),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    // C. Add to Inventory Log (for history consistency)
    final logRef = _firestore.collection('inventory_logs').doc();
    batch.set(logRef, {
      'type': 'SELL',
      'productId': product.id,
      'productName': product.name,
      'quantityRemoved': quantity,
      'oldStock': product.currentStock,
      'newStock': product.currentStock - quantity,
      'soldTo': customerName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}