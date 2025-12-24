import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/product_model.dart';

final inventoryRepositoryProvider = Provider((ref) => InventoryRepository(FirebaseFirestore.instance, ref));

class InventoryRepository {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  InventoryRepository(this._firestore, this._ref);

  // ... (receiveProduct method remains same) ...

  // 👇 UPDATED: Batch Receive (Saves prices in logs for History)
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
          .get();

      DocumentReference? targetProductRef;
      int oldStock = 0;

      // Find exact variant match
      if (querySnapshot.docs.isNotEmpty) {
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final String dbColor = (data['color'] ?? '').toString().trim().toLowerCase();
          final String newColor = product.color.trim().toLowerCase();

          // Check Date Match logic (Optional, based on your previous preference)
          // For now, assuming if Model & Color match, we update stock.
          if (dbColor == newColor) {
            targetProductRef = doc.reference;
            oldStock = (data['currentStock'] as num).toInt();
            break;
          }
        }
      }

      if (targetProductRef != null) {
        batch.update(targetProductRef, {
          'currentStock': FieldValue.increment(product.currentStock),
          'marketPrice': product.marketPrice,
          'buyingPrice': product.buyingPrice,
          'lastUpdated': product.lastUpdated ?? DateTime.now(),
        });
      } else {
        targetProductRef = _firestore.collection('products').doc();
        batch.set(targetProductRef, product.toMap());
      }

      // 4. Audit Log (Updated to include Prices for History/Reprinting)
      final logRef = _firestore.collection('inventory_logs').doc();
      batch.set(logRef, {
        'batchId': masterLogRef.id,
        'type': 'RECEIVE',
        'productId': targetProductRef.id,
        'productName': product.name, // Saved for history
        'productModel': product.model,
        'productCategory': product.category,
        'buyingPrice': product.buyingPrice, // Saved for history
        'marketPrice': product.marketPrice, // Saved for history
        'commissionPercent': product.commissionPercent,
        'quantityAdded': product.currentStock,
        'oldStock': oldStock,
        'newStock': oldStock + product.currentStock,
        'receivedBy': user.email,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // 👇 NEW: Watch Stock History (Batches)
  Stream<List<Map<String, dynamic>>> watchStockHistory() {
    return _firestore
        .collection('inventory_batches')
        .where('type', isEqualTo: 'INWARD_CHALLAN')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList());
  }

  // 👇 NEW: Get Details for a Specific History Batch (For Reprinting)
  Future<List<Product>> getHistoryBatchItems(String batchId) async {
    final snapshot = await _firestore
        .collection('inventory_logs')
        .where('batchId', isEqualTo: batchId)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      // Reconstruct Product object from Log data for the PDF generator
      return Product(
        id: data['productId'] ?? '',
        name: data['productName'] ?? '',
        model: data['productModel'] ?? '',
        category: data['productCategory'] ?? '',
        capacity: '', // Not stored in log, optional
        color: '', // Not stored in log, optional
        marketPrice: (data['marketPrice'] ?? 0).toDouble(),
        commissionPercent: (data['commissionPercent'] ?? 0).toDouble(),
        buyingPrice: (data['buyingPrice'] ?? 0).toDouble(),
        currentStock: (data['quantityAdded'] ?? 0).toInt(), // Quantity received
        lastUpdated: (data['timestamp'] as Timestamp?)?.toDate(),
      );
    }).toList();
  }

  // ... (updateProduct, deleteProduct, watchInventory remain same) ...
  Future<void> updateProduct(Product product) async {
    final batch = _firestore.batch();
    final docRef = _firestore.collection('products').doc(product.id);
    batch.update(docRef, product.toMap());
    await batch.commit();
  }

  Future<void> deleteProduct(String productId, String model) async {
    await _firestore.collection('products').doc(productId).delete();
  }

  Stream<List<Product>> watchInventory() {
    return _firestore.collection('products').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        try {
          return Product.fromMap(doc.id, doc.data());
        } catch (e) {
          return null;
        }
      }).whereType<Product>().toList();
    });
  }
}

final inventoryStreamProvider = StreamProvider<List<Product>>((ref) {
  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.watchInventory();
});

// Provider for History
final stockHistoryProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(inventoryRepositoryProvider).watchStockHistory();
});