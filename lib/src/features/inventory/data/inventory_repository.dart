import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/product_model.dart';

// 1. Repository Provider
final inventoryRepositoryProvider = Provider((ref) => InventoryRepository(FirebaseFirestore.instance, ref));

class InventoryRepository {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  InventoryRepository(this._firestore, this._ref);

  // Single Product Receive
  Future<void> receiveProduct({
    required String name,
    required String model,
    required String category,
    required String capacity,
    required double mrp,
    required double commission,
    required int quantity,
  }) async {
    await receiveBatchProducts([
      Product(
        id: '',
        name: name,
        model: model,
        category: category,
        capacity: capacity,
        marketPrice: mrp,
        commissionPercent: commission,
        buyingPrice: mrp - (mrp * (commission / 100)),
        currentStock: quantity,
      )
    ]);
  }

  // Batch Receive Logic
  Future<void> receiveBatchProducts(List<Product> newProducts) async {
    final user = _ref.read(authServiceProvider).currentUser;
    if (user == null) throw Exception("User not logged in");

    final batch = _firestore.batch();

    final masterLogRef = _firestore.collection('inventory_batches').doc();
    batch.set(masterLogRef, {
      'type': 'INWARD_CHALLAN',
      'itemCount': newProducts.length,
      'createdBy': user.email,
      'timestamp': FieldValue.serverTimestamp(),
    });

    for (var product in newProducts) {
      final querySnapshot = await _firestore
          .collection('products')
          .where('model', isEqualTo: product.model)
          .limit(1)
          .get();

      DocumentReference productRef;
      int oldStock = 0;

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        productRef = doc.reference;
        oldStock = (doc['currentStock'] as num).toInt();

        batch.update(productRef, {
          'currentStock': FieldValue.increment(product.currentStock),
          'marketPrice': product.marketPrice,
          'commissionPercent': product.commissionPercent,
          'buyingPrice': product.buyingPrice,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        productRef = _firestore.collection('products').doc();
        batch.set(productRef, product.toMap());
      }

      final logRef = _firestore.collection('inventory_logs').doc();
      batch.set(logRef, {
        'batchId': masterLogRef.id,
        'type': 'RECEIVE',
        'productId': productRef.id,
        'productModel': product.model,
        'productCategory': product.category,
        'quantityAdded': product.currentStock,
        'oldStock': oldStock,
        'newStock': oldStock + product.currentStock,
        'receivedBy': user.email,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // 👇 4. NEW: Update Product (ACID)
  Future<void> updateProduct(Product product) async {
    final user = _ref.read(authServiceProvider).currentUser;
    // Batch ensures Atomicity: The update and the log happen together.
    final batch = _firestore.batch();

    // A. Update the Product Document
    final docRef = _firestore.collection('products').doc(product.id);
    batch.update(docRef, product.toMap());

    // B. Create Audit Log
    final logRef = _firestore.collection('inventory_logs').doc();
    batch.set(logRef, {
      'type': 'UPDATE',
      'productId': product.id,
      'productModel': product.model,
      'updatedBy': user?.email ?? 'Admin',
      'changes': 'Details Updated (Price/Name/etc)',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // 👇 5. NEW: Delete Product (ACID)
  Future<void> deleteProduct(String productId, String model) async {
    final user = _ref.read(authServiceProvider).currentUser;
    final batch = _firestore.batch();

    // A. Delete the Product Document
    final docRef = _firestore.collection('products').doc(productId);
    batch.delete(docRef);

    // B. Create Audit Log (So we know who deleted what)
    final logRef = _firestore.collection('inventory_logs').doc();
    batch.set(logRef, {
      'type': 'DELETE',
      'productId': productId,
      'productModel': model,
      'deletedBy': user?.email ?? 'Admin',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Watch Inventory Stream
  Stream<List<Product>> watchInventory() {
    return _firestore
        .collection('products')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        try {
          return Product.fromMap(doc.id, doc.data());
        } catch (e) {
          debugPrint("Error parsing doc ${doc.id}: $e");
          return null;
        }
      }).whereType<Product>().toList();
    });
  }
}

// Provider for UI
final inventoryStreamProvider = StreamProvider<List<Product>>((ref) {
  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.watchInventory();
});