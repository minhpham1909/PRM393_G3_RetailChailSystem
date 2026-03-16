import 'package:flutter/material.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/constants/app_routes.dart';
import '../widgets/manager_app_bar.dart';

/// Màn hình Quản lý Tồn kho (Inventory Management)
/// Hiển thị tổng quan tồn kho, tìm kiếm/lọc sản phẩm, danh sách sản phẩm
/// Thiết kế theo stitch template: inventory_management
class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() =>
      _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  // Danh sách sản phẩm
  List<ProductModel> _products = [];
  List<ProductModel> _filteredProducts = [];
  bool _isLoading = true;

  // Bộ lọc hiện tại
  String _activeFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Tải danh sách sản phẩm từ Firestore
  Future<void> _loadProducts() async {
    try {
      final snapshot = await _firestoreService.getCollection('products');
      final products =
          snapshot.docs
              .map((doc) => ProductModel.fromFirestore(doc))
              .toList();

      if (mounted) {
        setState(() {
          _products = products;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Lỗi tải danh sách sản phẩm: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Áp dụng bộ lọc theo trạng thái tồn kho
  void _applyFilter() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredProducts =
          _products.where((p) {
            // Lọc theo từ khóa
            final matchesSearch =
                query.isEmpty ||
                p.name.toLowerCase().contains(query) ||
                p.sku.toLowerCase().contains(query);

            // Lọc theo trạng thái
            final matchesFilter =
                _activeFilter == 'All' || p.stockStatus == _activeFilter;

            return matchesSearch && matchesFilter;
          }).toList();
    });
  }



  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Tính thống kê
    final totalItems = _products.length;
    final lowStockCount = _products.where((p) =>
        p.stockStatus == 'Low Stock' || p.stockStatus == 'Critical').length;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: const ManagerAppBar(title: 'Store Inventory'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProducts,
          child: CustomScrollView(
            slivers: [
              // ===== THẺ THỐNG KÊ TỔNG QUAN =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    children: [
                      // Thẻ 1: Tổng sản phẩm
                      _buildSummaryCard(
                        title: 'Total Items',
                        value: '$totalItems',
                        icon: Icons.inventory,
                        backgroundColor: colorScheme.surfaceContainerLow,
                        textColor: colorScheme.onSurface,
                      ),
                      const SizedBox(height: 12),
                      // Thẻ 2: Cảnh báo tồn kho thấp (xanh lá)
                      _buildSummaryCard(
                        title: 'Low Stock Alerts',
                        value: '$lowStockCount',
                        icon: Icons.warning_amber,
                        backgroundColor: colorScheme.secondaryContainer,
                        textColor: colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(height: 12),
                      // Thẻ 3: Yêu cầu đang chờ
                      _buildSummaryCard(
                        title: 'Pending Requests',
                        value: '0',
                        icon: Icons.pending_actions,
                        backgroundColor: colorScheme.surfaceContainerLow,
                        textColor: colorScheme.onSurface,
                      ),
                      const SizedBox(height: 16),
                      // Nút xem Recent Requests
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.tonalIcon(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.recentRequests),
                          icon: const Icon(Icons.history),
                          label: const Text('View Recent Requests', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ===== Ô TÌM KIẾM =====
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

              // ===== BỘ LỌC CHIP =====
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

              // ===== TIÊU ĐỀ DANH SÁCH =====
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

              // ===== DANH SÁCH SẢN PHẨM =====
              _isLoading
                  ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                  : _filteredProducts.isEmpty
                  ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No products found',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
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
      // Nút FAB thêm sản phẩm / tạo yêu cầu nhập hàng
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Chuyển đến màn hình Stock Import Request
          Navigator.pushNamed(context, AppRoutes.stockImportRequest);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Widget thẻ tóm tắt — theo stitch: card với giá trị lớn + icon
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
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1,
                ),
              ),
              Icon(icon, color: textColor.withValues(alpha: 0.6), size: 24),
            ],
          ),
        ],
      ),
    );
  }

  /// Widget chip bộ lọc — theo stitch: rounded-full, active = filled
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

  /// Widget hiển thị một sản phẩm — theo stitch: ảnh, tên, badge, stock, action
  Widget _buildProductItem(ProductModel product) {
    final colorScheme = Theme.of(context).colorScheme;

    // Chọn màu badge theo trạng thái tồn kho
    Color badgeBg;
    Color badgeText;
    switch (product.stockStatus) {
      case 'Critical':
        badgeBg = colorScheme.errorContainer;
        badgeText = colorScheme.onErrorContainer;
        break;
      case 'Low Stock':
        badgeBg = colorScheme.secondaryContainer;
        badgeText = colorScheme.onSecondaryContainer;
        break;
      case 'Out of Stock':
        badgeBg = colorScheme.errorContainer;
        badgeText = colorScheme.error;
        break;
      default:
        badgeBg = colorScheme.surfaceContainerHighest;
        badgeText = colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Ảnh sản phẩm
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                product.image != null && product.image!.isNotEmpty
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        product.image!,
                        fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.image_outlined,
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    )
                    : Icon(
                      Icons.inventory_2,
                      color: colorScheme.onSurfaceVariant,
                    ),
          ),
          const SizedBox(width: 12),
          // Thông tin sản phẩm
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hàng 1: Tên + Badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Badge trạng thái
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        product.stockStatus.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: badgeText,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Hàng 2: Stock + Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Số lượng tồn kho
                    RichText(
                      text: TextSpan(
                        text: 'Stock: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        children: [
                          TextSpan(
                            text: '${product.stock}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color:
                                  product.stockStatus == 'Critical'
                                      ? colorScheme.error
                                      : colorScheme.onSurface,
                            ),
                          ),
                          const TextSpan(text: ' units'),
                        ],
                      ),
                    ),
                    // Nút yêu cầu nhập hàng
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.stockImportRequest,
                          arguments: product,
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Request Stock',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
