import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../inventory/domain/product_model.dart';
import '../data/sales_repository.dart';
import 'pdf_generator.dart';

class SellProductScreen extends ConsumerStatefulWidget {
  final Product product;
  const SellProductScreen({super.key, required this.product});

  @override
  ConsumerState<SellProductScreen> createState() => _SellProductScreenState();
}

class _SellProductScreenState extends ConsumerState<SellProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _discountController = TextEditingController(text: '0');

  String _paymentStatus = 'Cash';
  double _finalSellingPrice = 0.0;
  bool _isLoading = false;
  bool _isWholesale = false;
  static const double _wholesaleDiscountPercent = 8.0;

  @override
  void initState() {
    super.initState();
    _calculateTotal();
    _qtyController.addListener(_calculateTotal);
    _discountController.addListener(_calculateTotal);
  }

  void _calculateTotal() {
    final qty = int.tryParse(_qtyController.text) ?? 0;
    final discount = double.tryParse(_discountController.text) ?? 0;
    if (qty > 0) {
      final unitPrice = widget.product.marketPrice - (widget.product.marketPrice * (discount / 100));
      setState(() => _finalSellingPrice = unitPrice * qty);
    }
  }

  void _toggleSaleType(bool isWholesale) {
    setState(() {
      _isWholesale = isWholesale;
      _discountController.text = _isWholesale ? _wholesaleDiscountPercent.toStringAsFixed(0) : '0';
    });
    _calculateTotal();
  }

  Future<void> _processSale() async {
    if (!_formKey.currentState!.validate()) return;
    final qty = int.parse(_qtyController.text);
    if (qty > widget.product.currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not enough stock! Max: ${widget.product.currentStock}'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(salesRepositoryProvider).sellProduct(
        product: widget.product,
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        quantity: qty,
        discountPercent: double.parse(_discountController.text.trim()),
        paymentStatus: _paymentStatus,
      );

      if (mounted) _showSuccessDialog(qty);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(int qty) {
    final name = _customerNameController.text.trim();
    final phone = _customerPhoneController.text.trim();
    final discount = double.parse(_discountController.text.trim());
    final finalPrice = _finalSellingPrice;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
        title: const Text("Sale Successful"),
        content: const Text("Stock has been updated.\nGenerate invoice now?"),
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
              PdfGenerator.generateInvoice(
                customerName: name,
                customerPhone: phone,
                productName: widget.product.name,
                productModel: widget.product.model,
                quantity: qty,
                mrp: widget.product.marketPrice,
                discountPercent: discount,
                finalPrice: finalPrice,
                paymentStatus: _paymentStatus,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(widget.product.model)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SALE MODE SELECTOR
              Row(
                children: [
                  Expanded(
                    child: _ModeCard(
                      label: "Retail",
                      isSelected: !_isWholesale,
                      onTap: () => _toggleSaleType(false),
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModeCard(
                      label: "Wholesale",
                      isSelected: _isWholesale,
                      onTap: () => _toggleSaleType(true),
                      icon: Icons.store_mall_directory_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. PRODUCT INFO & STOCK
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Available Stock", style: TextStyle(fontSize: 12)),
                        Text(
                          "${widget.product.currentStock} Units",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("Market Price", style: TextStyle(fontSize: 12)),
                        Text(
                          "৳${widget.product.marketPrice.toStringAsFixed(0)}",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. INPUT FIELDS
              const Text("Customer Info", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customerNameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: "Customer Name",
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _customerPhoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 24),
              const Text("Transaction Details", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Quantity",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _discountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Discount (%)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _paymentStatus,
                items: ['Cash', 'Due'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _paymentStatus = v!),
                decoration: InputDecoration(
                  labelText: "Payment Type",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.payment),
                ),
              ),

              const SizedBox(height: 32),

              // 4. TOTAL & ACTION
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Net Total:", style: TextStyle(color: Colors.white70, fontSize: 16)),
                    Text(
                      "৳${_finalSellingPrice.toStringAsFixed(0)}",
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _processSale,
                  icon: const Icon(Icons.check_circle_outline),
                  label: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("CONFIRM SALE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;

  const _ModeCard({required this.label, required this.isSelected, required this.onTap, required this.icon});

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Theme.of(context).primaryColor : Colors.grey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
                label,
                style: TextStyle(fontWeight: FontWeight.bold, color: color)
            ),
          ],
        ),
      ),
    );
  }
}