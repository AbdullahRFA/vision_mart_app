import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/inventory_repository.dart';
import 'receiving_pdf_generator.dart'; // 👈 1. Import This

class ReceiveProductScreen extends ConsumerStatefulWidget {
  const ReceiveProductScreen({super.key});

  @override
  ConsumerState<ReceiveProductScreen> createState() => _ReceiveProductScreenState();
}

class _ReceiveProductScreenState extends ConsumerState<ReceiveProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _modelController = TextEditingController();
  final _categoryController = TextEditingController();
  final _capacityController = TextEditingController();
  final _qtyController = TextEditingController();
  final _mrpController = TextEditingController();
  final _commissionController = TextEditingController();

  // Calculated Field
  double _calculatedBuyingPrice = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Listen to changes to auto-calculate
    _mrpController.addListener(_calculatePrice);
    _commissionController.addListener(_calculatePrice);
  }

  void _calculatePrice() {
    final mrp = double.tryParse(_mrpController.text) ?? 0;
    final comm = double.tryParse(_commissionController.text) ?? 0;
    setState(() {
      _calculatedBuyingPrice = mrp - (mrp * (comm / 100));
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Save to Database
      await ref.read(inventoryRepositoryProvider).receiveProduct(
        name: _nameController.text.trim(),
        model: _modelController.text.trim(),
        category: _categoryController.text.trim(),
        capacity: _capacityController.text.trim(),
        quantity: int.parse(_qtyController.text.trim()),
        mrp: double.parse(_mrpController.text.trim()),
        commission: double.parse(_commissionController.text.trim()),
      );

      // 2. Capture Data for PDF before clearing (Optional, if you want to clear)
      final pdfData = {
        'name': _nameController.text.trim(),
        'model': _modelController.text.trim(),
        'category': _categoryController.text.trim(),
        'qty': int.parse(_qtyController.text.trim()),
        'mrp': double.parse(_mrpController.text.trim()),
        'buyPrice': _calculatedBuyingPrice,
      };

      if (mounted) {
        // 3. Show Success & Ask to Print
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Text("Stock Added!"),
              ],
            ),
            content: const Text("Product received successfully.\nGenerate Inward Challan / Memo?"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close Dialog
                  Navigator.pop(context); // Go back to Dashboard
                },
                child: const Text("No, Just Save"),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.print),
                label: const Text("Print Memo"),
                onPressed: () {
                  Navigator.pop(ctx); // Close Dialog

                  // 4. Generate PDF
                  ReceivingPdfGenerator.generateReceivingMemo(
                    productName: pdfData['name'] as String,
                    model: pdfData['model'] as String,
                    category: pdfData['category'] as String,
                    quantity: pdfData['qty'] as int,
                    mrp: pdfData['mrp'] as double,
                    buyingPrice: pdfData['buyPrice'] as double,
                    receivedBy: "Admin", // You can fetch actual user email if needed
                  );

                  // Then go back
                  Navigator.pop(context);
                },
              )
            ],
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint("🔴 ERROR SAVING PRODUCT: $e");
      debugPrint("🔍 STACK TRACE: $stackTrace");

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
      appBar: AppBar(title: const Text('Receive Product (Stock In)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Product Details'),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(labelText: 'Model Number (Required)'),
                validator: (v) => v!.isEmpty ? 'Model is required' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Product Name'),
                      validator: (v) => v!.isEmpty ? 'Name is required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(labelText: 'Category (TV, AC)'),
                      validator: (v) => v!.isEmpty ? 'Category required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _capacityController,
                decoration: const InputDecoration(labelText: 'Capacity (e.g., 32", 1.5Ton)'),
              ),

              const SizedBox(height: 24),
              _buildSectionHeader('Pricing & Stock'),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mrpController,
                      decoration: const InputDecoration(labelText: 'Market Price (MRP)'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'MRP required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _commissionController,
                      decoration: const InputDecoration(labelText: 'Commission %'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Auto-calculated Display
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.green.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Buying Price (Auto):', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      _calculatedBuyingPrice.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              TextFormField(
                controller: _qtyController,
                decoration: const InputDecoration(
                  labelText: 'Quantity Received',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Quantity required' : null,
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: const Icon(Icons.save),
                  label: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('SAVE TO INVENTORY'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
    );
  }
}