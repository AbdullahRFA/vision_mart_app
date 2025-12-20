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
        lastUpdated: DateTime.now(),
      )
    ]);
  }

  // 👇 UPDATED: Batch Receive Logic with Color & Date Checks
  Future<void> receiveBatchProducts(List<Product> newProducts) async {
    final user = _ref.read(authServiceProvider).currentUser;
    if (user == null) throw Exception("User not logged in");

    final batch = _firestore.batch();

    // Create a Master Log for this batch operation
    final masterLogRef = _firestore.collection('inventory_batches').doc();
    batch.set(masterLogRef, {
      'type': 'INWARD_CHALLAN',
      'itemCount': newProducts.length,
      'createdBy': user.email,
      'timestamp': FieldValue.serverTimestamp(),
    });

    for (var product in newProducts) {
      // 1. Fetch ALL products with this model (Removed limit(1))
      // We need to check all variants (Colors/Dates) to find the right one to merge.
      final querySnapshot = await _firestore
          .collection('products')
          .where('model', isEqualTo: product.model)
          .get();

      DocumentReference? targetProductRef;
      int oldStock = 0;

      // 2. Logic: Find if this EXACT variant exists (Same Color AND Same Date)
      if (querySnapshot.docs.isNotEmpty) {
        for (var doc in querySnapshot.docs) {
          final data = doc.data();

          // A. Check Color Match
          final String dbColor = (data['color'] ?? '').toString().trim().toLowerCase();
          final String newColor = product.color.trim().toLowerCase();
          if (dbColor != newColor) continue; // Colors differ? Treat as new item.

          // B. Check Date Match (Year-Month-Day)
          final Timestamp? dbTs = data['lastUpdated'] as Timestamp?;
          if (dbTs != null) {
            final dbDate = dbTs.toDate();
            final newDate = product.lastUpdated!; // From input

            final isSameDay = dbDate.year == newDate.year &&
                dbDate.month == newDate.month &&
                dbDate.day == newDate.day;

            if (isSameDay) {
              // FOUND IT! Same Model, Same Color, Same Date.
              // We will update this specific document.
              targetProductRef = doc.reference;
              oldStock = (data['currentStock'] as num).toInt();
              break;
            }
          }
        }
      }

      // 3. Prepare Batch Operation
      if (targetProductRef != null) {
        // UPDATE existing (Merge stock)
        batch.update(targetProductRef, {
          'currentStock': FieldValue.increment(product.currentStock),
          'marketPrice': product.marketPrice,
          'commissionPercent': product.commissionPercent,
          'buyingPrice': product.buyingPrice,
          // We don't change 'lastUpdated' to keep it anchored to the original date
        });
      } else {
        // CREATE new entry (New Date or New Color)
        targetProductRef = _firestore.collection('products').doc();
        batch.set(targetProductRef, product.toMap());
      }

      // 4. Audit Log
      final logRef = _firestore.collection('inventory_logs').doc();
      batch.set(logRef, {
        'batchId': masterLogRef.id,
        'type': 'RECEIVE',
        'productId': targetProductRef.id,
        'productModel': product.model,
        'productCategory': product.category,
        'quantityAdded': product.currentStock,
        'oldStock': oldStock,
        'newStock': oldStock + product.currentStock,
        'variant': "${product.color} | ${product.lastUpdated}", // Useful for debugging
        'receivedBy': user.email,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // Update Product (ACID)
  Future<void> updateProduct(Product product) async {
    final user = _ref.read(authServiceProvider).currentUser;
    final batch = _firestore.batch();

    final docRef = _firestore.collection('products').doc(product.id);
    batch.update(docRef, product.toMap());

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

  // Delete Product (ACID)
  Future<void> deleteProduct(String productId, String model) async {
    final user = _ref.read(authServiceProvider).currentUser;
    final batch = _firestore.batch();

    final docRef = _firestore.collection('products').doc(productId);
    batch.delete(docRef);

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