import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/firestore_service.dart';

enum _ProductMenuAction { details, edit, delete }

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Management'),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.db.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = snapshot.hasData
              ? snapshot.data!.docs.map((doc) => ProductModel.fromFirestore(doc)).toList()
              : [];

          final lowStockCount = products.where((p) => p.stock < 10).length;
          final filteredProducts = products
              .where((p) =>
                  p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  p.sku.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();

          return SingleChildScrollView(
            child: Column(
              children: [
                // Summary Cards
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text('TOTAL PRODUCTS',
                                  style: Theme.of(context).textTheme.labelSmall),
                              const SizedBox(height: 8),
                              Text(products.length.toString(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text('LOW STOCK',
                                  style: Theme.of(context).textTheme.labelSmall),
                              const SizedBox(height: 8),
                              Text(lowStockCount.toString(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber[700])),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions & Search
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _showAddProductDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add new product'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by name or SKU...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Products List
                if (filteredProducts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('No products found',
                        style: Theme.of(context).textTheme.bodyLarge),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PRODUCT CATALOG (${filteredProducts.length})',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: Colors.grey[600])),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final p = filteredProducts[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: p.image != null && p.image!.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(p.image!,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _buildImagePlaceholder()),
                                      )
                                    : _buildImagePlaceholder(),
                                title: Text(p.name),
                                subtitle: Text(
                                  '${p.sku} • ${p.price.toInt()}₫ | Stock: ${p.stock}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _showProductDetailsDialog(p),
                                trailing: PopupMenuButton<_ProductMenuAction>(
                                  onSelected: (action) {
                                    switch (action) {
                                      case _ProductMenuAction.details:
                                        _showProductDetailsDialog(p);
                                        break;
                                      case _ProductMenuAction.edit:
                                        _showEditProductDialog(p);
                                        break;
                                      case _ProductMenuAction.delete:
                                        _showDeleteConfirmDialog(p);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: _ProductMenuAction.details,
                                      child: Text('View details'),
                                    ),
                                    PopupMenuItem(
                                      value: _ProductMenuAction.edit,
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: _ProductMenuAction.delete,
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 50,
      height: 50,
      color: Colors.grey[300],
      child: const Icon(Icons.image),
    );
  }

  void _showProductDetailsDialog(ProductModel p) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final screenW = MediaQuery.sizeOf(dialogContext).width;
        final contentW = (screenW - 96).clamp(280.0, 520.0).toDouble();

        return AlertDialog(
        title: const Text('Product details'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentW),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.image != null && p.image!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: contentW,
                        height: 200,
                        child: Image.network(
                          p.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: contentW,
                            height: 200,
                            color: Colors.grey[300],
                          ),
                        ),
                      ),
                    ),
                  ),
                _buildDetailRow('Name:', p.name),
                _buildDetailRow('SKU:', p.sku),
                _buildDetailRow('Category:', p.category),
                _buildDetailRow('Price:', '${p.price.toInt()}₫'),
                _buildDetailRow('Stock:', '${p.stock}'),
                _buildDetailRow('Description:', p.description),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
        );
      },
    );
  }

  void _showAddProductDialog() {
    final skuCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '0');
    final descCtrl = TextEditingController();

    String? existingProductId;
    ProductModel? existingProduct;

    Future<void> lookupSku(StateSetter setDialogState) async {
      final sku = skuCtrl.text.trim();
      if (sku.isEmpty) {
        setDialogState(() {
          existingProductId = null;
          existingProduct = null;
        });
        return;
      }

      try {
        final q = await _firestoreService.db
            .collection('products')
            .where('sku', isEqualTo: sku)
            .limit(1)
            .get();
        if (!mounted) return;

        if (q.docs.isEmpty) {
          setDialogState(() {
            existingProductId = null;
            existingProduct = null;
          });
          return;
        }

        final doc = q.docs.first;
        final p = ProductModel.fromFirestore(doc);
        setDialogState(() {
          existingProductId = doc.id;
          existingProduct = p;

          nameCtrl.text = p.name;
          categoryCtrl.text = p.category;
          priceCtrl.text = p.price.toString();
          imageCtrl.text = p.image ?? '';
          descCtrl.text = p.description;
          stockCtrl.text = '0';
        });
      } catch (_) {
        // Ignore lookup errors; user can still create new product.
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isRestock = existingProductId != null && existingProduct != null;
          final screenW = MediaQuery.sizeOf(dialogContext).width;
          final contentW = (screenW - 96).clamp(280.0, 520.0).toDouble();

          return AlertDialog(
            title: Text(isRestock ? 'Restock inventory' : 'Add new product'),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentW),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: skuCtrl,
                      decoration: InputDecoration(
                        labelText: 'SKU',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Lookup SKU',
                          onPressed: () => lookupSku(setDialogState),
                          icon: const Icon(Icons.search),
                        ),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => lookupSku(setDialogState),
                    ),
                    const SizedBox(height: 12),
                    if (isRestock)
                      SizedBox(
                        width: contentW,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SKU already exists',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${existingProduct!.name} (current stock: ${existingProduct!.stock})',
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (isRestock) const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      enabled: !isRestock,
                      decoration: const InputDecoration(
                        labelText: 'Product name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryCtrl,
                      enabled: !isRestock,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      enabled: !isRestock,
                      decoration: const InputDecoration(
                        labelText: 'Price (VND)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stockCtrl,
                      decoration: InputDecoration(
                        labelText: isRestock ? 'Quantity to add' : 'Stock',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: imageCtrl,
                      enabled: !isRestock,
                      decoration: const InputDecoration(
                        labelText: 'Image URL (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      enabled: !isRestock,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);

                  final sku = skuCtrl.text.trim();
                  final name = nameCtrl.text.trim();
                  final category = categoryCtrl.text.trim();
                  final price = double.tryParse(priceCtrl.text.trim());
                  final qty = int.tryParse(stockCtrl.text.trim());

                  if (sku.isEmpty) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Please enter an SKU')),
                    );
                    return;
                  }

                  if (qty == null || qty < 0) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Invalid quantity')),
                    );
                    return;
                  }

                  if (!isRestock) {
                    if (name.isEmpty || category.isEmpty || price == null) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Please fill in all required fields')),
                      );
                      return;
                    }
                  }

                  try {
                    if (isRestock) {
                      final newStock = existingProduct!.stock + qty;
                      await _firestoreService.db
                          .collection('products')
                          .doc(existingProductId)
                          .update({'stock': newStock});
                    } else {
                      await _firestoreService.db.collection('products').add({
                        'sku': sku,
                        'name': name,
                        'category': category,
                        'price': price,
                        'stock': qty,
                        'image': imageCtrl.text.trim().isEmpty
                            ? null
                            : imageCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                      });
                    }

                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          isRestock
                              ? 'Stock increased successfully'
                              : 'Product added successfully',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: Text(isRestock ? 'Increase stock' : 'Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditProductDialog(ProductModel p) {
    final skuCtrl = TextEditingController(text: p.sku);
    final nameCtrl = TextEditingController(text: p.name);
    final categoryCtrl = TextEditingController(text: p.category);
    final priceCtrl = TextEditingController(text: p.price.toString());
    final imageCtrl = TextEditingController(text: p.image ?? '');
    final stockCtrl = TextEditingController(text: p.stock.toString());
    final descCtrl = TextEditingController(text: p.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: skuCtrl,
                  enabled: false,
                  decoration:
                      const InputDecoration(labelText: 'SKU', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Product name', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: categoryCtrl,
                  decoration:
                    const InputDecoration(labelText: 'Category', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: priceCtrl,
                  decoration:
                    const InputDecoration(labelText: 'Price (VND)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(
                  controller: stockCtrl,
                  decoration:
                    const InputDecoration(labelText: 'Stock', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(
                  controller: imageCtrl,
                  decoration:
                    const InputDecoration(labelText: 'Image URL', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: descCtrl,
                  decoration:
                    const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  maxLines: 3),
            ],
          ),
        ),
        actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await _firestoreService.db.collection('products').doc(p.productId).update({
                  'name': nameCtrl.text.trim(),
                  'category': categoryCtrl.text.trim(),
                  'price': double.parse(priceCtrl.text.trim()),
                  'stock': int.parse(stockCtrl.text.trim()),
                  'image': imageCtrl.text.isEmpty ? null : imageCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Updated successfully')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(ProductModel p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm delete'),
        content: Text('Are you sure you want to delete ${p.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await _firestoreService.db.collection('products').doc(p.productId).delete();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Deleted successfully')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
