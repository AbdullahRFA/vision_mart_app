import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/inventory_repository.dart';
import '../domain/product_model.dart';
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
  final _colorController = TextEditingController();
  final _qtyController = TextEditingController();
  final _mrpController = TextEditingController();
  final _commissionController = TextEditingController();

  // State
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  double _calculatedBuyingPrice = 0.0;
  bool _isLoading = false;

  // Batch List
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _addToList() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) return;

    final product = Product(
      id: '',
      name: _nameController.text.trim(),
      model: _modelController.text.trim(),
      category: _selectedCategory!,
      capacity: _capacityController.text.trim(),
      color: _colorController.text.trim(),
      marketPrice: double.parse(_mrpController.text.trim()),
      commissionPercent: double.parse(_commissionController.text.trim()),
      buyingPrice: _calculatedBuyingPrice,
      currentStock: int.parse(_qtyController.text.trim()),
      lastUpdated: _selectedDate,
    );

    setState(() {
      _tempBatchList.add(product);
      // Clear specific fields
      _modelController.clear();
      _nameController.clear();
      _capacityController.clear();
      _colorController.clear();
      _qtyController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${product.category} Added! (${_tempBatchList.length} items total)"), duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _submitBatch() async {
    if (_tempBatchList.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(inventoryRepositoryProvider).receiveBatchProducts(_tempBatchList);
      final itemsSaved = List<Product>.from(_tempBatchList);
      // Capture the date used for this batch before clearing
      final batchDate = _selectedDate;

      setState(() => _tempBatchList.clear());

      if (mounted) _showBatchSuccessDialog(itemsSaved, batchDate);

    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 👇 Modified to accept date
  void _showBatchSuccessDialog(List<Product> itemsSaved, DateTime batchDate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
        title: Text("Batch Received!", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Text(
          "Successfully added ${itemsSaved.length} items to inventory.\n\nGenerate Challan PDF?",
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Close", style: TextStyle(color: isDark ? Colors.redAccent : Colors.grey[700])),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.print_rounded),
            label: const Text("Print Challan"),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              // 👇 Passing the correct batchDate
              ReceivingPdfGenerator.generateBatchReceivingMemo(
                products: itemsSaved,
                receivedBy: "Admin",
                receivingDate: batchDate,
              );
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputStyle = TextStyle(color: isDark ? Colors.white : Colors.black87);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Stock (Batch)'),
        actions: [
          if (_tempBatchList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Badge(
                label: Text('${_tempBatchList.length}'),
                child: const Icon(Icons.shopping_cart_outlined),
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
                    _SectionHeader(title: "Add Item Details", icon: Icons.add_circle_outline),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedCategory,
                            style: inputStyle,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            items: _categoryOptions.map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis)
                            )).toList(),
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
                            style: inputStyle,
                            decoration: _inputDecor(label: 'Model'),
                            validator: (v) => v!.isEmpty ? 'Req' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      style: inputStyle,
                      decoration: _inputDecor(label: 'Product Name'),
                      validator: (v) => v!.isEmpty ? 'Req' : null,
                    ),
                    const SizedBox(height: 10),

                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: _inputDecor(label: 'Received Date'),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy').format(_selectedDate),
                              style: inputStyle,
                            ),
                            Icon(Icons.calendar_today, size: 18, color: Theme.of(context).primaryColor),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _capacityController,
                            textInputAction: TextInputAction.next,
                            style: inputStyle,
                            decoration: _inputDecor(label: 'Capacity/Size'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _colorController,
                            textInputAction: TextInputAction.next,
                            style: inputStyle,
                            decoration: _inputDecor(label: 'Color (Opt)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _mrpController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            style: inputStyle,
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
                            style: inputStyle,
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
                            style: inputStyle,
                            decoration: _inputDecor(label: 'Qty'),
                            validator: (v) => v!.isEmpty ? 'Req' : null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _addToList,
                        icon: const Icon(Icons.playlist_add),
                        label: const Text("ADD TO LIST", style: TextStyle(color: Colors.white)), // Explicitly white for button
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : Theme.of(context).primaryColor,
                          side: BorderSide(color: isDark ? Colors.white : Theme.of(context).primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(thickness: 2),
                    _SectionHeader(title: "Items to Save (${_tempBatchList.length})", icon: Icons.list_alt),

                    if (_tempBatchList.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Center(
                            child: Text(
                              "List is empty. Add items above.",
                              style: TextStyle(color: isDark ? Colors.white : Colors.grey[600]),
                            )
                        ),
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
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 12,
                                backgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
                                child: Text(
                                  "${index + 1}",
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                                ),
                              ),
                              title: Text(
                                  "${item.category} - ${item.model}",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)
                              ),
                              subtitle: RichText(
                                text: TextSpan(
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey[700]),
                                  children: [
                                    TextSpan(
                                      text: "${DateFormat('dd/MM').format(item.lastUpdated!)} | Color: ${item.color.isEmpty ? 'N/A' : item.color}\n",
                                      style: TextStyle(color: isDark ? Colors.yellowAccent : Colors.grey[700]),
                                    ),
                                    TextSpan(
                                      text: "Buy: ৳${item.buyingPrice.toStringAsFixed(0)}",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.greenAccent : Colors.black87
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                onPressed: () => setState(() => _tempBatchList.removeAt(index)),
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              boxShadow: [
                BoxShadow(
                    color: isDark ? Colors.black26 : Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, -5)
                )
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: (_isLoading || _tempBatchList.isEmpty) ? null : _submitBatch,
                icon: const Icon(Icons.save_rounded),
                label: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SAVE ALL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Green Button
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
    final primaryColor = Theme.of(context).primaryColor;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.yellowAccent : Colors.grey[600],
        fontSize: 14,
      ),
      floatingLabelStyle: TextStyle(
        color: primaryColor,
        fontWeight: FontWeight.bold,
      ),
      hintText: label,
      hintStyle: TextStyle(
        color: isDark ? Colors.white60 : Colors.black12,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? Colors.yellowAccent : Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(
            color: isDark ? Colors.yellowAccent : Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold
        )),
      ],
    );
  }
}