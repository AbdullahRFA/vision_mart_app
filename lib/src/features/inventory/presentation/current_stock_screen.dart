import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/inventory_repository.dart';
import '../domain/product_model.dart';
import 'receive_product_screen.dart';

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ReceiveProductScreen()),
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
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),

          Expanded(
            child: inventoryAsync.when(
              data: (products) {
                // Filter: currentStock > 0 AND matches search
                final availableProducts = products.where((p) {
                  final hasStock = p.currentStock > 0;
                  final matchesSearch =
                      p.model.toLowerCase().contains(_searchQuery) ||
                          p.category.toLowerCase().contains(_searchQuery);
                  return hasStock && matchesSearch;
                }).toList();

                if (availableProducts.isEmpty) {
                  return const Center(child: Text("No stock available."));
                }

                // Group by Category
                final Map<String, List<Product>> grouped = {};
                for (var p in availableProducts) {
                  if (!grouped.containsKey(p.category)) {
                    grouped[p.category] = [];
                  }
                  grouped[p.category]!.add(p);
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
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

  const _CategoryStockCard(
      {required this.categoryName, required this.products});

  Color _getStockColor(int stock) {
    if (stock < 5) return Colors.red;
    if (stock <= 20) return Colors.orange;
    return Colors.green;
  }

  String _getStockStatus(int stock) {
    if (stock < 5) return "Low";
    if (stock <= 20) return "Med";
    return "High";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    // 1. Calculate Summaries
    final int totalModels = products.length;
    final int totalQuantity = products.fold(0, (sum, p) => sum + p.currentStock);
    final double totalValue = products.fold(0, (sum, p) => sum + (p.buyingPrice * p.currentStock));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // 2. Custom Header Display
          title: Text(
            categoryName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : primaryColor,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildSummaryRow("Total Available Models:", "$totalModels", isDark),
              _buildSummaryRow("Total Product Quantity:", "$totalQuantity", isDark),
              _buildSummaryRow(
                  "Total Stock Value:",
                  "৳${totalValue.toStringAsFixed(0)}",
                  isDark,
                  valueColor: Colors.green
              ),
            ],
          ),
          leading: CircleAvatar(
            backgroundColor: primaryColor.withOpacity(0.1),
            child: Icon(Icons.category_rounded, color: primaryColor),
          ),
          backgroundColor: isDark ? Colors.black12 : primaryColor.withOpacity(0.02),
          collapsedBackgroundColor: Colors.transparent,
          childrenPadding: const EdgeInsets.only(bottom: 8),

          // 3. Expanded Product List
          children: products.map((p) {
            final stockColor = _getStockColor(p.currentStock);
            final statusLabel = _getStockStatus(p.currentStock);

            return Column(
              children: [
                Divider(
                    height: 1,
                    thickness: 0.5,
                    color: isDark ? Colors.white10 : Colors.grey.shade200),
                ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(
                    p.model,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    p.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "MRP",
                            style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white38 : Colors.grey[500]),
                          ),
                          Text(
                            "৳${p.marketPrice.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: stockColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: stockColor.withOpacity(0.3), width: 1),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "${p.currentStock}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: stockColor,
                              ),
                            ),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: stockColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valueColor ?? (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}