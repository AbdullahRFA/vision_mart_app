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

  // Filter State
  String _selectedCategory = "All";

  // Define your main categories here (matches what you type in Receive Product)
  final List<String> _categories = [
    "All",
    "Low Stock", // Special Filter
    "TV",
    "Refrigerator",
    "AC",
    "Fan",
    "Washing Machine",
    "Other"
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsyncValue = ref.watch(inventoryStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Current Inventory')),
      body: Column(
        children: [
          // 1. SEARCH BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by Name or Model',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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
                // Special styling for "Low Stock" to make it urgent
                final isLowStockChip = category == "Low Stock";

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    selectedColor: isLowStockChip ? Colors.red.shade100 : Colors.blue.shade100,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? (isLowStockChip ? Colors.red : Colors.blue.shade900)
                          : Colors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 20),

          // 3. PRODUCT LIST
          Expanded(
            child: inventoryAsyncValue.when(
              data: (products) {
                // FILTERING LOGIC
                final filteredProducts = products.where((p) {
                  // A. Search Query Check
                  final matchesSearch = p.name.toLowerCase().contains(_searchQuery) ||
                      p.model.toLowerCase().contains(_searchQuery);

                  if (!matchesSearch) return false;

                  // B. Category / Low Stock Check
                  if (_selectedCategory == "All") {
                    return true;
                  } else if (_selectedCategory == "Low Stock") {
                    return p.currentStock < 5; // Low Stock Threshold
                  } else {
                    // Category Matching (Case insensitive partial match)
                    return p.category.toLowerCase().contains(_selectedCategory.toLowerCase());
                  }
                }).toList();

                if (filteredProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text(
                          _selectedCategory == "Low Stock"
                              ? "No items are running low!"
                              : "No products found.",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80), // Space for FAB if needed
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return _ProductCard(product: product);
                  },
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

  Color _getStockColor(int stock) {
    if (stock == 0) return Colors.red;
    if (stock < 5) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _getStockColor(product.currentStock).withOpacity(0.1),
          child: Text(
            product.currentStock.toString(),
            style: TextStyle(
              color: _getStockColor(product.currentStock),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          product.model,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4)
                  ),
                  child: Text(product.category, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                Text(
                  "MRP: ৳${product.marketPrice.toStringAsFixed(0)}",
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SellProductScreen(product: product),
            ),
          );
        },
      ),
    );
  }
}