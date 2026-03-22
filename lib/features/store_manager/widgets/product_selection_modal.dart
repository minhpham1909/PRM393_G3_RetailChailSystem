import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/models/product_model.dart';
import '../../../core/services/firestore_service.dart';

/// Represents a selected product with quantity.
class SelectedProduct {
  final ProductModel product;
  int quantity;

  SelectedProduct({required this.product, required this.quantity});
}

/// Reusable product selection modal (used for Stock Request and POS).
class ProductSelectionModal extends StatefulWidget {
  final List<SelectedProduct> initialSelected;
  final String actionLabel;
  final String? storeId;

  const ProductSelectionModal({
    super.key, 
    required this.initialSelected,
    this.actionLabel = 'Add Items',
    this.storeId,
  });

  @override
  State<ProductSelectionModal> createState() => _ProductSelectionModalState();
}

class _ProductSelectionModalState extends State<ProductSelectionModal> {
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription? _productsSubscription;
  StreamSubscription? _inventorySubscription;
  
  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  final Map<String, int> _branchStockMap = {}; // SKU -> Stock record
  final List<String> _categories = ['All Categories'];
  
  String _searchQuery = '';
  String _selectedCategory = 'All Categories';
  bool _isLoading = true;

  final Map<String, SelectedProduct> _localSelected = {};

  @override
  void initState() {
    super.initState();
    for (var item in widget.initialSelected) {
      _localSelected[item.product.productId] = SelectedProduct(
        product: item.product, 
        quantity: item.quantity,
      );
    }
    _listenToProducts();
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _inventorySubscription?.cancel();
    super.dispose();
  }

  /// Listen to the product list and inventory list from Firestore.
  void _listenToProducts() {
    setState(() => _isLoading = true);
    
    // 1. Listen to Master Data (Products)
    _productsSubscription = _firestoreService.streamCollection('products').listen((snapshot) {
      final products = snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();
      final cats = products.map((p) => p.category).toSet().toList();
      cats.sort();
      
      if (mounted) {
        setState(() {
          _allProducts = products;
          _categories.clear();
          _categories.add('All Categories');
          _categories.addAll(cats);
        });
        _filterProducts();
        if (widget.storeId == null) {
          setState(() => _isLoading = false);
        }
      }
    });

    // 2. Listen to Branch Inventory if storeId is provided
    if (widget.storeId != null) {
      _inventorySubscription = _firestoreService.db
          .collection('inventory')
          .where('store_id', isEqualTo: widget.storeId)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _branchStockMap.clear();
            for (var doc in snapshot.docs) {
              final data = doc.data();
              final sku = data['product_sku'];
              final stock = data['stock'] ?? 0;
              if (sku != null) {
                _branchStockMap[sku] = (stock as num).toInt();
              }
            }
            _isLoading = false;
          });
          _filterProducts();
        }
      }, onError: (e) {
        debugPrint('Failed to load inventory for modal: $e');
        if (mounted) setState(() => _isLoading = false);
      });
    }
  }
  
  void _filterProducts() {
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        final matchCategory = _selectedCategory == 'All Categories' || p.category == _selectedCategory;
        final matchSearch = _searchQuery.isEmpty || 
            p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
            p.sku.toLowerCase().contains(_searchQuery.toLowerCase());
            
        // Get stock level (prefer branch stock, fallback to product global stock)
        final stock = widget.storeId != null 
            ? (_branchStockMap[p.sku] ?? 0) 
            : p.stock;

        // Only show products in stock (stock > 0).
        return matchCategory && matchSearch && stock > 0;
      }).toList();
    });
  }

  void _toggleProduct(ProductModel product) {
    setState(() {
      if (_localSelected.containsKey(product.productId)) {
        _localSelected.remove(product.productId);
      } else {
        _localSelected[product.productId] = SelectedProduct(product: product, quantity: 1);
      }
    });
  }

  void _submit() {
    Navigator.pop(context, _localSelected.values.toList());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Search & Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              onChanged: (val) {
                _searchQuery = val;
                _filterProducts();
              },
              decoration: InputDecoration(
                hintText: 'Search SKU or Product Name...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Categories
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat, style: TextStyle(fontSize: 12, color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface)),
                    selected: isSelected,
                    selectedColor: colorScheme.primary,
                    onSelected: (bool selected) {
                      setState(() {
                        _selectedCategory = cat;
                        _filterProducts();
                      });
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(height: 24),

          // Product List
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    final isSelected = _localSelected.containsKey(product.productId);
                    
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: product.image != null && product.image!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  product.image!, 
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.inventory_2),
                                ),
                              )
                            : const Icon(Icons.inventory_2),
                      ),
                      title: Text(product.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: Row(
                        children: [
                          Text('SKU: ${product.sku}', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                          const SizedBox(width: 8),
                          _buildStockBadge(product),
                        ],
                      ),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (val) => _toggleProduct(product),
                      ),
                      onTap: () => _toggleProduct(product),
                    );
                  },
                ),
          ),

          // Footer action
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('${widget.actionLabel} (${_localSelected.length})'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockBadge(ProductModel product) {
    final stock = widget.storeId != null 
        ? (_branchStockMap[product.sku] ?? 0) 
        : product.stock;
    
    final color = stock <= 5 ? Colors.red : Colors.green[700];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color?.withValues(alpha: 0.5) ?? Colors.grey),
      ),
      child: Text(
        'Stock: $stock',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
