import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../inventory/domain/product_model.dart';
import '../data/sales_repository.dart';
import 'pdf_generator.dart'; // 👈 IMPORT THIS

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
      setState(() {
        _finalSellingPrice = unitPrice * qty;
      });
    }
  }

  Future<void> _processSale() async {
    if (!_formKey.currentState!.validate()) return;

    final qty = int.parse(_qtyController.text);

    // Check Stock
    if (qty > widget.product.currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Not enough stock! Max is ${widget.product.currentStock}'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Perform the Sale Logic (Database Update)
      await ref.read(salesRepositoryProvider).sellProduct(
        product: widget.product,
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        quantity: qty,
        discountPercent: double.parse(_discountController.text.trim()),
        paymentStatus: _paymentStatus,
      );

      // 2. Capture values for the PDF before we clear/close anything
      final name = _customerNameController.text.trim();
      final phone = _customerPhoneController.text.trim();
      final discount = double.parse(_discountController.text.trim());
      final finalPrice = _finalSellingPrice;

      if (mounted) {
        // 3. Show Success & Ask to Print
        showDialog(
          context: context,
          barrierDismissible: false, // Force user to choose
          builder: (ctx) => AlertDialog(
            title: const Text("Sale Successful!"),
            content: const Text("Inventory updated. Do you want to print the Invoice?"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close Dialog
                  Navigator.pop(context); // Close Sell Screen
                },
                child: const Text("No, Close"),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.print),
                label: const Text("Print / Share"),
                onPressed: () {
                  Navigator.pop(ctx); // Close Dialog

                  // 4. Generate PDF
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

                  // After printing/sharing, close the Sell Screen
                  Navigator.pop(context);
                },
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sell: ${widget.product.model}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PRODUCT SUMMARY CARD
              Card(
                color: Colors.blue.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Available Stock", style: Theme.of(context).textTheme.bodySmall),
                          Text("${widget.product.currentStock}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("Market Price (MRP)", style: Theme.of(context).textTheme.bodySmall),
                          Text(widget.product.marketPrice.toStringAsFixed(0), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // CUSTOMER DETAILS
              const Text("Customer Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _customerNameController,
                decoration: const InputDecoration(
                    labelText: "Customer Name",
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder()
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _customerPhoneController,
                decoration: const InputDecoration(
                    labelText: "Phone Number (Optional)",
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder()
                ),
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 20),
              const Text("Sale Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      decoration: const InputDecoration(labelText: "Quantity"),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _discountController,
                      decoration: const InputDecoration(labelText: "Discount (%)"),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _paymentStatus,
                decoration: const InputDecoration(labelText: "Payment Status"),
                items: ['Cash', 'Due'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _paymentStatus = v!),
              ),

              const SizedBox(height: 30),

              // TOTAL CARD
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("NET TOTAL:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      _finalSellingPrice.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _processSale,
                  icon: const Icon(Icons.check_circle),
                  label: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("CONFIRM SALE", style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
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