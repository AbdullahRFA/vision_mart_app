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
  Product? _selectedProduct;
  final _qtyController = TextEditingController(text: '1');

  // 3-Way Pricing Controllers
  final _discountPercentController = TextEditingController(text: '0');
  final _discountAmountController = TextEditingController(text: '0');
  final _finalPriceController = TextEditingController(text: '0');

  // Focus Nodes for Pricing Logic
  final _discPercentFocus = FocusNode();
  final _discAmountFocus = FocusNode();
  final _finalPriceFocus = FocusNode();

  String _paymentStatus = 'Cash';
  DateTime _selectedDate = DateTime.now();
  SalesDiscountType _discountType = SalesDiscountType.percentage;
  bool _isLoading = false;

  final List<CartItem> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.product;

    // Initial Calc if product passed
    if (_selectedProduct != null) {
      _resetPricingFields();
    }

    // CHECK FOR EDIT MODE
    if (widget.existingInvoice != null && widget.existingItems != null) {
      _loadExistingData();
    }

    // Attach Listeners
    _qtyController.addListener(_onQtyChanged);
    _discountPercentController.addListener(_onPercentChanged);
    _discountAmountController.addListener(_onAmountChanged);
    _finalPriceController.addListener(_onFinalPriceChanged);
  }

  // LOAD DATA FOR EDITING
  void _loadExistingData() async {
    final invoice = widget.existingInvoice!;

    // 1. Populate Customer & Payment Info
    _customerNameController.text = invoice['customerName'] ?? '';
    _customerPhoneController.text = invoice['customerPhone'] ?? '';
    _customerAddressController.text = invoice['customerAddress'] ?? '';
    _paymentStatus = invoice['paymentStatus'] ?? 'Cash';
    _paidAmountController.text = (invoice['paidAmount'] ?? 0).toString();

    // 2. Handle Date
    if (invoice['timestamp'] != null) {
      try {
        final ts = invoice['timestamp'];
        if (ts is Timestamp) _selectedDate = ts.toDate();
      } catch (e) {
        _selectedDate = DateTime.now();
      }
    }

    // 3. Reconstruct Cart Items
    // We need real Product objects to check stock limits and get buying prices
    final allProducts = await ref.read(inventoryStreamProvider.future);

    if (mounted) {
      setState(() {
        for (var itemData in widget.existingItems!) {
          final productId = itemData['productId'];
          // Find product in current inventory or create placeholder if deleted
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
                currentStock: 0 // Stock might be 0 until restored
            ),
          );

          _cartItems.add(CartItem(
            product: product,
            quantity: (itemData['quantity'] ?? 1).toInt(),
            discountPercent: (itemData['discountPercent'] ?? 0).toDouble(),
            finalPrice: (itemData['totalAmount'] ?? 0).toDouble(),
          ));
        }
      });
    }
  }

  // --- PRICING LOGIC ---

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

  // --- CART EDIT LOGIC ---
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
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Editing ${item.product.model}..."), duration: const Duration(milliseconds: 600)),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = DateTime(
          picked.year, picked.month, picked.day,
          DateTime.now().hour, DateTime.now().minute
      ));
    }
  }

  void _addToCart() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a product"), backgroundColor: Colors.red));
      return;
    }

    final qty = int.parse(_qtyController.text);

    // In edit mode, we skip local stock check warning because stock is yet to be restored
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
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added to Cart"), duration: Duration(milliseconds: 600)));
  }

  Future<void> _processBatchSale() async {
    if (_cartItems.isEmpty) return;
    if (_customerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter Customer Name")));
      return;
    }

    double totalCartAmount = 0;
    for (var item in _cartItems) totalCartAmount += item.finalPrice;

    double paidAmount = 0;
    if (_paymentStatus == 'Cash') {
      paidAmount = totalCartAmount;
    } else if (_paymentStatus == 'Due') {
      paidAmount = 0;
    } else if (_paymentStatus == 'Partial') {
      paidAmount = double.tryParse(_paidAmountController.text) ?? 0;
      if (paidAmount <= 0 || paidAmount >= totalCartAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Partial Amount must be greater than 0 and less than Total"))
        );
        return;
      }
    }

    double dueAmount = totalCartAmount - paidAmount;
    if(dueAmount < 0) dueAmount = 0;

    setState(() => _isLoading = true);
    try {
      // 1. IF UPDATING: Delete Old Invoice First (Restores Stock)
      // This is awaited, so it completes before we try to sell again
      if (widget.existingInvoice != null) {
        final oldInvoiceId = widget.existingInvoice!['id'];
        await ref.read(salesRepositoryProvider).deleteInvoiceAndRestoreStock(oldInvoiceId);
      }

      // 2. Create New Sale (Checks & Deducts Stock)
      // Since stock is restored in step 1, this will now succeed even for sold-out items
      await ref.read(salesRepositoryProvider).sellBatchProducts(
        items: _cartItems,
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        customerAddress: _customerAddressController.text.trim(),
        paymentStatus: _paymentStatus,
        paidAmount: paidAmount,
        saleDate: _selectedDate,
      );

      final soldItems = List<CartItem>.from(_cartItems);
      final cName = _customerNameController.text;
      final cPhone = _customerPhoneController.text;
      final cAddress = _customerAddressController.text;
      final payStatus = _paymentStatus;
      final sDate = _selectedDate;
      final pAmount = paidAmount;
      final dAmount = dueAmount;

      if (mounted) {
        if (widget.existingInvoice != null) {
          Navigator.pop(context); // Close Sell Screen
          Navigator.pop(context); // Close Detail Screen
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
          });
          _showSuccessDialog(soldItems, cName, cPhone, cAddress, payStatus, sDate, pAmount, dAmount);
        }
      }
    } catch (e) {
      // 👇 PRINT ERROR TO CONSOLE
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

    double cartTotal = 0;
    for (var i in _cartItems) cartTotal += i.finalPrice;

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

              // 2. ADD ITEM (UPDATED PRICING)
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

                    // Product Selector
                    inventoryAsync.when(
                      data: (products) {
                        return DropdownButtonFormField<Product>(
                          isExpanded: true,
                          value: _selectedProduct != null && products.any((p) => p.id == _selectedProduct!.id)
                              ? products.firstWhere((p) => p.id == _selectedProduct!.id)
                              : null,
                          hint: Text("Select Product", style: TextStyle(color: isDark ? Colors.white60 : Colors.grey)),
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: inputTextStyle,
                          items: products.map((p) {
                            return DropdownMenuItem(
                              value: p,
                              child: Text(
                                "${p.model} - ${p.name} (Stock: ${p.currentStock})",
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: p.currentStock == 0 ? Colors.redAccent : (isDark ? Colors.white : Colors.black87)),
                              ),
                            );
                          }).toList(),
                          onChanged: (p) {
                            setState(() {
                              _selectedProduct = p;
                              _resetPricingFields();
                            });
                          },
                          decoration: _inputDecor("Product"),
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
                        // Discount Type Toggle
                        ToggleButtons(
                          borderRadius: BorderRadius.circular(8),
                          constraints: const BoxConstraints(minHeight: 48, minWidth: 60),
                          isSelected: [_discountType == SalesDiscountType.percentage, _discountType == SalesDiscountType.flat],
                          onPressed: (index) {
                            setState(() {
                              _discountType = index == 0 ? SalesDiscountType.percentage : SalesDiscountType.flat;
                              // Force re-calc just in case field focus logic misses
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
                        // DISCOUNT INPUT
                        Expanded(
                          child: TextFormField(
                            // Swap controller based on Type
                            controller: _discountType == SalesDiscountType.percentage ? _discountPercentController : _discountAmountController,
                            focusNode: _discountType == SalesDiscountType.percentage ? _discPercentFocus : _discAmountFocus,
                            keyboardType: TextInputType.number,
                            style: inputTextStyle,
                            decoration: _inputDecor(_discountType == SalesDiscountType.percentage ? "Disc %" : "Disc Amt"),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // FINAL PRICE INPUT (Manual Override)
                        Expanded(
                          child: TextFormField(
                            controller: _finalPriceController,
                            focusNode: _finalPriceFocus,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                            decoration: _inputDecor("Sold Price"),
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
                            onPressed: () => setState(() => _cartItems.removeAt(index)),
                            tooltip: "Remove Item",
                          ),
                        ],
                      ),
                    ),
                  );
                },
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

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: isDark ? Colors.black45 : Colors.black26, blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Grand Total:", style: TextStyle(color: Colors.white70, fontSize: 16)),
                    Text(
                      "৳${cartTotal.toStringAsFixed(0)}",
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (_isLoading || _cartItems.isEmpty) ? null : _processBatchSale,
                  icon: Icon(isEditing ? Icons.update : Icons.check_circle),
                  label: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isEditing ? "UPDATE INVOICE (CORRECT MISTAKE)" : "CONFIRM BATCH SALE"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEditing ? Colors.orange : Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
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