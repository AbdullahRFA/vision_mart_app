import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/product_model.dart';

final inventoryRepositoryProvider = Provider((ref) => InventoryRepository(FirebaseFirestore.instance, ref));

final inventoryStreamProvider = StreamProvider<List<Product>>((ref) {
  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.watchInventory();
});

final stockHistoryProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(inventoryRepositoryProvider).watchStockHistory();
});

class InventoryRepository {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  InventoryRepository(this._firestore, this._ref);

  // --- 1. RECEIVE STOCK (BATCH) ---
  Future<void> receiveBatchProducts(List<Product> newProducts, DateTime batchDate) async {
    final user = _ref.read(authServiceProvider).currentUser;
    if (user == null) throw Exception("User not logged in");

    final batch = _firestore.batch();
    final masterLogRef = _firestore.collection('inventory_batches').doc();

    batch.set(masterLogRef, {
      'type': 'INWARD_CHALLAN',
      'itemCount': newProducts.length,
      'createdBy': user.email,
      'timestamp': Timestamp.fromDate(batchDate),
    });

    for (var product in newProducts) {
      // Fetch products with same MODEL
      final querySnapshot = await _firestore
          .collection('products')
          .where('model', isEqualTo: product.model)
          .get();

      DocumentReference? targetProductRef;
      int oldStock = 0;

      // STRICT MATCHING: Category + MRP + Commission
      if (querySnapshot.docs.isNotEmpty) {
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final String dbCategory = data['category'] ?? '';
          final double dbMrp = (data['marketPrice'] ?? 0).toDouble();
          final double dbComm = (data['commissionPercent'] ?? 0).toDouble();

          final bool isCategoryMatch = dbCategory == product.category;
          final bool isMrpMatch = (dbMrp - product.marketPrice).abs() < 0.01;
          final bool isCommMatch = (dbComm - product.commissionPercent).abs() < 0.01;

          if (isCategoryMatch && isMrpMatch && isCommMatch) {
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
          'commissionPercent': product.commissionPercent,
          'buyingPrice': product.buyingPrice,
          'lastUpdated': Timestamp.fromDate(batchDate),
        });
      } else {
        targetProductRef = _firestore.collection('products').doc();
        final productData = product.toMap();
        productData['lastUpdated'] = Timestamp.fromDate(batchDate);
        batch.set(targetProductRef, productData);
      }

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
        'timestamp': Timestamp.fromDate(batchDate),
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

  // --- 3. GET BATCH ITEMS (With Log ID for Editing) ---
  Future<List<Map<String, dynamic>>> getHistoryBatchLogs(String batchId) async {
    final snapshot = await _firestore
        .collection('inventory_logs')
        .where('batchId', isEqualTo: batchId)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['logId'] = doc.id; // Crucial for updating specific log
      return data;
    }).toList();
  }

  // Legacy method for PDF (wraps the above)
  Future<List<Product>> getHistoryBatchItems(String batchId) async {
    final logs = await getHistoryBatchLogs(batchId);
    return logs.map((data) {
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

  // --- 4. 👇 NEW: CORRECT MISTAKE (ACID Transaction) ---
  Future<void> correctStockEntry({
    required String logId,
    required String productId,
    required String newName,
    required String newModel,
    required double newMrp,
    required double newComm,
    required double newBuyingPrice,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final logRef = _firestore.collection('inventory_logs').doc(logId);
      final productRef = _firestore.collection('products').doc(productId);

      // 1. Update the Historical Log (so the memo is correct)
      transaction.update(logRef, {
        'productName': newName,
        'productModel': newModel,
        'marketPrice': newMrp,
        'commissionPercent': newComm,
        'buyingPrice': newBuyingPrice,
      });

      // 2. Update the Master Product (so current stock is correct)
      // Note: We check existence just in case it was deleted
      final productSnap = await transaction.get(productRef);
      if (productSnap.exists) {
        transaction.update(productRef, {
          'name': newName,
          'model': newModel,
          'marketPrice': newMrp,
          'commissionPercent': newComm,
          'buyingPrice': newBuyingPrice,
        });
      }
    });
  }

  // ... (Existing CRUD methods) ...
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