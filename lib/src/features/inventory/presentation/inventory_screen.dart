import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/inventory_repository.dart';
import '../domain/product_model.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = "";

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
    // 1. Listen to the stream
    final inventoryAsyncValue = ref.watch(inventoryStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Current Inventory')),
      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by Name or Model',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),

          // PRODUCT LIST
          Expanded(
            child: inventoryAsyncValue.when(
              data: (products) {
                // Client-side filtering
                final filteredProducts = products.where((p) {
                  return p.name.toLowerCase().contains(_searchQuery) ||
                      p.model.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filteredProducts.isEmpty) {
                  return const Center(child: Text("No products found."));
                }

                return ListView.builder(
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStockColor(product.currentStock).withOpacity(0.2),
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
            Text(product.name),
            Text(
              "MRP: ${product.marketPrice.toStringAsFixed(0)}",
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // Future: Open Product Detail / Edit Page
        },
      ),
    );
  }
}