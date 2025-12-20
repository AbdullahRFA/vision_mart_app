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

  Future<void> sellBatchProducts({
    required List<CartItem> items,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String paymentStatus, // 'Cash', 'Due', 'Partial'
    required double paidAmount,    // 👈 NEW: Actual amount paid
    DateTime? saleDate,
  }) async {
    final user = _ref.read(authServiceProvider).currentUser;
    if (user == null) throw Exception("User not logged in");

    final batch = _firestore.batch();
    final timestamp = saleDate != null ? Timestamp.fromDate(saleDate) : FieldValue.serverTimestamp();
    final invoiceRef = _firestore.collection('sales_invoices').doc();

    double grandTotalAmount = 0;
    double grandTotalProfit = 0;

    // 1. Calculate Totals
    for (var item in items) {
      if (item.product.currentStock < item.quantity) {
        throw Exception("Insufficient stock for ${item.product.name}");
      }
      grandTotalAmount += item.finalPrice;
      final totalBuyingPrice = item.product.buyingPrice * item.quantity;
      grandTotalProfit += (item.finalPrice - totalBuyingPrice);
    }

    // 2. Determine Due Amount
    double dueAmount = grandTotalAmount - paidAmount;
    // Safety check for floating point errors or negative due
    if (dueAmount < 0) dueAmount = 0;

    // 3. Create Master Invoice Record (This is now the source of truth for Due Screen)
    batch.set(invoiceRef, {
      'type': 'INVOICE',
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'totalAmount': grandTotalAmount,
      'paidAmount': paidAmount,     // 👈 Saved
      'dueAmount': dueAmount,       // 👈 Saved
      'totalProfit': grandTotalProfit,
      'itemCount': items.length,
      'paymentStatus': paymentStatus,
      'soldBy': user.email,
      'timestamp': timestamp,
    });

    // 4. Process Individual Items
    for (var item in items) {
      final unitPrice = item.product.marketPrice - (item.product.marketPrice * (item.discountPercent / 100));
      final totalBuyingPrice = item.product.buyingPrice * item.quantity;
      final profit = item.finalPrice - totalBuyingPrice;

      // Distribute payment status/amount to items (for Analytics)
      // If invoice is Partial, items are marked Partial.
      // We distribute paidAmount proportionally: (ItemPrice / TotalPrice) * PaidAmount
      double itemPaidAmount = 0;
      if (grandTotalAmount > 0) {
        itemPaidAmount = (item.finalPrice / grandTotalAmount) * paidAmount;
      }
      double itemDueAmount = item.finalPrice - itemPaidAmount;

      final saleRef = _firestore.collection('sales').doc();
      batch.set(saleRef, {
        'invoiceId': invoiceRef.id,
        'productId': item.product.id,
        'productName': item.product.name,
        'productModel': item.product.model,
        'category': item.product.category,
        'customerName': customerName, // Duplicated for easier querying
        'customerPhone': customerPhone,
        'customerAddress': customerAddress,
        'quantity': item.quantity,
        'mrp': item.product.marketPrice,
        'discountPercent': item.discountPercent,
        'sellingPriceUnit': unitPrice,
        'totalAmount': item.finalPrice,
        'paidAmount': itemPaidAmount, // 👈 Proportional Pay
        'dueAmount': itemDueAmount,   // 👈 Proportional Due
        'profit': profit,
        'paymentStatus': paymentStatus,
        'soldBy': user.email,
        'timestamp': timestamp,
      });

      // Update Stock
      final productRef = _firestore.collection('products').doc(item.product.id);
      batch.update(productRef, {
        'currentStock': FieldValue.increment(-item.quantity),
      });

      // Inventory Log
      final logRef = _firestore.collection('inventory_logs').doc();
      batch.set(logRef, {
        'type': 'SELL',
        'invoiceId': invoiceRef.id,
        'productId': item.product.id,
        'productName': item.product.name,
        'quantityRemoved': item.quantity,
        'soldTo': customerName,
        'timestamp': timestamp,
      });
    }

    await batch.commit();
  }
}