import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../inventory/domain/product_model.dart';
import '../../inventory/data/inventory_repository.dart'; // Needed for provider
import '../data/sales_repository.dart';
import 'pdf_generator.dart';

class SellProductScreen extends ConsumerStatefulWidget {
  final Product product;
  // We keep 'product' as the "initial" selection
  const SellProductScreen({super.key, required this.product});

  @override
  ConsumerState<SellProductScreen> createState() => _SellProductScreenState();
}

class _SellProductScreenState extends ConsumerState<SellProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Customer Info (Global for Invoice)
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();

  // Item Details
  Product? _selectedProduct;
  final _qtyController = TextEditingController(text: '1');
  final _discountController = TextEditingController(text: '0');

  String _paymentStatus = 'Cash';
  double _currentLineTotal = 0.0;

  bool _isLoading = false;
  bool _isWholesale = false;

  // The Cart
  final List<CartItem> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.product;
    _calculateLineTotal();
    _qtyController.addListener(_calculateLineTotal);
    _discountController.addListener(_calculateLineTotal);
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
    if (_selectedProduct == null) return;

    final qty = int.parse(_qtyController.text);

    // Check Stock
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
      // Reset Item fields
      _qtyController.text = '1';
      // We keep discount same for convenience or reset it
      _calculateLineTotal();
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added to Cart"), duration: Duration(milliseconds: 600)));
  }

  Future<void> _processBatchSale() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cart is empty!")));
      return;
    }
    if (_customerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter Customer Name")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(salesRepositoryProvider).sellBatchProducts(
        items: _cartItems,
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        paymentStatus: _paymentStatus,
      );

      // Create copy for PDF
      final soldItems = List<CartItem>.from(_cartItems);
      final cName = _customerNameController.text;
      final cPhone = _customerPhoneController.text;
      final payStatus = _paymentStatus;

      // Clear UI
      if (mounted) {
        setState(() {
          _cartItems.clear();
          _customerNameController.clear();
          _customerPhoneController.clear();
        });
        _showSuccessDialog(soldItems, cName, cPhone, payStatus);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(List<CartItem> items, String name, String phone, String status) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
        title: const Text("Sale Successful"),
        content: Text("${items.length} items sold.\nGenerate invoice now?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("Close"),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.print_rounded),
            label: const Text("Print Invoice"),
            onPressed: () {
              Navigator.pop(ctx);
              PdfGenerator.generateBatchInvoice(
                items: items,
                customerName: name,
                customerPhone: phone,
                paymentStatus: status,
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
    final inventoryAsync = ref.watch(inventoryStreamProvider); // Need to fetch all products for dropdown
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate Grand Total of Cart
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
              // 1. CUSTOMER INFO (Global)
              _SectionHeader(title: "Customer Info", icon: Icons.person),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _customerNameController,
                      decoration: _inputDecor("Customer Name", Icons.person_outline),
                      validator: (v) => v!.isEmpty ? 'Req' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _customerPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecor("Phone", Icons.phone),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. ADD ITEM SECTION
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Add Item to Cart", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),

                    // Product Dropdown
                    inventoryAsync.when(
                      data: (products) {
                        return DropdownButtonFormField<Product>(
                          isExpanded: true,
                          value: _selectedProduct != null && products.any((p) => p.id == _selectedProduct!.id)
                              ? products.firstWhere((p) => p.id == _selectedProduct!.id)
                              : null,
                          hint: const Text("Select Product"),
                          items: products.map((p) {
                            return DropdownMenuItem(
                              value: p,
                              child: Text(
                                "${p.model} - ${p.name} (Stock: ${p.currentStock})",
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: p.currentStock == 0 ? Colors.red : null
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
                      error: (e, s) => Text("Error loading products: $e"),
                    ),
                    const SizedBox(height: 10),

                    // Qty & Discount
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
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
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).primaryColor)
                        ),
                        ElevatedButton.icon(
                          onPressed: _addToCart,
                          icon: const Icon(Icons.add_shopping_cart, size: 18),
                          label: const Text("Add"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
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
                const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Cart is empty"))),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _cartItems.length,
                itemBuilder: (context, index) {
                  final item = _cartItems[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text("${index + 1}", style: const TextStyle(fontSize: 12)),
                      ),
                      title: Text(item.product.model, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${item.quantity} x ৳${item.product.marketPrice} (-${item.discountPercent}%)"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("৳${item.finalPrice.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
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
              DropdownButtonFormField<String>(
                value: _paymentStatus,
                items: ['Cash', 'Due'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _paymentStatus = v!),
                decoration: _inputDecor("Payment Type", Icons.payment),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Grand Total:", style: TextStyle(color: Colors.white70, fontSize: 16)),
                    Text(
                      "৳${cartTotal.toStringAsFixed(0)}",
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
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
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
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
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}