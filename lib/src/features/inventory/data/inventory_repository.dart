import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/product_model.dart';

final inventoryRepositoryProvider = Provider((ref) => InventoryRepository(FirebaseFirestore.instance, ref));

class InventoryRepository {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  InventoryRepository(this._firestore, this._ref);

  // 1. Receive Product Logic
  Future<void> receiveProduct({
    required String name,
    required String model,
    required String category,
    required String capacity,
    required double mrp,
    required double commission,
    required int quantity,
  }) async {
    final user = _ref.read(authServiceProvider).currentUser;
    if (user == null) throw Exception("User not logged in");

    // Auto-Calculate Buying Price
    final double buyingPrice = mrp - (mrp * (commission / 100));

    final batch = _firestore.batch();

    // A. Check if product already exists (by Model Number)
    final querySnapshot = await _firestore
        .collection('products')
        .where('model', isEqualTo: model)
        .limit(1)
        .get();

    DocumentReference productRef;
    int oldStock = 0;

    if (querySnapshot.docs.isNotEmpty) {
      // UPDATE EXISTING PRODUCT
      final doc = querySnapshot.docs.first;
      productRef = doc.reference;
      oldStock = doc['currentStock'];

      batch.update(productRef, {
        'currentStock': FieldValue.increment(quantity),
        'marketPrice': mrp, // Update prices to latest
        'commissionPercent': commission,
        'buyingPrice': buyingPrice,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } else {
      // CREATE NEW PRODUCT
      productRef = _firestore.collection('products').doc();
      final newProduct = Product(
        id: productRef.id,
        name: name,
        model: model,
        category: category,
        capacity: capacity,
        marketPrice: mrp,
        commissionPercent: commission,
        buyingPrice: buyingPrice,
        currentStock: quantity,
      );
      batch.set(productRef, newProduct.toMap());
    }

    // B. Create an Audit Log (The "Memo" data)
    final logRef = _firestore.collection('inventory_logs').doc();
    batch.set(logRef, {
      'type': 'RECEIVE',
      'productId': productRef.id,
      'productName': name,
      'productModel': model,
      'quantityAdded': quantity,
      'oldStock': oldStock,
      'newStock': oldStock + quantity,
      'receivedBy': user.email,
      'timestamp': FieldValue.serverTimestamp(),
      'buyingPriceSnapshot': buyingPrice, // Important for profit calc later
    });

    await batch.commit();
  }
}