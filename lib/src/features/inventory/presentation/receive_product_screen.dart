import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/inventory_repository.dart';
import '../domain/product_model.dart';
import 'receiving_pdf_generator.dart';

class ReceiveProductScreen extends ConsumerStatefulWidget {
  const ReceiveProductScreen({super.key});

  @override
  ConsumerState<ReceiveProductScreen> createState() =>
      _ReceiveProductScreenState();
}

enum DiscountType { percentage, flat }

class _ReceiveProductScreenState extends ConsumerState<ReceiveProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _modelController = TextEditingController();
  final _capacityController = TextEditingController();
  final _colorController = TextEditingController();
  final _qtyController = TextEditingController();
  final _mrpController = TextEditingController();
  final _commissionController =
      TextEditingController(); // Acts as Disc % OR Flat Amt
  final _buyingPriceController = TextEditingController(); // 👈 New Manual Field

  // Focus Nodes (To prevent circular calc loops)
  final _mrpFocus = FocusNode();
  final _commFocus = FocusNode();
  final _buyPriceFocus = FocusNode();

  // State
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  DiscountType _discountType = DiscountType.percentage; // Default: %

  // Batch List
  final List<Product> _tempBatchList = [];

  final List<String> _categoryOptions = [
    'Television',
    'Refrigerator & Freezer',
    'Air Conditioner',
    'Washing Machine',
    'Fan & Air Cooling',
    'Kitchen Appliance',
    'Small Home Appliance',
    'Audio & Multimedia',
    'Security & Smart Device',
    'Accessories & Digital',
  ];

  // 1. EXPANDED REAL-WORLD DATA
  final Map<String, Map<String, double>> _predefinedData = {
    'Refrigerator & Freezer': {
      // VCM Refrigerator
      '50L': 16000,

      '101L V.Box': 20100,

      '121L': 19300,

      '142L TM': 28400,

      '160L BM': 28400,

      '222L BM': 35900,

      '238L BM': 38200,

      '240L TM': 38200,

      '252L BM': 39100,

      '262L TM': 40200,

      // GD Refrigerator
      '135L With Canopy': 36400,

      '135L Without Canopy': 33900,

      '142G TM': 30700,

      '150G TM': 32100,

      '160G BM': 32100,

      '180G TM': 38000,

      '185G BM': 38800,

      '191G TM': 31300,

      '196G BM': 39100,

      '200G TM': 40100,

      '216G BM': 40900,

      '217G TM': 40900,

      '221G BM': 32800,

      '222G TM': 41100,

      '238G BM': 42900,

      '240G TM': 42900,

      '242G TM': 43200,

      '252G BM': 44400,

      '262G TM': 44700,

      '275L Bevg': 62300,

      '280G TM': 47700,

      '238G Smart BM': 44000,

      '252G Smart BM': 45400,

      '305G TM': 51300,

      '330G BM': 54600,

      '330G BM Water Dis.': 56600,

      '356G TM': 55600,

      '285L NF': 61300,

      '309L NF': 63400,

      '566G SBS NF': 88400,

      // Chest Freezer
      '112L GD': 28700,

      '150L GD': 32100,

      '250L GD': 42600,

      '350L GD': 48900,

      '158L Ice': 42600,

      '368L Ice': 62900,

      '568L Ice': 90500,

      '150L GD SMT': 33900,

      '250L GD SMT': 43700,
    },
    'Television': {
      '32" LED P20 Prime': 18500,
      '32" LED Smart Coolita': 22500,
      '32" Google TV Z30': 25300,
      '43" Google TV Q10S': 39900,
      '43" 4K Google TV RQ1': 51900,
      '50" 4K Google TV RQ1': 62900,
      '55" 4K Google TV RQ1': 72900,
      '65" QLED 4K PQ1': 96900,
      '75" QLED 4K PQ1': 145000,
    },
    'Air Conditioner': {
      '1.0 Ton (Non-Inv) AXC': 31500,
      '1.5 Ton (Non-Inv) BXC': 41500,
      '2.0 Ton (Non-Inv) CXC': 71000,
      '1.0 Ton Inverter 3D': 46500,
      '1.5 Ton Inverter 3D': 60970,
      '2.0 Ton Inverter 3D': 82500,
      '1.5 Ton Cassette Type': 95000,
    },
    'Washing Machine': {
      '6KG Front Loading FLT60B': 41900,
      '7KG Front Loading': 45500,
      '8KG Top Loading ATC80': 33000,
      '9KG Top Loading': 36500,
      '6KG Twin Tub': 14500,
    },
    'Kitchen Appliance': {
      'Microwave Oven 20L': 10800,
      'Microwave Oven 25L': 14600,
      'Microwave Oven 30L Convection': 18700,
      'Rice Cooker 1.8L SS': 2990,
      'Rice Cooker 2.8L SS': 3190,
      'Rice Cooker 3.0L SS': 3670,
      'Blender 850W Tufan': 5950,
      'Blender 3-in-1 Deluxe': 2400,
      'Induction Cooker Eco 1206': 3750,
      'Induction Cooker Touch': 3350,
      'Electric Kettle 1.5L': 890,
      'Electric Kettle 1.8L': 960,
    },
    'Fan & Air Cooling': {
      'Ceiling Fan 56" Ivory': 3190,
      'Ceiling Fan 48"': 3175,
      'Ceiling Fan 36"': 2975,
      'Ceiling Net Fan 20"': 1900,
      'High Speed Table Fan 12"': 1760,
      'Stand Fan 18"': 3399,
      'Rechargeable Table Fan 14"': 4899,
    },
    'Small Home Appliance': {
      'Iron Steam': 1800,
      'Iron Dry Heavy': 1200,
      'Room Heater Fan': 2500,
      'Geyser 30L': 7500,
    },
  };

  @override
  void initState() {
    super.initState();
    // Attach Listeners for 3-way calculation
    _mrpController.addListener(_onMrpChanged);
    _commissionController.addListener(_onCommissionChanged);
    _buyingPriceController.addListener(_onBuyingPriceChanged);
  }

  // --- 3-WAY CALCULATION LOGIC ---

  void _onMrpChanged() {
    if (!_mrpFocus.hasFocus) return; // Only calc if user is typing MRP
    _recalculateBuyingPrice();
  }

  void _onCommissionChanged() {
    if (!_commFocus.hasFocus) return; // Only calc if user is typing Comm
    _recalculateBuyingPrice();
  }

  void _onBuyingPriceChanged() {
    if (!_buyPriceFocus.hasFocus)
      return; // Only calc if user is typing Buy Price
    // Reverse Calculate Commission
    double mrp = double.tryParse(_mrpController.text) ?? 0;
    double buyPrice = double.tryParse(_buyingPriceController.text) ?? 0;
    if (mrp <= 0) return;

    double discountAmount = mrp - buyPrice;

    if (_discountType == DiscountType.percentage) {
      double percent = (discountAmount / mrp) * 100;
      _commissionController.text = percent.toStringAsFixed(2);
    } else {
      _commissionController.text = discountAmount.toStringAsFixed(0);
    }
  }

  void _recalculateBuyingPrice() {
    double mrp = double.tryParse(_mrpController.text) ?? 0;
    double commInput = double.tryParse(_commissionController.text) ?? 0;
    double finalBuyPrice = 0;

    if (_discountType == DiscountType.percentage) {
      // Logic: MRP - (MRP * %)
      finalBuyPrice = mrp - (mrp * (commInput / 100));
    } else {
      // Logic: MRP - Flat Amount
      finalBuyPrice = mrp - commInput;
    }

    _buyingPriceController.text = finalBuyPrice.toStringAsFixed(0);
  }

  // --- END CALCULATION LOGIC ---

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _addToList() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) return;

    // Final Calculation check before adding
    double mrp = double.parse(_mrpController.text.trim());
    double buyPrice = double.parse(_buyingPriceController.text.trim());

    // Always store as Percentage internally for consistency, or calculated from fields
    // But your Model expects a percentage. Let's calculate the effective % if in Flat mode.
    double effectiveCommPercent = 0;
    if (mrp > 0) {
      effectiveCommPercent = ((mrp - buyPrice) / mrp) * 100;
    }

    final product = Product(
      id: '',
      name: _nameController.text.trim(),
      model: _modelController.text.trim(),
      category: _selectedCategory!,
      capacity: _capacityController.text.trim(),
      color: _colorController.text.trim(),
      marketPrice: mrp,
      commissionPercent: effectiveCommPercent, // Store normalized %
      buyingPrice: buyPrice,
      currentStock: int.parse(_qtyController.text.trim()),
      lastUpdated: _selectedDate,
    );

    setState(() {
      _tempBatchList.add(product);
      // Clear fields
      _modelController.clear();
      _nameController.clear();
      _capacityController.clear();
      _colorController.clear();
      _qtyController.clear();
      // Reset Calc fields optionally
      // _mrpController.clear();
      // _buyingPriceController.clear();
      // _commissionController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${product.category} Added!"),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  Future<void> _submitBatch() async {
    if (_tempBatchList.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      await ref
          .read(inventoryRepositoryProvider)
          .receiveBatchProducts(_tempBatchList);
      final itemsSaved = List<Product>.from(_tempBatchList);
      final batchDate = _selectedDate;
      setState(() => _tempBatchList.clear());
      if (mounted) _showBatchSuccessDialog(itemsSaved, batchDate);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showBatchSuccessDialog(List<Product> itemsSaved, DateTime batchDate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        icon: const Icon(
          Icons.check_circle_rounded,
          color: Colors.green,
          size: 48,
        ),
        title: Text(
          "Batch Received!",
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          "Successfully added ${itemsSaved.length} items.\nPrint Challan?",
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.print_rounded),
            label: const Text("Print"),
            onPressed: () {
              Navigator.pop(ctx);
              ReceivingPdfGenerator.generateBatchReceivingMemo(
                products: itemsSaved,
                receivedBy: "Admin",
                receivingDate: batchDate,
              );
            },
          ),
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
        title: const Text('Receive Stock'),
        actions: [
          if (_tempBatchList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Badge(
                label: Text('${_tempBatchList.length}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
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
                    _SectionHeader(
                      title: "Item Details",
                      icon: Icons.add_circle_outline,
                    ),
                    const SizedBox(height: 16),

                    // 1. CATEGORY & MODEL (Autocomplete)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedCategory,
                            style: inputStyle,
                            dropdownColor: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            items: _categoryOptions
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCategory = v),
                            decoration: _inputDecor(label: 'Category'),
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: RawAutocomplete<String>(
                            textEditingController: _modelController,
                            focusNode: FocusNode(),
                            optionsBuilder: (TextEditingValue val) {
                              if (_selectedCategory == null) return const [];
                              final models =
                                  _predefinedData[_selectedCategory]?.keys
                                      .toList() ??
                                  [];
                              if (val.text.isEmpty) return models;
                              return models.where(
                                (o) => o.toLowerCase().contains(
                                  val.text.toLowerCase(),
                                ),
                              );
                            },
                            onSelected: (String selection) {
                              final price =
                                  _predefinedData[_selectedCategory]?[selection];
                              if (price != null) {
                                _mrpController.text = price.toStringAsFixed(0);
                                // Trigger calculation if comm/buy price is already filled
                                _onMrpChanged();
                              }
                            },
                            fieldViewBuilder: (ctx, ctrl, focus, onComplete) {
                              return TextFormField(
                                controller: ctrl,
                                focusNode: focus,
                                onEditingComplete: onComplete,
                                style: inputStyle,
                                decoration: _inputDecor(label: 'Model'),
                                validator: (v) => v!.isEmpty ? 'Req' : null,
                              );
                            },
                            optionsViewBuilder: (ctx, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 200,
                                    constraints: const BoxConstraints(
                                      maxHeight: 250,
                                    ),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (ctx, idx) {
                                        final opt = options.elementAt(idx);
                                        return ListTile(
                                          title: Text(
                                            opt,
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                          onTap: () => onSelected(opt),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 2. NAME & DATE
                    TextFormField(
                      controller: _nameController,
                      style: inputStyle,
                      decoration: _inputDecor(label: 'Product Name'),
                      validator: (v) => v!.isEmpty ? 'Req' : null,
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: _inputDecor(label: 'Received Date'),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy').format(_selectedDate),
                              style: inputStyle,
                            ),
                            Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: Theme.of(context).primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 3. CAP & COLOR & QTY
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _capacityController,
                            style: inputStyle,
                            decoration: _inputDecor(label: 'Size/Cap'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _colorController,
                            style: inputStyle,
                            decoration: _inputDecor(label: 'Color'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            style: inputStyle,
                            decoration: _inputDecor(label: 'Qty'),
                            validator: (v) => v!.isEmpty ? 'Req' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4. PRICING SECTION HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SectionHeader(
                          title: "Pricing & Commission",
                          icon: Icons.price_change_outlined,
                        ),
                        // TOGGLE SWITCH
                        ToggleButtons(
                          borderRadius: BorderRadius.circular(8),
                          constraints: const BoxConstraints(
                            minHeight: 30,
                            minWidth: 60,
                          ),
                          isSelected: [
                            _discountType == DiscountType.percentage,
                            _discountType == DiscountType.flat,
                          ],
                          onPressed: (index) {
                            setState(() {
                              _discountType = index == 0
                                  ? DiscountType.percentage
                                  : DiscountType.flat;
                              // Recalculate based on new type
                              _onCommissionChanged();
                            });
                          },
                          children: const [
                            Text(
                              "%",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Flat",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 5. ADVANCED PRICING FIELDS
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black26
                            : Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white10
                              : Colors.blue.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          // MRP
                          Expanded(
                            child: TextFormField(
                              controller: _mrpController,
                              focusNode: _mrpFocus,
                              keyboardType: TextInputType.number,
                              style: inputStyle,
                              decoration: _inputDecor(label: 'MRP'),
                              validator: (v) => v!.isEmpty ? 'Req' : null,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // COMMISSION / DISCOUNT
                          Expanded(
                            child: TextFormField(
                              controller: _commissionController,
                              focusNode: _commFocus,
                              keyboardType: TextInputType.number,
                              style: inputStyle,
                              decoration: _inputDecor(
                                label: _discountType == DiscountType.percentage
                                    ? 'Comm %'
                                    : 'Disc Tk',
                              ),
                              validator: (v) => v!.isEmpty ? 'Req' : null,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // BUYING PRICE (MANUAL OVERRIDE)
                          Expanded(
                            child: TextFormField(
                              controller: _buyingPriceController,
                              focusNode: _buyPriceFocus,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                              decoration: _inputDecor(label: 'Buy Price'),
                              validator: (v) => v!.isEmpty ? 'Req' : null,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _addToList,
                        icon: const Icon(Icons.playlist_add),
                        label: const Text(
                          "ADD TO LIST",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    _SectionHeader(
                      title: "Batch List (${_tempBatchList.length})",
                      icon: Icons.list_alt,
                    ),
                    if (_tempBatchList.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _tempBatchList.length,
                        itemBuilder: (ctx, idx) {
                          final item = _tempBatchList[idx];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            child: ListTile(
                              dense: true,
                              title: Text(
                                "${item.model} (${item.name})",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              subtitle: Text(
                                "Buy: ${item.buyingPrice.toStringAsFixed(0)} | Stock: ${item.currentStock}",
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => setState(
                                  () => _tempBatchList.removeAt(idx),
                                ),
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

          // BOTTOM BUTTON
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_isLoading || _tempBatchList.isEmpty)
                    ? null
                    : _submitBatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SAVE BATCH"),
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
      labelStyle: TextStyle(
        color: isDark ? Colors.yellowAccent : Colors.grey[700],
        fontSize: 13,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
        Icon(icon, size: 18, color: isDark ? Colors.yellowAccent : Colors.blue),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}
