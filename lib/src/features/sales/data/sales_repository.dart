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

  Future<void> sellProduct({
    required Product product,
    required String customerName,
    required String customerPhone,
    required String customerAddress, // 👈 New Field
    required int quantity,
    required double discountPercent,
    required String paymentStatus,
  }) async {
    final sellingPriceUnit = product.marketPrice - (product.marketPrice * (discountPercent / 100));
    final total = sellingPriceUnit * quantity;

    await sellBatchProducts(
      items: [CartItem(product: product, quantity: quantity, discountPercent: discountPercent, finalPrice: total)],
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress, // 👈 Pass it
      paymentStatus: paymentStatus,
    );
  }

  Future<void> sellBatchProducts({
    required List<CartItem> items,
    required String customerName,
    required String customerPhone,
    required String customerAddress, // 👈 New Field
    required String paymentStatus,
  }) async {
    final user = _ref.read(authServiceProvider).currentUser;
    if (user == null) throw Exception("User not logged in");

    final batch = _firestore.batch();
    final timestamp = FieldValue.serverTimestamp();
    final invoiceRef = _firestore.collection('sales_invoices').doc();

    double grandTotalAmount = 0;
    double grandTotalProfit = 0;

    for (var item in items) {
      if (item.product.currentStock < item.quantity) {
        throw Exception("Insufficient stock for ${item.product.name}");
      }
      grandTotalAmount += item.finalPrice;
      final totalBuyingPrice = item.product.buyingPrice * item.quantity;
      grandTotalProfit += (item.finalPrice - totalBuyingPrice);
    }

    // A. Invoice Record
    batch.set(invoiceRef, {
      'type': 'INVOICE',
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress, // 👈 Save Address
      'totalAmount': grandTotalAmount,
      'totalProfit': grandTotalProfit,
      'itemCount': items.length,
      'paymentStatus': paymentStatus,
      'soldBy': user.email,
      'timestamp': timestamp,
    });

    // B. Individual Sales
    for (var item in items) {
      final unitPrice = item.product.marketPrice - (item.product.marketPrice * (item.discountPercent / 100));
      final totalBuyingPrice = item.product.buyingPrice * item.quantity;
      final profit = item.finalPrice - totalBuyingPrice;

      final saleRef = _firestore.collection('sales').doc();
      batch.set(saleRef, {
        'invoiceId': invoiceRef.id,
        'productId': item.product.id,
        'productName': item.product.name,
        'productModel': item.product.model,
        'category': item.product.category,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerAddress': customerAddress, // 👈 Save Address
        'quantity': item.quantity,
        'mrp': item.product.marketPrice,
        'discountPercent': item.discountPercent,
        'sellingPriceUnit': unitPrice,
        'totalAmount': item.finalPrice,
        'profit': profit,
        'paymentStatus': paymentStatus,
        'soldBy': user.email,
        'timestamp': timestamp,
      });

      final productRef = _firestore.collection('products').doc(item.product.id);
      batch.update(productRef, {
        'currentStock': FieldValue.increment(-item.quantity),
        'lastUpdated': timestamp,
      });

      final logRef = _firestore.collection('inventory_logs').doc();
      batch.set(logRef, {
        'type': 'SELL',
        'invoiceId': invoiceRef.id,
        'productId': item.product.id,
        'productName': item.product.name,
        'quantityRemoved': item.quantity,
        'oldStock': item.product.currentStock,
        'newStock': item.product.currentStock - item.quantity,
        'soldTo': customerName,
        'timestamp': timestamp,
      });
    }

    await batch.commit();
  }
}