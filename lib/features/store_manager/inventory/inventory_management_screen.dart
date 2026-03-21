import 'package:flutter/material.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/constants/app_routes.dart';
import '../widgets/manager_app_bar.dart';

/// Inventory Management screen.
/// Shows inventory summary, search/filter, and product list.
class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() =>
      _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  // Product list
  List<ProductModel> _products = [];
  List<ProductModel> _filteredProducts = [];
  int _pendingRequestsCount = 0;
  bool _isLoading = true;

  // Current filters
  String _activeFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to avoid calling setState during initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _loadProducts(),
        _loadPendingRequestsCount(),
      ]);
    } catch (e) {
      debugPrint('Error in _loadData: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Load products from Firestore.
  Future<void> _loadProducts() async {
    try {
      final snapshot = await _firestoreService.getCollection('products');
      final products = snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc))
          .toList();

      if (mounted) {
        setState(() {
          _products = products;
          _applyFilter();
        });
      }
    } catch (e) {
      debugPrint('Failed to load products: $e');
      rethrow;
    }
  }

  /// Load the count of pending stock requests.
  Future<void> _loadPendingRequestsCount() async {
    try {
      final snapshot = await _firestoreService.db
          .collection('stock_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      if (mounted) {
        setState(() {
          _pendingRequestsCount = snapshot.docs.length;
        });
      }
    } catch (e) {
      debugPrint('Failed to load pending requests count: $e');
      rethrow;
    }
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} VND';
  }

  /// Apply filters based on stock status.
  void _applyFilter() {
    final query = _searchController.text.toLowerCase();

    final filtered = _products.where((p) {
      // Keyword filter
      final matchesSearch = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.sku.toLowerCase().contains(query);

      // Stock-status filter
      final matchesFilter =
          _activeFilter == 'All' || p.stockStatus == _activeFilter;

      return matchesSearch && matchesFilter;
    }).toList();

    if (mounted) {
      setState(() {
        _filteredProducts = filtered;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Summary stats
    final totalItems = _products.length;
    final lowStockCount = _products.where((p) =>
        p.stockStatus == 'Low Stock' || p.stockStatus == 'Critical').length;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: const ManagerAppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              // ===== SUMMARY CARDS =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    children: [
                      _buildSummaryCard(
                        title: 'Total Items',
                        value: '$totalItems',
                        icon: Icons.inventory,
                        backgroundColor: colorScheme.surfaceContainerLow,
                        textColor: colorScheme.onSurface,
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryCard(
                        title: 'Low Stock Alerts',
                        value: '$lowStockCount',
                        icon: Icons.warning_amber,
                        backgroundColor: colorScheme.secondaryContainer,
                        textColor: colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryCard(
                        title: 'Pending Requests',
                        value: '$_pendingRequestsCount',
                        icon: Icons.pending_actions,
                        backgroundColor: colorScheme.surfaceContainerLow,
                        textColor: colorScheme.onSurface,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.tonalIcon(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.recentRequests).then((_) => _loadData()),
                          icon: const Icon(Icons.history),
                          label: const Text('View Recent Requests', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ===== SEARCH =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _applyFilter(),
                    decoration: InputDecoration(
                      hintText: 'Search for products...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),

              // ===== FILTER CHIPS =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          ['All', 'Low Stock', 'Out of Stock', 'Critical']
                              .map(
                                (filter) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _buildFilterChip(filter),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ),
              ),

              // ===== PRODUCT LIST =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    'Inventory Items',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              _isLoading
                  ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                  : _filteredProducts.isEmpty
                  ? SliverFillRemaining(
                    child: Center(
                      child: Text('No products found', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    ),
                  )
                  : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    sliver: SliverList.separated(
                      itemCount: _filteredProducts.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _buildProductItem(_filteredProducts[index]);
                      },
                    ),
                  ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.stockImportRequest).then((_) => _loadData());
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1,
                ),
              ),
              Icon(icon, color: textColor.withOpacity(0.6), size: 24),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = _activeFilter == label;

    return GestureDetector(
      onTap: () {
        setState(() => _activeFilter = label);
        _applyFilter();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.primary : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isActive ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildProductItem(ProductModel product) {
    final colorScheme = Theme.of(context).colorScheme;
    Color badgeColor;
    Color badgeText;
    
    switch (product.stockStatus) {
      case 'Critical':
        badgeColor = colorScheme.errorContainer;
        badgeText = colorScheme.onErrorContainer;
        break;
      case 'Low Stock':
        badgeColor = colorScheme.secondaryContainer;
        badgeText = colorScheme.onSecondaryContainer;
        break;
      case 'Out of Stock':
        badgeColor = colorScheme.errorContainer;
        badgeText = colorScheme.error;
        break;
      default:
        badgeColor = colorScheme.surfaceContainerHighest;
        badgeText = colorScheme.onSurfaceVariant;
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.productDetail,
            arguments: product,
          ).then((_) => _loadProducts());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: product.image != null && product.image!.isNotEmpty
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(product.image!, fit: BoxFit.cover),
                    )
                    : const Icon(Icons.inventory_2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatCurrency(product.price),
                          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            product.stockStatus.toUpperCase(),
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: badgeText),
                          ),
                        ),
                        Text(
                          'Stock: ${product.stock} units',
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
