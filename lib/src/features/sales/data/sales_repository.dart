import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../../inventory/domain/product_model.dart';

final salesRepositoryProvider = Provider((ref) => SalesRepository(FirebaseFirestore.instance, ref));

class CartItem {
  final Product product;
  final int quantity;
  final double discountPercent;
  final double finalPrice;

  CartItem({
    required this.product,
    required this.quantity,
    required this.discountPercent,
    required this.finalPrice,
  });
}

class SalesRepository {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  SalesRepository(this._firestore, this._ref);

  // 1. SELL BATCH (ACID Transaction)
  Future<void> sellBatchProducts({
    required List<CartItem> items,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String paymentStatus, // 'Cash', 'Due', 'Partial'
    required double paidAmount,    // Actual amount paid
    DateTime? saleDate,
  }) async {
    final user = _ref.read(authServiceProvider).currentUser;
    if (user == null) throw Exception("User not logged in");

    final timestamp = saleDate != null ? Timestamp.fromDate(saleDate) : FieldValue.serverTimestamp();

    final invoiceRef = _firestore.collection('sales_invoices').doc();

    double grandTotalAmount = 0;
    double grandTotalProfit = 0;

    for (var item in items) {
      grandTotalAmount += item.finalPrice;
      final totalBuyingPrice = item.product.buyingPrice * item.quantity;
      grandTotalProfit += (item.finalPrice - totalBuyingPrice);
    }

    double dueAmount = grandTotalAmount - paidAmount;
    if (dueAmount < 0) dueAmount = 0;

    await _firestore.runTransaction((transaction) async {

      // PHASE 1: ALL READS (Check Stock)
      for (var item in items) {
        final productRef = _firestore.collection('products').doc(item.product.id);
        final snapshot = await transaction.get(productRef);

        if (!snapshot.exists) {
          throw Exception("Product '${item.product.name}' not found in database.");
        }

        final currentStock = (snapshot.data()?['currentStock'] ?? 0) as int;
        if (currentStock < item.quantity) {
          throw Exception("Insufficient stock for '${item.product.model}'. Available: $currentStock, Required: ${item.quantity}");
        }
      }

      // PHASE 2: ALL WRITES

      // A. Create Invoice
      transaction.set(invoiceRef, {
        'type': 'INVOICE',
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerAddress': customerAddress,
        'totalAmount': grandTotalAmount,
        'paidAmount': paidAmount,
        'dueAmount': dueAmount,
        'totalProfit': grandTotalProfit,
        'itemCount': items.length,
        'paymentStatus': paymentStatus,
        'soldBy': user.email,
        'timestamp': timestamp,
      });

      // B. Process Items
      for (var item in items) {
        final unitPrice = item.product.marketPrice - (item.product.marketPrice * (item.discountPercent / 100));
        final totalBuyingPrice = item.product.buyingPrice * item.quantity;
        final profit = item.finalPrice - totalBuyingPrice;

        double itemPaidAmount = 0;
        if (grandTotalAmount > 0) {
          itemPaidAmount = (item.finalPrice / grandTotalAmount) * paidAmount;
        }
        double itemDueAmount = item.finalPrice - itemPaidAmount;

        final saleRef = _firestore.collection('sales').doc();

        transaction.set(saleRef, {
          'invoiceId': invoiceRef.id,
          'productId': item.product.id,
          'productName': item.product.name,
          'productModel': item.product.model,
          'category': item.product.category,
          'customerName': customerName,
          'customerPhone': customerPhone,
          'customerAddress': customerAddress,
          'quantity': item.quantity,
          'mrp': item.product.marketPrice,
          'discountPercent': item.discountPercent,
          'sellingPriceUnit': unitPrice,
          'totalAmount': item.finalPrice,
          'paidAmount': itemPaidAmount,
          'dueAmount': itemDueAmount,
          'profit': profit,
          'paymentStatus': paymentStatus,
          'soldBy': user.email,
          'timestamp': timestamp,
        });

        // Decrement Stock
        final productRef = _firestore.collection('products').doc(item.product.id);
        transaction.update(productRef, {
          'currentStock': FieldValue.increment(-item.quantity),
        });

        // Inventory Log
        final logRef = _firestore.collection('inventory_logs').doc();
        transaction.set(logRef, {
          'type': 'SELL',
          'invoiceId': invoiceRef.id,
          'productId': item.product.id,
          'productName': item.product.name,
          'quantityRemoved': item.quantity,
          'soldTo': customerName,
          'timestamp': timestamp,
        });
      }
    });
  }

  // 2. DELETE INVOICE & RESTORE STOCK (ACID Transaction)
  // This wrapper can be used directly for Deletion
  Future<void> deleteInvoice(String invoiceId) async {
    await deleteInvoiceAndRestoreStock(invoiceId);
  }

  // Helper logic for both Update and Delete
  Future<void> deleteInvoiceAndRestoreStock(String invoiceId) async {
    // 1. Query items (Allowed outside transaction to get IDs)
    final salesQuery = await _firestore
        .collection('sales')
        .where('invoiceId', isEqualTo: invoiceId)
        .get();

    await _firestore.runTransaction((transaction) async {
      // PHASE 1: ALL READS
      // We must read all product docs first to check existence before updating
      List<DocumentSnapshot> productSnaps = [];

      for (var doc in salesQuery.docs) {
        final productId = doc.data()['productId'];
        final productRef = _firestore.collection('products').doc(productId);
        final snap = await transaction.get(productRef);
        productSnaps.add(snap);
      }

      // PHASE 2: ALL WRITES
      for (int i = 0; i < salesQuery.docs.length; i++) {
        final saleDoc = salesQuery.docs[i];
        final productSnap = productSnaps[i];

        final data = saleDoc.data();
        final qty = data['quantity'];
        final int quantityToRestore = (qty is int) ? qty : (qty as double).toInt();

        // Restore Stock if product still exists
        if (productSnap.exists) {
          transaction.update(productSnap.reference, {
            'currentStock': FieldValue.increment(quantityToRestore),
          });
        }

        // Delete the sale record
        transaction.delete(saleDoc.reference);
      }

      // Delete the Master Invoice
      final invoiceRef = _firestore.collection('sales_invoices').doc(invoiceId);
      transaction.delete(invoiceRef);
    });
  }
}