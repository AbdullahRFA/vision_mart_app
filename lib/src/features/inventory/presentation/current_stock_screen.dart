import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/inventory_repository.dart';
import '../domain/product_model.dart';
import 'receive_product_screen.dart'; // Import the form screen

class CurrentStockScreen extends ConsumerStatefulWidget {
  const CurrentStockScreen({super.key});

  @override
  ConsumerState<CurrentStockScreen> createState() => _CurrentStockScreenState();
}

class _CurrentStockScreenState extends ConsumerState<CurrentStockScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Current Stock")),
      // i) Floating Action Button to Receive Stock
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReceiveProductScreen()),
          );
        },
        label: const Text("Receive Stock"),
        icon: const Icon(Icons.add_shopping_cart),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search Model, Category...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),

          Expanded(
            child: inventoryAsync.when(
              data: (products) {
                // Filter: currentStock > 0 AND matches search
                final availableProducts = products.where((p) {
                  final hasStock = p.currentStock > 0; // Auto-remove zero stock
                  final matchesSearch = p.model.toLowerCase().contains(_searchQuery) ||
                      p.category.toLowerCase().contains(_searchQuery);
                  return hasStock && matchesSearch;
                }).toList();

                if (availableProducts.isEmpty) {
                  return const Center(child: Text("No stock available."));
                }

                // ii) Group by Category
                final Map<String, List<Product>> grouped = {};
                for (var p in availableProducts) {
                  if (!grouped.containsKey(p.category)) grouped[p.category] = [];
                  grouped[p.category]!.add(p);
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80), // Padding for FAB
                  children: grouped.entries.map((entry) {
                    return _CategoryStockCard(
                      categoryName: entry.key,
                      products: entry.value,
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text("Error: $e")),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryStockCard extends StatelessWidget {
  final String categoryName;
  final List<Product> products;

  const _CategoryStockCard({required this.categoryName, required this.products});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(
              categoryName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),

          // Product List
          ...products.map((p) => Column(
            children: [
              ListTile(
                title: Text(
                  p.model,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(p.name),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                        "Stock: ${p.currentStock}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                    ),
                    Text(
                      "MRP: ৳${p.marketPrice.toStringAsFixed(0)}",
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (p != products.last)
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
            ],
          )),
        ],
      ),
    );
  }
}