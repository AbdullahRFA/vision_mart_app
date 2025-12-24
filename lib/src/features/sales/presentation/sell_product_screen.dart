import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../inventory/domain/product_model.dart';
import '../../inventory/data/inventory_repository.dart';
import '../data/sales_repository.dart';
import 'pdf_generator.dart';

class SellProductScreen extends ConsumerStatefulWidget {
  // 1. CHANGED: Made product optional (nullable)
  final Product? product;
  const SellProductScreen({super.key, this.product});

  @override
  ConsumerState<SellProductScreen> createState() => _SellProductScreenState();
}

class _SellProductScreenState extends ConsumerState<SellProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Customer Info
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerAddressController = TextEditingController();

  // Controller for Partial Payment
  final _paidAmountController = TextEditingController();

  // Item Details
  Product? _selectedProduct;
  final _qtyController = TextEditingController(text: '1');
  final _discountController = TextEditingController(text: '0');

  String _paymentStatus = 'Cash';
  DateTime _selectedDate = DateTime.now();
  double _currentLineTotal = 0.0;
  bool _isLoading = false;

  final List<CartItem> _cartItems = [];

  @override
  void initState() {
    super.initState();
    // 2. CHANGED: Initialize with widget.product (which might be null now)
    _selectedProduct = widget.product;
    _calculateLineTotal();
    _qtyController.addListener(_calculateLineTotal);
    _discountController.addListener(_calculateLineTotal);
  }

  // Date Picker Logic
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

  void _calculateLineTotal() {
    if (_selectedProduct == null) return;
    final qty = int.tryParse(_qtyController.text) ?? 0;
    final discount = double.tryParse(_discountController.text) ?? 0;
    if (qty > 0) {
      final unitPrice = _selectedProduct!.marketPrice - (_selectedProduct!.marketPrice * (discount / 100));
      setState(() => _currentLineTotal = unitPrice * qty);
    }
  }

  void _addToCart() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a product"), backgroundColor: Colors.red));
      return;
    }

    final qty = int.parse(_qtyController.text);
    if (qty > _selectedProduct!.currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insufficient Stock! Max: ${_selectedProduct!.currentStock}'), backgroundColor: Colors.red),
      );
      return;
    }

    final item = CartItem(
      product: _selectedProduct!,
      quantity: qty,
      discountPercent: double.parse(_discountController.text),
      finalPrice: _currentLineTotal,
    );

    setState(() {
      _cartItems.add(item);
      _qtyController.text = '1';
      // Optional: Clear selection after add if you prefer
      // _selectedProduct = null;
      _calculateLineTotal();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added to Cart"), duration: Duration(milliseconds: 600)));
  }

  Future<void> _processBatchSale() async {
    if (_cartItems.isEmpty) return;
    if (_customerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter Customer Name")));
      return;
    }

    // 1. Calculate Total Amount
    double totalCartAmount = 0;
    for (var item in _cartItems) totalCartAmount += item.finalPrice;

    // 2. Determine Paid Amount based on Status
    double paidAmount = 0;
    if (_paymentStatus == 'Cash') {
      paidAmount = totalCartAmount;
    } else if (_paymentStatus == 'Due') {
      paidAmount = 0;
    } else if (_paymentStatus == 'Partial') {
      paidAmount = double.tryParse(_paidAmountController.text) ?? 0;

      // Validation for Partial
      if (paidAmount <= 0 || paidAmount >= totalCartAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Partial Amount must be greater than 0 and less than Total"))
        );
        return;
      }
    }

    // 3. Calculate Due for display/PDF
    double dueAmount = totalCartAmount - paidAmount;
    if(dueAmount < 0) dueAmount = 0;

    setState(() => _isLoading = true);
    try {
      await ref.read(salesRepositoryProvider).sellBatchProducts(
        items: _cartItems,
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        customerAddress: _customerAddressController.text.trim(),
        paymentStatus: _paymentStatus,
        paidAmount: paidAmount,
        saleDate: _selectedDate,
      );

      // Capture values for the Success Dialog
      final soldItems = List<CartItem>.from(_cartItems);
      final cName = _customerNameController.text;
      final cPhone = _customerPhoneController.text;
      final cAddress = _customerAddressController.text;
      final payStatus = _paymentStatus;
      final sDate = _selectedDate;
      final pAmount = paidAmount;
      final dAmount = dueAmount;

      if (mounted) {
        setState(() {
          _cartItems.clear();
          _customerNameController.clear();
          _customerPhoneController.clear();
          _customerAddressController.clear();
          _paidAmountController.clear();
          _selectedDate = DateTime.now();
          _paymentStatus = 'Cash';
          _selectedProduct = null; // Reset selection
        });

        // Pass amounts to the dialog
        _showSuccessDialog(soldItems, cName, cPhone, cAddress, payStatus, sDate, pAmount, dAmount);
      }
    } catch (e) {
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

    double cartTotal = 0;
    for (var i in _cartItems) cartTotal += i.finalPrice;

    return Scaffold(
      appBar: AppBar(title: const Text("New Sale (POS)")),
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

              // Address Field
              TextFormField(
                controller: _customerAddressController,
                style: inputTextStyle,
                decoration: _inputDecor("Customer Address", Icons.location_on_outlined),
              ),
              const SizedBox(height: 10),

              // DATE PICKER
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: _inputDecor("Sale Date", Icons.calendar_today),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy').format(_selectedDate),
                        style: inputTextStyle,
                      ),
                      Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 2. ADD ITEM SECTION
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

                    // Product Dropdown
                    inventoryAsync.when(
                      data: (products) {
                        return DropdownButtonFormField<Product>(
                          isExpanded: true,
                          // Ensure selected product is valid in the list
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
                                style: TextStyle(
                                    color: p.currentStock == 0 ? Colors.redAccent : (isDark ? Colors.white : Colors.black87)
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (p) {
                            setState(() {
                              _selectedProduct = p;
                              _calculateLineTotal();
                            });
                          },
                          decoration: _inputDecor("Product"),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, s) => Text("Error: $e"),
                    ),
                    const SizedBox(height: 10),

                    // Qty & Discount
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            style: inputTextStyle,
                            decoration: _inputDecor("Qty"),
                            onChanged: (_) => _calculateLineTotal(),
                            validator: (v) => (int.tryParse(v ?? '0') ?? 0) <= 0 ? 'Invalid' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _discountController,
                            keyboardType: TextInputType.number,
                            style: inputTextStyle,
                            decoration: _inputDecor("Disc %"),
                            onChanged: (_) => _calculateLineTotal(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Item Total & Add Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            "Total: ৳${_currentLineTotal.toStringAsFixed(0)}",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.greenAccent : Theme.of(context).primaryColor)
                        ),
                        ElevatedButton.icon(
                          onPressed: _addToCart,
                          icon: const Icon(Icons.add_shopping_cart, size: 18),
                          label: const Text("Add"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.green : Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        )
                      ],
                    )
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
                          "${item.quantity} x ৳${item.product.marketPrice} (-${item.discountPercent}%)",
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700])
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("৳${item.finalPrice.toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.greenAccent : Colors.black)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => setState(() => _cartItems.removeAt(index)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // 4. CHECKOUT
              _SectionHeader(title: "Payment Info", icon: Icons.payment),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: _paymentStatus,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: inputTextStyle,
                // Partial Added
                items: ['Cash', 'Due', 'Partial'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: inputTextStyle))).toList(),
                onChanged: (v) => setState(() => _paymentStatus = v!),
                decoration: _inputDecor("Payment Type", Icons.payment),
              ),

              // Conditional Paid Amount Field
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
                  icon: const Icon(Icons.check_circle),
                  label: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("CONFIRM BATCH SALE"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
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