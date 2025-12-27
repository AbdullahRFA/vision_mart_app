import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../inventory/domain/product_model.dart';
import '../../inventory/data/inventory_repository.dart';
import '../data/sales_repository.dart';
import 'pdf_generator.dart';

class SellProductScreen extends ConsumerStatefulWidget {
  final Product? product;
  // Optional params for Editing
  final Map<String, dynamic>? existingInvoice;
  final List<Map<String, dynamic>>? existingItems;

  const SellProductScreen({
    super.key,
    this.product,
    this.existingInvoice,
    this.existingItems,
  });

  @override
  ConsumerState<SellProductScreen> createState() => _SellProductScreenState();
}

enum SalesDiscountType { percentage, flat }

class _SellProductScreenState extends ConsumerState<SellProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Customer Info
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerAddressController = TextEditingController();

  // Payment
  final _paidAmountController = TextEditingController();

  // Item Details
  Product? _selectedProduct; // Used for Single Selection Form
  final _qtyController = TextEditingController(text: '1');

  // 3-Way Pricing Controllers (Item Level)
  final _discountPercentController = TextEditingController(text: '0');
  final _discountAmountController = TextEditingController(text: '0');
  final _finalPriceController = TextEditingController(text: '0');

  // Focus Nodes (Item Level)
  final _discPercentFocus = FocusNode();
  final _discAmountFocus = FocusNode();
  final _finalPriceFocus = FocusNode();

  // --- NEW: Global Discount / Grand Total Controllers ---
  final _globalDiscPercentController = TextEditingController(text: '0');
  final _globalDiscAmtController = TextEditingController(text: '0');
  final _globalGrandTotalController = TextEditingController(text: '0');

  // Focus Nodes (Global)
  final _globalDiscPercentFocus = FocusNode();
  final _globalDiscAmtFocus = FocusNode();
  final _globalGrandTotalFocus = FocusNode();

  String _paymentStatus = 'Cash';
  DateTime _selectedDate = DateTime.now();
  SalesDiscountType _discountType = SalesDiscountType.percentage;

  // Track Global Discount Type (default %)
  SalesDiscountType _globalDiscountType = SalesDiscountType.percentage;

  bool _isLoading = false;

  final List<CartItem> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.product;

    if (_selectedProduct != null) {
      _resetPricingFields();
    }

    if (widget.existingInvoice != null && widget.existingItems != null) {
      _loadExistingData();
    }

    // Attach Listeners (Item Level)
    _qtyController.addListener(_onQtyChanged);
    _discountPercentController.addListener(_onPercentChanged);
    _discountAmountController.addListener(_onAmountChanged);
    _finalPriceController.addListener(_onFinalPriceChanged);

    // Attach Listeners (Global Level)
    _globalDiscPercentController.addListener(_onGlobalPercentChanged);
    _globalDiscAmtController.addListener(_onGlobalAmountChanged);
    _globalGrandTotalController.addListener(_onGlobalTotalChanged);
  }

  void _loadExistingData() async {
    final invoice = widget.existingInvoice!;
    _customerNameController.text = invoice['customerName'] ?? '';
    _customerPhoneController.text = invoice['customerPhone'] ?? '';
    _customerAddressController.text = invoice['customerAddress'] ?? '';
    _paymentStatus = invoice['paymentStatus'] ?? 'Cash';
    _paidAmountController.text = (invoice['paidAmount'] ?? 0).toString();

    if (invoice['timestamp'] != null) {
      try {
        final ts = invoice['timestamp'];
        if (ts is Timestamp) _selectedDate = ts.toDate();
      } catch (e) {
        _selectedDate = DateTime.now();
      }
    }

    final allProducts = await ref.read(inventoryStreamProvider.future);

    if (mounted) {
      setState(() {
        for (var itemData in widget.existingItems!) {
          final productId = itemData['productId'];
          final product = allProducts.firstWhere(
                (p) => p.id == productId,
            orElse: () => Product(
                id: productId,
                name: itemData['productName'] ?? 'Unknown',
                model: itemData['productModel'] ?? '',
                category: 'Unknown',
                capacity: '',
                marketPrice: (itemData['mrp'] ?? 0).toDouble(),
                commissionPercent: 0,
                buyingPrice: 0,
                currentStock: 0),
          );

          _cartItems.add(CartItem(
            product: product,
            quantity: (itemData['quantity'] ?? 1).toInt(),
            discountPercent: (itemData['discountPercent'] ?? 0).toDouble(),
            finalPrice: (itemData['totalAmount'] ?? 0).toDouble(),
          ));
        }
        // Recalculate totals after loading
        _recalculateGlobalValues();
      });
    }
  }

  // --- ITEM PRICING LOGIC ---
  void _resetPricingFields() {
    if (_selectedProduct == null) return;
    double mrp = _selectedProduct!.marketPrice;
    int qty = int.tryParse(_qtyController.text) ?? 1;
    double totalMrp = mrp * qty;

    _finalPriceController.text = totalMrp.toStringAsFixed(0);
    _discountPercentController.text = '0';
    _discountAmountController.text = '0';
  }

  void _onQtyChanged() {
    if (_selectedProduct == null) return;
    _onPercentChanged();
  }

  void _onPercentChanged() {
    if (!_discPercentFocus.hasFocus && _discPercentFocus.hasPrimaryFocus) return;
    if (_selectedProduct == null) return;

    double mrp = _selectedProduct!.marketPrice;
    int qty = int.tryParse(_qtyController.text) ?? 1;
    double totalMrp = mrp * qty;

    double percent = double.tryParse(_discountPercentController.text) ?? 0;
    double discountAmt = totalMrp * (percent / 100);
    double finalPrice = totalMrp - discountAmt;

    if (_discountAmountController.text != discountAmt.toStringAsFixed(0)) {
      _discountAmountController.text = discountAmt.toStringAsFixed(0);
    }
    if (_finalPriceController.text != finalPrice.toStringAsFixed(0)) {
      _finalPriceController.text = finalPrice.toStringAsFixed(0);
    }
  }

  void _onAmountChanged() {
    if (!_discAmountFocus.hasFocus) return;
    if (_selectedProduct == null) return;

    double mrp = _selectedProduct!.marketPrice;
    int qty = int.tryParse(_qtyController.text) ?? 1;
    double totalMrp = mrp * qty;
    if (totalMrp == 0) return;

    double discountAmt = double.tryParse(_discountAmountController.text) ?? 0;
    double percent = (discountAmt / totalMrp) * 100;
    double finalPrice = totalMrp - discountAmt;

    _discountPercentController.text = percent.toStringAsFixed(2);
    _finalPriceController.text = finalPrice.toStringAsFixed(0);
  }

  void _onFinalPriceChanged() {
    if (!_finalPriceFocus.hasFocus) return;
    if (_selectedProduct == null) return;

    double mrp = _selectedProduct!.marketPrice;
    int qty = int.tryParse(_qtyController.text) ?? 1;
    double totalMrp = mrp * qty;
    if (totalMrp == 0) return;

    double finalPrice = double.tryParse(_finalPriceController.text) ?? 0;
    double discountAmt = totalMrp - finalPrice;
    double percent = (discountAmt / totalMrp) * 100;

    _discountAmountController.text = discountAmt.toStringAsFixed(0);
    _discountPercentController.text = percent.toStringAsFixed(2);
  }

  // --- NEW: GLOBAL PRICING LOGIC ---

  double get _cartSubTotal => _cartItems.fold(0, (sum, item) => sum + item.finalPrice);

  void _recalculateGlobalValues() {
    // Default to preserving the Percentage logic when items change
    _onGlobalPercentChanged(force: true);
  }

  void _onGlobalPercentChanged({bool force = false}) {
    if (!_globalDiscPercentFocus.hasFocus && !force) return;

    double subTotal = _cartSubTotal;
    double percent = double.tryParse(_globalDiscPercentController.text) ?? 0;
    double discountAmt = subTotal * (percent / 100);
    double grandTotal = subTotal - discountAmt;

    if (_globalDiscAmtController.text != discountAmt.toStringAsFixed(0)) {
      _globalDiscAmtController.text = discountAmt.toStringAsFixed(0);
    }
    if (_globalGrandTotalController.text != grandTotal.toStringAsFixed(0)) {
      _globalGrandTotalController.text = grandTotal.toStringAsFixed(0);
    }
  }

  void _onGlobalAmountChanged() {
    if (!_globalDiscAmtFocus.hasFocus) return;

    double subTotal = _cartSubTotal;
    if (subTotal == 0) return;

    double discountAmt = double.tryParse(_globalDiscAmtController.text) ?? 0;
    double percent = (discountAmt / subTotal) * 100;
    double grandTotal = subTotal - discountAmt;

    _globalDiscPercentController.text = percent.toStringAsFixed(2);
    _globalGrandTotalController.text = grandTotal.toStringAsFixed(0);
  }

  void _onGlobalTotalChanged() {
    if (!_globalGrandTotalFocus.hasFocus) return;

    double subTotal = _cartSubTotal;
    if (subTotal == 0) return;

    double grandTotal = double.tryParse(_globalGrandTotalController.text) ?? 0;
    double discountAmt = subTotal - grandTotal;
    double percent = (discountAmt / subTotal) * 100;

    _globalDiscAmtController.text = discountAmt.toStringAsFixed(0);
    _globalDiscPercentController.text = percent.toStringAsFixed(2);
  }

  // --- SHOW PRODUCT SELECTION DIALOG ---
  void _openProductSelector(List<Product> allProducts) async {
    final List<Product>? results = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductSelectionSheet(products: allProducts),
    );

    if (results != null && results.isNotEmpty) {
      if (results.length == 1) {
        setState(() {
          _selectedProduct = results.first;
          _resetPricingFields();
        });
      } else {
        setState(() {
          for (var p in results) {
            _cartItems.add(CartItem(
              product: p,
              quantity: 1,
              discountPercent: 0,
              finalPrice: p.marketPrice,
            ));
          }
          _selectedProduct = null;
          _resetPricingFields();
          _recalculateGlobalValues(); // Update total
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${results.length} items added to cart")),
        );
      }
    }
  }

  void _addToCart() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a product"), backgroundColor: Colors.red));
      return;
    }

    final qty = int.parse(_qtyController.text);
    if (qty > _selectedProduct!.currentStock && widget.existingInvoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insufficient Stock! Max: ${_selectedProduct!.currentStock}'), backgroundColor: Colors.red),
      );
      return;
    }

    final item = CartItem(
      product: _selectedProduct!,
      quantity: qty,
      discountPercent: double.tryParse(_discountPercentController.text) ?? 0,
      finalPrice: double.tryParse(_finalPriceController.text) ?? 0,
    );

    setState(() {
      _cartItems.add(item);
      _qtyController.text = '1';
      _selectedProduct = null;
      _finalPriceController.text = '0';
      _discountPercentController.text = '0';
      _discountAmountController.text = '0';
      _recalculateGlobalValues(); // Update totals
    });
  }

  void _editCartItem(int index) {
    final item = _cartItems[index];
    setState(() {
      _cartItems.removeAt(index);
      _selectedProduct = item.product;
      _qtyController.text = item.quantity.toString();
      _finalPriceController.text = item.finalPrice.toStringAsFixed(0);
      _discountPercentController.text = item.discountPercent.toStringAsFixed(2);
      double totalMrp = item.product.marketPrice * item.quantity;
      double distAmt = totalMrp - item.finalPrice;
      _discountAmountController.text = distAmt.toStringAsFixed(0);
      _discountType = SalesDiscountType.percentage;
      _recalculateGlobalValues(); // Update totals
    });
  }

  // --- PREVIEW LOGIC (NEW) ---
  void _previewInvoice() {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cart is empty")));
      return;
    }
    // Basic validation for preview
    if (_customerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter Customer Name to preview")));
      return;
    }

    // 1. Calculate final values (mirroring sale logic)
    final double finalGrandTotal = double.tryParse(_globalGrandTotalController.text) ?? _cartSubTotal;
    final double subTotal = _cartSubTotal;

    List<CartItem> previewItems = [];

    if (subTotal == 0) {
      previewItems = List.from(_cartItems);
    } else {
      final double adjustmentRatio = finalGrandTotal / subTotal;
      for (var item in _cartItems) {
        final double adjustedPrice = item.finalPrice * adjustmentRatio;
        final double totalMrp = item.product.marketPrice * item.quantity;

        // Calculate effective discount
        final double newDiscountPercent = totalMrp > 0
            ? ((totalMrp - adjustedPrice) / totalMrp) * 100
            : 0;

        previewItems.add(CartItem(
          product: item.product,
          quantity: item.quantity,
          discountPercent: newDiscountPercent,
          finalPrice: adjustedPrice,
        ));
      }
    }

    double paidAmount = 0;
    if (_paymentStatus == 'Cash') {
      paidAmount = finalGrandTotal;
    } else if (_paymentStatus == 'Due') {
      paidAmount = 0;
    } else if (_paymentStatus == 'Partial') {
      paidAmount = double.tryParse(_paidAmountController.text) ?? 0;
    }

    double dueAmount = finalGrandTotal - paidAmount;
    if (dueAmount < 0) dueAmount = 0;

    // 2. Generate PDF (without saving to DB)
    PdfGenerator.generateBatchInvoice(
      items: previewItems,
      customerName: _customerNameController.text.trim(),
      customerPhone: _customerPhoneController.text.trim(),
      customerAddress: _customerAddressController.text.trim(),
      paymentStatus: _paymentStatus,
      paidAmount: paidAmount,
      dueAmount: dueAmount,
      saleDate: _selectedDate,
    );
  }

  Future<void> _processBatchSale() async {
    if (_cartItems.isEmpty) return;
    if (_customerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter Customer Name")));
      return;
    }

    // 1. Calculate Actual Final Grand Total (User adjusted)
    final double finalGrandTotal = double.tryParse(_globalGrandTotalController.text) ?? _cartSubTotal;
    final double subTotal = _cartSubTotal;

    // 2. Prepare Final Items List with Adjusted Prices (Prorated)
    List<CartItem> finalItemsToSell = [];

    if (subTotal == 0) {
      finalItemsToSell = List.from(_cartItems);
    } else {
      // Calculate ratio to distribute the global discount/override
      final double adjustmentRatio = finalGrandTotal / subTotal;

      for (var item in _cartItems) {
        final double adjustedPrice = item.finalPrice * adjustmentRatio;

        // Recalculate discount percent for the record based on original MRP vs New Adjusted Price
        final double totalMrp = item.product.marketPrice * item.quantity;
        final double newDiscountPercent = totalMrp > 0
            ? ((totalMrp - adjustedPrice) / totalMrp) * 100
            : 0;

        finalItemsToSell.add(CartItem(
          product: item.product,
          quantity: item.quantity,
          discountPercent: newDiscountPercent, // Updated discount
          finalPrice: adjustedPrice, // Updated price
        ));
      }
    }

    // 3. Payment logic uses finalGrandTotal
    double paidAmount = 0;
    if (_paymentStatus == 'Cash') {
      paidAmount = finalGrandTotal;
    } else if (_paymentStatus == 'Due') {
      paidAmount = 0;
    } else if (_paymentStatus == 'Partial') {
      paidAmount = double.tryParse(_paidAmountController.text) ?? 0;
    }

    double dueAmount = finalGrandTotal - paidAmount;
    if (dueAmount < 0) dueAmount = 0;

    setState(() => _isLoading = true);
    try {
      if (widget.existingInvoice != null) {
        final oldInvoiceId = widget.existingInvoice!['id'];
        await ref.read(salesRepositoryProvider).deleteInvoiceAndRestoreStock(oldInvoiceId);
      }

      // Pass the adjusted items (with prorated prices) to repository
      // The repository calculates Profit = FinalPrice - BuyingPrice.
      // Since FinalPrice is now adjusted for global discount, Profit will be accurate.
      await ref.read(salesRepositoryProvider).sellBatchProducts(
        items: finalItemsToSell,
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        customerAddress: _customerAddressController.text.trim(),
        paymentStatus: _paymentStatus,
        paidAmount: paidAmount,
        saleDate: _selectedDate,
      );

      final soldItems = List<CartItem>.from(finalItemsToSell);
      final cName = _customerNameController.text;
      final cPhone = _customerPhoneController.text;
      final cAddress = _customerAddressController.text;
      final payStatus = _paymentStatus;
      final sDate = _selectedDate;
      final pAmount = paidAmount;
      final dAmount = dueAmount;

      if (mounted) {
        if (widget.existingInvoice != null) {
          Navigator.pop(context);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invoice Updated Successfully")));
        } else {
          setState(() {
            _cartItems.clear();
            _customerNameController.clear();
            _customerPhoneController.clear();
            _customerAddressController.clear();
            _paidAmountController.clear();
            _selectedDate = DateTime.now();
            _paymentStatus = 'Cash';
            _selectedProduct = null;
            _resetPricingFields();
            _recalculateGlobalValues();
          });
          _showSuccessDialog(soldItems, cName, cPhone, cAddress, payStatus, sDate, pAmount, dAmount);
        }
      }
    } catch (e) {
      debugPrint('Error updating/processing invoice: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(List<CartItem> items, String name, String phone, String address, String status, DateTime date, double paidAmount, double dueAmount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
        title: Text("Sale Successful", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Text("${items.length} items sold.\nGenerate invoice now?", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text("Close", style: TextStyle(color: isDark ? Colors.redAccent : Colors.grey)),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.print_rounded),
            label: const Text("Print Invoice"),
            style: FilledButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              PdfGenerator.generateBatchInvoice(
                items: items,
                customerName: name,
                customerPhone: phone,
                customerAddress: address,
                paymentStatus: status,
                paidAmount: paidAmount,
                dueAmount: dueAmount,
                saleDate: date,
              );
              Navigator.pop(context);
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputTextStyle = TextStyle(color: isDark ? Colors.white : Colors.black87);
    final isEditing = widget.existingInvoice != null;

    // Use current subtotal state
    double cartSubTotal = _cartSubTotal;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? "Edit Invoice (Correction)" : "New Sale (POS)")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. CUSTOMER INFO
              _SectionHeader(title: "Customer Info", icon: Icons.person),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _customerNameController,
                      style: inputTextStyle,
                      decoration: _inputDecor("Customer Name", Icons.person_outline),
                      validator: (v) => v!.isEmpty ? 'Req' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _customerPhoneController,
                      style: inputTextStyle,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecor("Phone", Icons.phone),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _customerAddressController,
                style: inputTextStyle,
                decoration: _inputDecor("Customer Address", Icons.location_on_outlined),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: _inputDecor("Sale Date", Icons.calendar_today),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: inputTextStyle),
                      Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 2. PRODUCT SELECTION & ADD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Add Item to Cart", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 12),

                    inventoryAsync.when(
                      data: (products) {
                        return InkWell(
                          onTap: () => _openProductSelector(products),
                          child: InputDecorator(
                            decoration: _inputDecor("Select Product", Icons.search),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedProduct != null
                                        ? "${_selectedProduct!.model} - ${_selectedProduct!.name}"
                                        : "Tap to search & select products...",
                                    style: TextStyle(
                                      color: _selectedProduct != null
                                          ? (isDark ? Colors.white : Colors.black87)
                                          : (isDark ? Colors.white54 : Colors.grey),
                                      fontWeight: _selectedProduct != null ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                              ],
                            ),
                          ),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, s) => Text("Error: $e"),
                    ),
                    const SizedBox(height: 10),

                    // Qty Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            style: inputTextStyle,
                            decoration: _inputDecor("Qty"),
                            validator: (v) => (int.tryParse(v ?? '0') ?? 0) <= 0 ? 'Invalid' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        ToggleButtons(
                          borderRadius: BorderRadius.circular(8),
                          constraints: const BoxConstraints(minHeight: 48, minWidth: 60),
                          isSelected: [_discountType == SalesDiscountType.percentage, _discountType == SalesDiscountType.flat],
                          onPressed: (index) {
                            setState(() {
                              _discountType = index == 0 ? SalesDiscountType.percentage : SalesDiscountType.flat;
                              _onPercentChanged();
                            });
                          },
                          children: const [Text("%"), Text("Tk")],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 3-Way Pricing Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _discountType == SalesDiscountType.percentage ? _discountPercentController : _discountAmountController,
                            focusNode: _discountType == SalesDiscountType.percentage ? _discPercentFocus : _discAmountFocus,
                            keyboardType: TextInputType.number,
                            style: inputTextStyle,
                            decoration: _inputDecor(_discountType == SalesDiscountType.percentage ? "Disc %" : "Disc Amt"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _finalPriceController,
                            focusNode: _finalPriceFocus,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                            decoration: _inputDecor("Item Price"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addToCart,
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text("Add Item"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.green : Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. CART LIST
              _SectionHeader(title: "Cart Items (${_cartItems.length})", icon: Icons.shopping_basket_outlined),
              const SizedBox(height: 10),

              if (_cartItems.isEmpty)
                Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("Cart is empty", style: TextStyle(color: isDark ? Colors.white60 : Colors.grey)))),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _cartItems.length,
                itemBuilder: (context, index) {
                  final item = _cartItems[index];
                  return Card(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
                        child: Text("${index + 1}", style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black)),
                      ),
                      title: Text(item.product.model, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      subtitle: Text(
                          "${item.quantity} x ৳${item.product.marketPrice} (-${item.discountPercent.toStringAsFixed(1)}%)",
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700])
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("৳${item.finalPrice.toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.greenAccent : Colors.black)),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                            onPressed: () => _editCartItem(index),
                            tooltip: "Edit Item",
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => setState(() {
                              _cartItems.removeAt(index);
                              _recalculateGlobalValues();
                            }),
                            tooltip: "Remove Item",
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // ----------------------------------------------------
              // 👇 NEW: TOTAL SUMMARY & GLOBAL ADJUSTMENT SECTION
              // ----------------------------------------------------
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: isDark ? Colors.black45 : Colors.black26, blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: [
                    // SUBTOTAL
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Subtotal:", style: TextStyle(color: Colors.white70, fontSize: 14)),
                        Text(
                          "৳${cartSubTotal.toStringAsFixed(0)}",
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 20),

                    // GLOBAL DISCOUNT CONTROLS
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Global Disc %", style: TextStyle(color: Colors.white54, fontSize: 10)),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 40,
                                child: TextFormField(
                                  controller: _globalDiscPercentController,
                                  focusNode: _globalDiscPercentFocus,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white12,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Flat Discount", style: TextStyle(color: Colors.white54, fontSize: 10)),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 40,
                                child: TextFormField(
                                  controller: _globalDiscAmtController,
                                  focusNode: _globalDiscAmtFocus,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white12,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // FINAL GRAND TOTAL
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: const Text("Net Payable:", style: TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _globalGrandTotalController,
                            focusNode: _globalGrandTotalFocus,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.end,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              prefixText: "৳",
                              prefixStyle: TextStyle(color: Colors.greenAccent, fontSize: 22),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. PAYMENT
              _SectionHeader(title: "Payment Info", icon: Icons.payment),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: _paymentStatus,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: inputTextStyle,
                items: ['Cash', 'Due', 'Partial'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: inputTextStyle))).toList(),
                onChanged: (v) => setState(() => _paymentStatus = v!),
                decoration: _inputDecor("Payment Type", Icons.payment),
              ),

              if (_paymentStatus == 'Partial') ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _paidAmountController,
                  keyboardType: TextInputType.number,
                  style: inputTextStyle,
                  decoration: _inputDecor("Paid Amount (Tk)", Icons.attach_money),
                ),
              ],

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _cartItems.isEmpty ? null : _previewInvoice,
                        icon: const Icon(Icons.visibility),
                        label: const Text("PREVIEW"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : Theme.of(context).primaryColor,
                          side: BorderSide(color: isDark ? Colors.white54 : Theme.of(context).primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: (_isLoading || _cartItems.isEmpty) ? null : _processBatchSale,
                        icon: Icon(isEditing ? Icons.update : Icons.check_circle),
                        label: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(isEditing ? "UPDATE SALE" : "CONFIRM SALE"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isEditing ? Colors.orange : Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  InputDecoration _inputDecor(String label, [IconData? icon]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.yellowAccent : Colors.grey[700]),
      prefixIcon: icon != null ? Icon(icon, size: 20, color: isDark ? Colors.white60 : Colors.grey) : null,
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey[50],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? Colors.yellowAccent : Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: isDark ? Colors.yellowAccent : Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}

// --------------------------------------------------------
// 👇 NEW WIDGET: Advanced Product Selection Sheet
// --------------------------------------------------------
class _ProductSelectionSheet extends StatefulWidget {
  final List<Product> products;
  const _ProductSelectionSheet({required this.products});

  @override
  State<_ProductSelectionSheet> createState() => _ProductSelectionSheetState();
}

class _ProductSelectionSheetState extends State<_ProductSelectionSheet> {
  String _searchQuery = "";
  String _selectedCategory = "All";
  final Set<Product> _selectedProducts = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.grey.shade50;

    // 1. Extract Categories
    final categories = ["All", ...widget.products.map((p) => p.category).toSet().toList()];

    // 2. Filter Products
    final filteredProducts = widget.products.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.model.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == "All" || p.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Select Products", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selectedProducts.toList()),
                  child: Text("Done (${_selectedProducts.length})"),
                )
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: "Search by Model or Name...",
                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Categories List
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              itemBuilder: (ctx, index) {
                final cat = categories[index];
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (v) => setState(() => _selectedCategory = cat),
                    backgroundColor: cardColor,
                    selectedColor: Colors.blue.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.blue : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                  ),
                );
              },
            ),
          ),

          const Divider(),

          // Product List
          Expanded(
            child: filteredProducts.isEmpty
                ? Center(child: Text("No products found", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredProducts.length,
              itemBuilder: (ctx, index) {
                final product = filteredProducts[index];
                final isSelected = _selectedProducts.any((p) => p.id == product.id);
                final hasStock = product.currentStock > 0;

                return Card(
                  color: isSelected ? Colors.blue.withOpacity(0.1) : cardColor,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isSelected ? const BorderSide(color: Colors.blue) : BorderSide.none,
                  ),
                  child: ListTile(
                    enabled: hasStock,
                    leading: Checkbox(
                      value: isSelected,
                      onChanged: hasStock ? (val) {
                        setState(() {
                          if (val == true) {
                            _selectedProducts.add(product);
                          } else {
                            _selectedProducts.removeWhere((p) => p.id == product.id);
                          }
                        });
                      } : null,
                    ),
                    title: Text(product.model, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name, style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[700])),
                        Text("Stock: ${product.currentStock}", style: TextStyle(color: hasStock ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    trailing: Text("৳${product.marketPrice}", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                    onTap: hasStock ? () {
                      setState(() {
                        if (isSelected) {
                          _selectedProducts.removeWhere((p) => p.id == product.id);
                        } else {
                          _selectedProducts.add(product);
                        }
                      });
                    } : null,
                  ),
                );
              },
            ),
          ),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selectedProducts.isEmpty ? null : () => Navigator.pop(context, _selectedProducts.toList()),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                child: Text("ADD ${_selectedProducts.length} ITEMS TO CART"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}