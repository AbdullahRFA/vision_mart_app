import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/inventory_repository.dart';
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

  // State Variables
  String? _selectedCategory;
  double _calculatedBuyingPrice = 0.0;
  bool _isLoading = false;

  // 👇 UPDATED: Categories based on Vision Electronics Product List
  final List<String> _categoryOptions = [
    'Television',            // Smart TV, Google TV, LED
    'Refrigerator & Freezer', // Glass Door, VCM, Chest Freezer
    'Air Conditioner',       // Inverter, General, VRF
    'Washing Machine',       // Automatic, Manual
    'Fan & Air Cooling',     // Ceiling, Pedestal, Exhaust, Air Cooler
    'Kitchen Appliance',     // Rice Cooker, Blender, Oven, Gas Stove
    'Small Home Appliance',  // Iron, Kettle, Geyser, Room Heater
    'Audio & Multimedia',    // Speakers, Home Theater
    'Security & Smart Device', // CCTV, DVR
    'Accessories & Digital'  // Clocks, Calculators, Remotes
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Save to Database
      await ref.read(inventoryRepositoryProvider).receiveProduct(
        name: _nameController.text.trim(),
        model: _modelController.text.trim(),
        category: _selectedCategory!,
        capacity: _capacityController.text.trim(),
        quantity: int.parse(_qtyController.text.trim()),
        mrp: double.parse(_mrpController.text.trim()),
        commission: double.parse(_commissionController.text.trim()),
      );

      // 2. Capture Data for PDF
      final pdfData = {
        'name': _nameController.text.trim(),
        'model': _modelController.text.trim(),
        'category': _selectedCategory!,
        'qty': int.parse(_qtyController.text.trim()),
        'mrp': double.parse(_mrpController.text.trim()),
        'buyPrice': _calculatedBuyingPrice,
      };

      if (mounted) _showSuccessDialog(pdfData);
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

  void _showSuccessDialog(Map<String, dynamic> pdfData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
        title: const Text("Stock Added!"),
        content: const Text("Product received successfully.\nGenerate Inward Challan / Memo?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("No, Close"),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.print_rounded),
            label: const Text("Print Memo"),
            onPressed: () {
              Navigator.pop(ctx);
              ReceivingPdfGenerator.generateReceivingMemo(
                productName: pdfData['name'] as String,
                model: pdfData['model'] as String,
                category: pdfData['category'] as String,
                quantity: pdfData['qty'] as int,
                mrp: pdfData['mrp'] as double,
                buyingPrice: pdfData['buyPrice'] as double,
                receivedBy: "Admin",
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
      appBar: AppBar(title: const Text('Receive Stock')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SECTION 1: PRODUCT DETAILS
              _SectionHeader(title: "Product Details", icon: Icons.inventory_2_outlined),
              const SizedBox(height: 16),

              TextFormField(
                controller: _modelController,
                textInputAction: TextInputAction.next,
                decoration: _inputDecor(label: 'Model Number', hint: 'e.g. VIS-32-LED-SMART', icon: Icons.qr_code),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecor(label: 'Product Name', icon: Icons.label_outline),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    // Dropdown for Category
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedCategory,
                      items: _categoryOptions.map((String category) {
                        return DropdownMenuItem(value: category, child: Text(category, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (newValue) => setState(() => _selectedCategory = newValue),
                      decoration: _inputDecor(label: 'Category'),
                      validator: (v) => v == null ? 'Required' : null,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                textInputAction: TextInputAction.next,
                decoration: _inputDecor(label: 'Capacity / Specs', hint: 'e.g., 32 Inch, 1.5 Ton', icon: Icons.aspect_ratio),
              ),

              const SizedBox(height: 32),

              // SECTION 2: COSTING
              _SectionHeader(title: "Pricing & Stock", icon: Icons.attach_money),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mrpController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecor(label: 'MRP (Market Price)', icon: Icons.price_change_outlined),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _commissionController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecor(label: 'Commission %', icon: Icons.percent),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Buying Price Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Buying Price (Calculated)", style: TextStyle(color: isDark ? Colors.white70 : Colors.green.shade900, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          "৳${_calculatedBuyingPrice.toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                    const Icon(Icons.calculate_outlined, color: Colors.green, size: 32),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              TextFormField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: _inputDecor(label: 'Quantity Received', icon: Icons.add_shopping_cart),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: const Icon(Icons.save_rounded),
                  label: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('SAVE TO INVENTORY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  InputDecoration _inputDecor({required String label, String? hint, IconData? icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey[50],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.transparent : Colors.grey.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        Text(
            title,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            )
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: Theme.of(context).primaryColor.withOpacity(0.2))),
      ],
    );
  }
}