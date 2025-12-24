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

  // --- 1. RECEIVE STOCK (BATCH) ---
  // 👇 UPDATED: Added 'batchDate' parameter
  Future<void> receiveBatchProducts(List<Product> newProducts, DateTime batchDate) async {
    final user = _ref.read(authServiceProvider).currentUser;
    if (user == null) throw Exception("User not logged in");

    final batch = _firestore.batch();
    final masterLogRef = _firestore.collection('inventory_batches').doc();

    // 1. Create Master Batch Record
    batch.set(masterLogRef, {
      'type': 'INWARD_CHALLAN',
      'itemCount': newProducts.length,
      'createdBy': user.email,
      // 👇 UPDATED: Use the passed batchDate instead of serverTimestamp()
      'timestamp': Timestamp.fromDate(batchDate),
    });

    for (var product in newProducts) {
      // 2. Check for existing product (Simple check by Model)
      final querySnapshot = await _firestore
          .collection('products')
          .where('model', isEqualTo: product.model)
          .get();

      DocumentReference? targetProductRef;
      int oldStock = 0;

      // Find exact match (Model + Category)
      if (querySnapshot.docs.isNotEmpty) {
        for (var doc in querySnapshot.docs) {
          if (doc['category'] == product.category) {
            targetProductRef = doc.reference;
            oldStock = (doc['currentStock'] as num).toInt();
            break;
          }
        }
      }

      // 3. Update or Create Product
      if (targetProductRef != null) {
        batch.update(targetProductRef, {
          'currentStock': FieldValue.increment(product.currentStock),
          'marketPrice': product.marketPrice,
          'buyingPrice': product.buyingPrice,
          // Update lastUpdated to the User's Batch Date
          'lastUpdated': Timestamp.fromDate(batchDate),
        });
      } else {
        targetProductRef = _firestore.collection('products').doc();
        // Ensure new product has the correct date
        final productData = product.toMap();
        productData['lastUpdated'] = Timestamp.fromDate(batchDate);
        batch.set(targetProductRef, productData);
      }

      // 4. Audit Log
      final logRef = _firestore.collection('inventory_logs').doc();
      batch.set(logRef, {
        'batchId': masterLogRef.id,
        'type': 'RECEIVE',
        'productId': targetProductRef.id,
        'productName': product.name,
        'productModel': product.model,
        'productCategory': product.category,
        'buyingPrice': product.buyingPrice,
        'marketPrice': product.marketPrice,
        'commissionPercent': product.commissionPercent,
        'quantityAdded': product.currentStock,
        'oldStock': oldStock,
        'newStock': oldStock + product.currentStock,
        'receivedBy': user.email,
        'timestamp': Timestamp.fromDate(batchDate), // Use Batch Date for consistency
      });
    }

    await batch.commit();
  }

  // --- 2. WATCH HISTORY ---
  Stream<List<Map<String, dynamic>>> watchStockHistory() {
    return _firestore
        .collection('inventory_batches')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList());
  }

  // --- 3. GET BATCH DETAILS (For PDF) ---
  Future<List<Product>> getHistoryBatchItems(String batchId) async {
    final snapshot = await _firestore
        .collection('inventory_logs')
        .where('batchId', isEqualTo: batchId)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Product(
        id: data['productId'] ?? '',
        name: data['productName'] ?? '',
        model: data['productModel'] ?? '',
        category: data['productCategory'] ?? '',
        capacity: '',
        color: '',
        marketPrice: (data['marketPrice'] ?? 0).toDouble(),
        commissionPercent: (data['commissionPercent'] ?? 0).toDouble(),
        buyingPrice: (data['buyingPrice'] ?? 0).toDouble(),
        currentStock: (data['quantityAdded'] ?? 0).toInt(),
        lastUpdated: (data['timestamp'] as Timestamp?)?.toDate(),
      );
    }).toList();
  }

  // ... (Keep existing update/delete/watchInventory methods) ...
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

final stockHistoryProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(inventoryRepositoryProvider).watchStockHistory();
});