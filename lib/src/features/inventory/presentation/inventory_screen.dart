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

  // 👇 UPDATED: Filter Categories to match Vision Electronics list
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
                  // Search Filter
                  final matchesSearch = p.name.toLowerCase().contains(_searchQuery) ||
                      p.model.toLowerCase().contains(_searchQuery);
                  if (!matchesSearch) return false;

                  // Category Filter
                  if (_selectedCategory == "All") return true;
                  if (_selectedCategory == "Low Stock") return p.currentStock < 5;

                  // Exact match preferred for categories, but we use contains for safety
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
                        Text(
                          "No products found",
                          style: TextStyle(color: Colors.grey.withOpacity(0.8), fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) => _ProductCard(product: filteredProducts[index]),
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

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.currentStock < 5;
    final stockColor = isLowStock ? Colors.red : Colors.green;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Helper to pick icon based on category
    IconData getIconForCategory(String cat) {
      final c = cat.toLowerCase();
      if (c.contains('tv') || c.contains('television')) return Icons.tv_rounded;
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
                // Icon / Avatar
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

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.model,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${product.name} • ${product.category}",
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "৳${product.marketPrice.toStringAsFixed(0)}",
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Stock Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: stockColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: stockColor.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        product.currentStock.toString(),
                        style: TextStyle(
                          color: stockColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "Stock",
                        style: TextStyle(color: stockColor, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}