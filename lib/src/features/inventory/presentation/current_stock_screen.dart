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

  // --- CRUD ACTIONS ---

  void _showEditDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => _EditProductDialog(product: product),
    );
  }

  void _confirmDelete(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Product?"),
        content: Text("Are you sure you want to delete ${product.model}?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                // ACID Compliant Delete (Handled in Repository)
                await ref
                    .read(inventoryRepositoryProvider)
                    .deleteProduct(product.id, product.model);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Product Deleted")));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                }
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
    final inventoryAsync = ref.watch(inventoryStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Current Stock")),
      // 1. CREATE (Receive Stock)
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

          // 2. READ (List View)
          Expanded(
            child: inventoryAsync.when(
              data: (products) {
                final availableProducts = products.where((p) {
                  // Filter logic: Show items with stock > 0 OR if searching (to find items to edit/delete even if 0)
                  // But requirement said "once a model stock is zero then it automatically remove"
                  // So we strictly filter stock > 0
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
                      onEdit: _showEditDialog,
                      onDelete: _confirmDelete,
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
  final Function(Product) onEdit;
  final Function(Product) onDelete;

  const _CategoryStockCard({
    required this.categoryName,
    required this.products,
    required this.onEdit,
    required this.onDelete,
  });

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

    // Summaries
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
                  valueColor: Colors.green),
            ],
          ),
          leading: CircleAvatar(
            backgroundColor: primaryColor.withOpacity(0.1),
            child: Icon(Icons.category_rounded, color: primaryColor),
          ),
          backgroundColor: isDark ? Colors.black12 : primaryColor.withOpacity(0.02),
          collapsedBackgroundColor: Colors.transparent,
          childrenPadding: const EdgeInsets.only(bottom: 8),
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
                    children: [
                      // --- NEW: Commission Info ---
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "Comm",
                            style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white38 : Colors.grey[500]),
                          ),
                          Text(
                            "${p.commissionPercent.toStringAsFixed(0)}%",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue, // Distinct color for commission
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // MRP Info
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
                      const SizedBox(width: 8),

                      // Stock Alarm
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

                      // 3. ACTIONS (Update/Delete)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: isDark ? Colors.white54 : Colors.grey),
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        onSelected: (value) {
                          if (value == 'edit') onEdit(p);
                          if (value == 'delete') onDelete(p);
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit, color: Colors.blue, size: 20),
                                const SizedBox(width: 10),
                                Text("Edit Details", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete, color: Colors.red, size: 20),
                                const SizedBox(width: 10),
                                Text("Delete Item", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                              ],
                            ),
                          ),
                        ],
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
          // Label Text
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.grey[700],
            ),
          ),
          // Add a small gap
          const SizedBox(width: 8),
          // 👇 FIXED: Wrapped in Flexible to prevent overflow
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: valueColor ?? (isDark ? Colors.white70 : Colors.black87),
              ),
              overflow: TextOverflow.ellipsis, // Add ellipsis (...) if it's still too long
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// 4. EDIT DIALOG (Update)
class _EditProductDialog extends ConsumerStatefulWidget {
  final Product product;
  const _EditProductDialog({required this.product});

  @override
  ConsumerState<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends ConsumerState<_EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _mrpCtrl;
  late TextEditingController _commCtrl;
  late TextEditingController _stockCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product.name);
    _modelCtrl = TextEditingController(text: widget.product.model);
    _mrpCtrl = TextEditingController(text: widget.product.marketPrice.toStringAsFixed(0));
    _commCtrl = TextEditingController(text: widget.product.commissionPercent.toString());
    _stockCtrl = TextEditingController(text: widget.product.currentStock.toString());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputStyle = TextStyle(color: isDark ? Colors.white : Colors.black87);

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      title: Text("Edit ${widget.product.model}", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _modelCtrl,
                style: inputStyle,
                decoration: _dialogDecor("Model"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameCtrl,
                style: inputStyle,
                decoration: _dialogDecor("Product Name"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _stockCtrl,
                style: inputStyle,
                keyboardType: TextInputType.number,
                decoration: _dialogDecor("Stock Quantity"),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mrpCtrl,
                      style: inputStyle,
                      keyboardType: TextInputType.number,
                      decoration: _dialogDecor("MRP"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _commCtrl,
                      style: inputStyle,
                      keyboardType: TextInputType.number,
                      decoration: _dialogDecor("Comm %"),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;

            final mrp = double.tryParse(_mrpCtrl.text) ?? 0;
            final comm = double.tryParse(_commCtrl.text) ?? 0;
            final stock = int.tryParse(_stockCtrl.text) ?? 0;
            final buyingPrice = mrp - (mrp * (comm / 100));

            // Create updated object
            final updatedProduct = Product(
              id: widget.product.id,
              name: _nameCtrl.text.trim(),
              model: _modelCtrl.text.trim(),
              category: widget.product.category, // Keep category
              capacity: widget.product.capacity,
              color: widget.product.color,
              marketPrice: mrp,
              commissionPercent: comm,
              buyingPrice: buyingPrice,
              currentStock: stock,
              lastUpdated: DateTime.now(),
            );

            try {
              // ACID Compliant Update
              await ref.read(inventoryRepositoryProvider).updateProduct(updatedProduct);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product Updated")));
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
            }
          },
          child: const Text("Save"),
        )
      ],
    );
  }

  InputDecoration _dialogDecor(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}