import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/inventory_repository.dart';
import '../domain/product_model.dart';
import '../../sales/presentation/sell_product_screen.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedCategory = "All";

  // Vision Electronics Categories
  final List<String> _categories = [
    "All",
    "Low Stock",
    "Television",
    "Refrigerator & Freezer",
    "Air Conditioner",
    "Washing Machine",
    "Fan & Air Cooling",
    "Kitchen Appliance",
    "Small Home Appliance",
    "Audio & Multimedia",
    "Security & Smart Device",
    "Accessories & Digital",
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  // 👇 Edit Logic
  void _showEditDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => _EditProductDialog(product: product),
    );
  }

  // 👇 Delete Logic
  void _confirmDelete(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Product?"),
        content: Text("Are you sure you want to delete ${product.model}?\nThis action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(inventoryRepositoryProvider).deleteProduct(product.id, product.model);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product Deleted")));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsyncValue = ref.watch(inventoryStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: Column(
        children: [
          // 1. SEARCH BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Model or Name...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // 2. FILTER CHIPS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                final isLowStock = category == "Low Stock";

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    showCheckmark: false,
                    side: BorderSide.none,
                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    selectedColor: isLowStock
                        ? Colors.red.withOpacity(0.2)
                        : Theme.of(context).primaryColor.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? (isLowStock ? Colors.red : Theme.of(context).primaryColor)
                          : (isDark ? Colors.white60 : Colors.grey[700]),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (bool selected) {
                      if (selected) setState(() => _selectedCategory = category);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // 3. PRODUCT LIST
          Expanded(
            child: inventoryAsyncValue.when(
              data: (products) {
                final filteredProducts = products.where((p) {
                  final matchesSearch = p.name.toLowerCase().contains(_searchQuery) ||
                      p.model.toLowerCase().contains(_searchQuery);
                  if (!matchesSearch) return false;

                  if (_selectedCategory == "All") return true;
                  if (_selectedCategory == "Low Stock") return p.currentStock < 5;

                  return p.category.toLowerCase().contains(_selectedCategory.toLowerCase()) ||
                      _selectedCategory.toLowerCase().contains(p.category.toLowerCase());
                }).toList();

                if (filteredProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text("No products found", style: TextStyle(color: Colors.grey.withOpacity(0.8), fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) => _ProductCard(
                    product: filteredProducts[index],
                    onEdit: () => _showEditDialog(filteredProducts[index]),
                    onDelete: () => _confirmDelete(filteredProducts[index]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, stack) => Center(child: Text("Error: $e")),
            ),
          ),
        ],
      ),
    );
  }
}

// 👇 Updated Product Card with Actions
class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ProductCard({required this.product, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.currentStock < 5;
    final stockColor = isLowStock ? Colors.red : Colors.green;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    IconData getIconForCategory(String cat) {
      final c = cat.toLowerCase();
      if (c.contains('tv')) return Icons.tv_rounded;
      if (c.contains('fridge') || c.contains('refrigerator')) return Icons.kitchen_rounded;
      if (c.contains('ac') || c.contains('air conditioner')) return Icons.ac_unit_rounded;
      if (c.contains('wash')) return Icons.local_laundry_service_rounded;
      if (c.contains('fan')) return Icons.air_rounded;
      if (c.contains('kitchen')) return Icons.rice_bowl_rounded;
      if (c.contains('audio')) return Icons.speaker_group_rounded;
      if (c.contains('security')) return Icons.videocam_rounded;
      return Icons.devices_other_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SellProductScreen(product: product)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(getIconForCategory(product.category), color: Theme.of(context).primaryColor),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.model, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text("${product.name}", style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text("৳${product.marketPrice.toStringAsFixed(0)}", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),

                // Stock & Actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Stock Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: stockColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text("${product.currentStock} Units", style: TextStyle(color: stockColor, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                    const SizedBox(height: 8),

                    // Edit/Delete Menu
                    Row(
                      children: [
                        InkWell(
                          onTap: onEdit,
                          child: Icon(Icons.edit, size: 20, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: onDelete,
                          child: Icon(Icons.delete, size: 20, color: Colors.red[300]),
                        ),
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 👇 Internal Edit Dialog Widget
class _EditProductDialog extends ConsumerStatefulWidget {
  final Product product;
  const _EditProductDialog({required this.product});

  @override
  ConsumerState<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends ConsumerState<_EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _mrpCtrl;
  late TextEditingController _commCtrl;
  late TextEditingController _capacityCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product.name);
    _mrpCtrl = TextEditingController(text: widget.product.marketPrice.toString());
    _commCtrl = TextEditingController(text: widget.product.commissionPercent.toString());
    _capacityCtrl = TextEditingController(text: widget.product.capacity);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Edit ${widget.product.model}"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Product Name"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _capacityCtrl,
                decoration: const InputDecoration(labelText: "Capacity/Size"),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mrpCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "MRP"),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _commCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Comm %"),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;

            final mrp = double.parse(_mrpCtrl.text);
            final comm = double.parse(_commCtrl.text);
            final buyingPrice = mrp - (mrp * (comm / 100));

            // Create updated object
            final updatedProduct = Product(
              id: widget.product.id,
              model: widget.product.model, // Model usually doesn't change
              category: widget.product.category,
              currentStock: widget.product.currentStock,
              name: _nameCtrl.text.trim(),
              capacity: _capacityCtrl.text.trim(),
              marketPrice: mrp,
              commissionPercent: comm,
              buyingPrice: buyingPrice,
            );

            try {
              await ref.read(inventoryRepositoryProvider).updateProduct(updatedProduct);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product Updated")));
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
            }
          },
          child: const Text("Save Changes"),
        )
      ],
    );
  }
}