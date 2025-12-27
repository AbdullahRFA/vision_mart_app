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
      final querySnapshot = await _firestore
          .collection('products')
          .where('model', isEqualTo: product.model)
          .get();

      DocumentReference? targetProductRef;
      int oldStock = 0;

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

  // --- 3. GET BATCH ITEMS ---
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
        currentStock: (data['quantityAdded'] as num? ?? 0).toInt(),
        lastUpdated: (data['timestamp'] as Timestamp?)?.toDate(),
      );
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> watchHistoryBatchLogs(String batchId) {
    return _firestore
        .collection('inventory_logs')
        .where('batchId', isEqualTo: batchId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['logId'] = doc.id;
        return data;
      }).toList();
    });
  }

  // --- 4. CORRECT MISTAKE (Logic Updated: Move Stock vs Update Stock) ---
  Future<void> correctStockEntry({
    required String logId,
    required String productId,
    required String category, // 👈 NEW: Required to find/create target product
    required String newName,
    required String newModel,
    required double newMrp,
    required double newComm,
    required double newBuyingPrice,
    required int newQuantity,
  }) async {
    // A. Pre-Check: Search for a product matching the NEW identity (Model + Category + MRP + Comm)
    // We do this outside the transaction because we can't query flexibly inside.
    final querySnap = await _firestore.collection('products')
        .where('category', isEqualTo: category)
        .where('model', isEqualTo: newModel)
        .get();

    String? targetProductId;

    // Exact match filter
    for (var doc in querySnap.docs) {
      final d = doc.data();
      final double dMrp = (d['marketPrice'] ?? 0).toDouble();
      final double dComm = (d['commissionPercent'] ?? 0).toDouble();
      if ((dMrp - newMrp).abs() < 0.01 && (dComm - newComm).abs() < 0.01) {
        targetProductId = doc.id;
        break;
      }
    }

    // B. Transaction
    await _firestore.runTransaction((transaction) async {
      final logRef = _firestore.collection('inventory_logs').doc(logId);
      final oldProductRef = _firestore.collection('products').doc(productId);

      final logSnap = await transaction.get(logRef);
      if (!logSnap.exists) throw Exception("Log entry not found");

      final oldLogData = logSnap.data()!;
      final int oldQuantity = (oldLogData['quantityAdded'] as num).toInt();

      // Check Old Product to determine if Identity changed
      final oldProductSnap = await transaction.get(oldProductRef);
      bool identityMatches = false;

      if (oldProductSnap.exists) {
        final d = oldProductSnap.data()!;
        final dModel = d['model'];
        final double dMrp = (d['marketPrice'] ?? 0).toDouble();
        final double dComm = (d['commissionPercent'] ?? 0).toDouble();

        // If the current product already matches the NEW details, we are NOT moving.
        if (dModel == newModel && (dMrp - newMrp).abs() < 0.01 && (dComm - newComm).abs() < 0.01) {
          identityMatches = true;
        }
      }

      if (identityMatches) {
        // --- SCENARIO 1: SAME IDENTITY (Only Name/Qty correction) ---
        // Just update the existing product
        final int qtyDiff = newQuantity - oldQuantity;

        if (oldProductSnap.exists) {
          final currentStock = (oldProductSnap.data()!['currentStock'] as num).toInt();
          if (qtyDiff < 0 && (currentStock + qtyDiff) < 0) {
            throw Exception("Cannot reduce quantity: Items already sold.");
          }

          transaction.update(oldProductRef, {
            'name': newName, // Allow name typo fix
            'buyingPrice': newBuyingPrice,
            'currentStock': FieldValue.increment(qtyDiff),
          });
        }

        transaction.update(logRef, {
          'productName': newName,
          'productModel': newModel,
          'marketPrice': newMrp,
          'commissionPercent': newComm,
          'buyingPrice': newBuyingPrice,
          'quantityAdded': newQuantity,
        });

      } else {
        // --- SCENARIO 2: DIFFERENT IDENTITY (Stock Move) ---
        // The user changed Model/Price, implying this batch belongs to a DIFFERENT product.

        // 1. Revert Stock from OLD Product
        if (oldProductSnap.exists) {
          final currentStock = (oldProductSnap.data()!['currentStock'] as num).toInt();
          if ((currentStock - oldQuantity) < 0) {
            throw Exception("Cannot move stock: Original items already sold.");
          }
          transaction.update(oldProductRef, {
            'currentStock': FieldValue.increment(-oldQuantity),
          });
        }

        // 2. Add Stock to TARGET Product
        String finalProductId;

        if (targetProductId != null) {
          // Target Exists
          final targetRef = _firestore.collection('products').doc(targetProductId);
          finalProductId = targetProductId!;

          transaction.update(targetRef, {
            'currentStock': FieldValue.increment(newQuantity),
            'buyingPrice': newBuyingPrice,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          // Target New
          final newProductRef = _firestore.collection('products').doc();
          finalProductId = newProductRef.id;

          transaction.set(newProductRef, {
            'name': newName,
            'model': newModel,
            'category': category, // Uses passed category
            'capacity': '',
            'color': '',
            'marketPrice': newMrp,
            'commissionPercent': newComm,
            'buyingPrice': newBuyingPrice,
            'currentStock': newQuantity,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }

        // 3. Update Log to point to NEW Product
        transaction.update(logRef, {
          'productId': finalProductId,
          'productName': newName,
          'productModel': newModel,
          'marketPrice': newMrp,
          'commissionPercent': newComm,
          'buyingPrice': newBuyingPrice,
          'quantityAdded': newQuantity,
        });
      }
    });
  }

  // --- 5. DELETE ENTRY (ACID Transaction) ---
  Future<void> deleteStockEntry({
    required String logId,
    required String productId,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final logRef = _firestore.collection('inventory_logs').doc(logId);
      final productRef = _firestore.collection('products').doc(productId);

      // 1. READS
      final logSnap = await transaction.get(logRef);
      if (!logSnap.exists) return; // Already deleted

      final data = logSnap.data()!;
      final quantityToRemove = (data['quantityAdded'] as num? ?? 0).toInt();
      final batchId = data['batchId'] as String;

      final productSnap = await transaction.get(productRef);
      final batchRef = _firestore.collection('inventory_batches').doc(batchId);
      final batchSnap = await transaction.get(batchRef);

      // 2. VALIDATION (Stock Check)
      if (productSnap.exists) {
        final currentStock = (productSnap.data()?['currentStock'] as num? ?? 0).toInt();

        // 👇 The Check
        if (currentStock < quantityToRemove) {
          throw Exception("You don't have the available stock right now that why this deletation request is rejected");
        }

        // 3. WRITES
        transaction.update(productRef, {
          'currentStock': FieldValue.increment(-quantityToRemove),
        });
      }

      // Cleanup Batch
      if (batchSnap.exists) {
        final currentBatchCount = (batchSnap.data()?['itemCount'] as num? ?? 0).toInt();
        if (currentBatchCount <= 1) {
          transaction.delete(batchRef); // Deletes batch if it was the last item
        } else {
          transaction.update(batchRef, {
            'itemCount': FieldValue.increment(-1),
          });
        }
      }

      transaction.delete(logRef);
    });
  }

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