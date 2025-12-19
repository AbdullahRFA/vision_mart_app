import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/inventory_repository.dart';
import '../domain/product_model.dart'; // Ensure this import exists
import 'receiving_pdf_generator.dart';

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
  final _capacityController = TextEditingController();
  final _qtyController = TextEditingController();
  final _mrpController = TextEditingController();
  final _commissionController = TextEditingController();

  String? _selectedCategory;
  double _calculatedBuyingPrice = 0.0;
  bool _isLoading = false;

  // 👇 NEW: List to hold mixed products before saving
  final List<Product> _tempBatchList = [];

  final List<String> _categoryOptions = [
    'Television', 'Refrigerator & Freezer', 'Air Conditioner',
    'Washing Machine', 'Fan & Air Cooling', 'Kitchen Appliance',
    'Small Home Appliance', 'Audio & Multimedia',
    'Security & Smart Device', 'Accessories & Digital'
  ];

  @override
  void initState() {
    super.initState();
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

  // 👇 CHANGED: Logic to ADD to local list instead of DB
  void _addToList() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) return;

    final product = Product(
      id: '', // Temp ID
      name: _nameController.text.trim(),
      model: _modelController.text.trim(),
      category: _selectedCategory!,
      capacity: _capacityController.text.trim(),
      marketPrice: double.parse(_mrpController.text.trim()),
      commissionPercent: double.parse(_commissionController.text.trim()),
      buyingPrice: _calculatedBuyingPrice,
      currentStock: int.parse(_qtyController.text.trim()),
    );

    setState(() {
      _tempBatchList.add(product);
      // Clear specific fields for next entry, keep others if needed
      _modelController.clear();
      _nameController.clear();
      _capacityController.clear();
      _qtyController.clear();
      // We might keep MRP/Commission if entering similar items, but let's clear for safety
      _mrpController.clear();
      _commissionController.clear();
      _calculatedBuyingPrice = 0.0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${product.category} Added to List! Add more or Save All."), duration: const Duration(seconds: 1)),
    );
  }

  // 👇 NEW: Logic to Save the whole Batch
  Future<void> _submitBatch() async {
    if (_tempBatchList.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(inventoryRepositoryProvider).receiveBatchProducts(_tempBatchList);

      if (mounted) _showBatchSuccessDialog();
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showBatchSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
        title: const Text("Batch Received!"),
        content: Text("Successfully added ${_tempBatchList.length} items to inventory."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("Close"),
          ),
          // You can add a loop here to generate a master PDF if needed
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Stock (Batch)'),
        actions: [
          // Show item count badge
          if (_tempBatchList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Badge(
                  label: Text('${_tempBatchList.length}'),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
              ),
            )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- INPUT FORM ---
                    _SectionHeader(title: "Add Item Details", icon: Icons.add_circle_outline),
                    const SizedBox(height: 16),

                    // Row 1: Category & Model
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedCategory,
                            items: _categoryOptions.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setState(() => _selectedCategory = v),
                            decoration: _inputDecor(label: 'Category'),
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _modelController,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecor(label: 'Model'),
                            validator: (v) => v!.isEmpty ? 'Req' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Row 2: Name & Capacity
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecor(label: 'Product Name'),
                            validator: (v) => v!.isEmpty ? 'Req' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _capacityController,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecor(label: 'Capacity/Size'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Row 3: Pricing
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _mrpController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecor(label: 'MRP'),
                            validator: (v) => v!.isEmpty ? 'Req' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _commissionController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecor(label: 'Comm %'),
                            validator: (v) => v!.isEmpty ? 'Req' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            decoration: _inputDecor(label: 'Qty'),
                            validator: (v) => v!.isEmpty ? 'Req' : null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ADD BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _addToList,
                        icon: const Icon(Icons.playlist_add),
                        label: const Text("ADD TO LIST"),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Theme.of(context).primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(thickness: 2),
                    _SectionHeader(title: "Items to Save (${_tempBatchList.length})", icon: Icons.list_alt),

                    // --- BATCH LIST PREVIEW ---
                    if (_tempBatchList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: Text("List is empty. Add items above.")),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _tempBatchList.length,
                        itemBuilder: (context, index) {
                          final item = _tempBatchList[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                  child: Text("${index + 1}"),
                                  radius: 12,
                                  backgroundColor: Colors.grey.shade300
                              ),
                              title: Text("${item.category} - ${item.model}", style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("Qty: ${item.currentStock} | Buy: ${item.buyingPrice.toStringAsFixed(0)}"),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => setState(() => _tempBatchList.removeAt(index)),
                              ),
                            ),
                          );
                        },
                      ),

                    // Add extra space at bottom for the FAB/Button
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),

          // --- BOTTOM ACTION BAR ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: (_isLoading || _tempBatchList.isEmpty) ? null : _submitBatch,
                icon: const Icon(Icons.save_rounded),
                label: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("SAVE ALL (${_tempBatchList.length} ITEMS)"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecor({required String label}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey[50],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
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
        Icon(icon, size: 18, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
      ],
    );
  }
}