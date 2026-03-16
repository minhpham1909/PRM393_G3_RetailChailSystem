import 'package:flutter/material.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/product_model.dart';

/// Màn hình Yêu cầu Nhập hàng (Stock Import Request)
/// Cho phép Store Manager tạo yêu cầu nhập hàng về cửa hàng
/// Thiết kế theo stitch template: stock_import_request
class StockImportRequestScreen extends StatefulWidget {
  const StockImportRequestScreen({super.key});

  @override
  State<StockImportRequestScreen> createState() =>
      _StockImportRequestScreenState();
}

class _StockImportRequestScreenState extends State<StockImportRequestScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  // Danh sách sản phẩm đã chọn để nhập hàng
  final List<_SelectedProduct> _selectedProducts = [];

  // Thông tin form
  String _sourceWarehouse = 'Central Master Warehouse (WH_MASTER_01)';
  String _priority = 'Normal';
  DateTime? _expectedDate;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // Danh sách sản phẩm tìm kiếm được
  List<ProductModel> _searchResults = [];
  // Trạng thái đang tìm kiếm (dùng cho loading indicator)

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lấy product từ argument nếu có
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is ProductModel && _selectedProducts.isEmpty) {
      setState(() {
        _selectedProducts.add(_SelectedProduct(product: args, quantity: 1));
      });
    }
  }

  /// Tìm kiếm sản phẩm theo tên hoặc SKU
  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }



    try {
      final snapshot = await _firestoreService.getCollection('products');
      final products =
          snapshot.docs
              .map((doc) => ProductModel.fromFirestore(doc))
              .where(
                (p) =>
                    p.name.toLowerCase().contains(query.toLowerCase()) ||
                    p.sku.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();

      if (mounted) {
        setState(() {
          _searchResults = products;
        });
      }
    } catch (e) {
      debugPrint('Lỗi tìm kiếm sản phẩm: $e');
      if (mounted) setState(() {});
    }
  }

  /// Thêm sản phẩm vào danh sách yêu cầu
  void _addProduct(ProductModel product) {
    // Kiểm tra trùng lặp
    final exists = _selectedProducts.any(
      (p) => p.product.productId == product.productId,
    );
    if (!exists) {
      setState(() {
        _selectedProducts.add(
          _SelectedProduct(product: product, quantity: 1),
        );
        _searchController.clear();
        _searchResults = [];
      });
    }
  }

  /// Gửi yêu cầu nhập hàng
  Future<void> _submitRequest() async {
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 1 sản phẩm')),
      );
      return;
    }

    try {
      // Tạo document yêu cầu nhập hàng trong Firestore
      await _firestoreService.addDocument('stock_requests', {
        'products':
            _selectedProducts
                .map(
                  (p) => {
                    'product_id': p.product.productId,
                    'product_name': p.product.name,
                    'sku': p.product.sku,
                    'quantity': p.quantity,
                  },
                )
                .toList(),
        'source_warehouse': _sourceWarehouse,
        'priority': _priority,
        'expected_date': _expectedDate?.toIso8601String(),
        'notes': _notesController.text,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'total_items': _selectedProducts.fold(0, (sum, p) => sum + p.quantity),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Yêu cầu nhập hàng đã được gửi thành công!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi gửi yêu cầu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      // ===== APP BAR =====
      appBar: AppBar(
        title: const Text('Stock Request'),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== HEADER: Tiêu đề + Badge =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NEW REQUEST DETAILS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'MANAGER MODE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ===== CHỌN SẢN PHẨM =====
            _buildProductSelectionSection(context),
            const SizedBox(height: 16),

            // ===== NGUỒN KHO + ĐỘ ƯU TIÊN =====
            _buildLogisticsSection(context),
            const SizedBox(height: 16),

            // ===== NGÀY GIAO + GHI CHÚ =====
            _buildDateNotesSection(context),
            const SizedBox(height: 24),

            // ===== NÚT GỬI YÊU CẦU =====
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitRequest,
                icon: const Icon(Icons.send),
                label: const Text(
                  'Submit Request',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Phần chọn sản phẩm — theo stitch: card trắng, search, danh sách đã chọn
  Widget _buildProductSelectionSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề phần
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.inventory_2,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product Selection',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Add items to your replenishment list',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Ô tìm kiếm sản phẩm
          TextField(
            controller: _searchController,
            onChanged: _searchProducts,
            decoration: InputDecoration(
              hintText: 'Search SKU or Product Name...',
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),

          // Kết quả tìm kiếm
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final product = _searchResults[index];
                  return ListTile(
                    dense: true,
                    title: Text(product.name, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      'SKU: ${product.sku}',
                      style: const TextStyle(fontSize: 10),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      onPressed: () => _addProduct(product),
                    ),
                    onTap: () => _addProduct(product),
                  );
                },
              ),
            ),
          ],

          // Danh sách sản phẩm đã chọn
          if (_selectedProducts.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._selectedProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final selected = entry.value;
              return _buildSelectedProductItem(selected, index);
            }),
          ],

          // Nút thêm sản phẩm khác
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              // Focus vào ô tìm kiếm
              FocusScope.of(context).requestFocus(FocusNode());
            },
            icon: const Icon(Icons.add_circle_outline, size: 16),
            label: const Text('Add Another Item'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
              side: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.3),
                style: BorderStyle.solid,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Widget hiển thị sản phẩm đã chọn với stepper số lượng
  Widget _buildSelectedProductItem(_SelectedProduct selected, int index) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceBright,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          bottom: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      child: Row(
        children: [
          // Ảnh sản phẩm
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.inventory_2,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Tên + SKU
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected.product.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'SKU: ${selected.product.sku}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Stepper số lượng (+/-)
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nút giảm
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  onPressed: () {
                    setState(() {
                      if (selected.quantity > 1) {
                        selected.quantity--;
                      } else {
                        _selectedProducts.removeAt(index);
                      }
                    });
                  },
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
                // Hiển thị số lượng
                SizedBox(
                  width: 36,
                  child: Text(
                    '${selected.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Nút tăng
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () {
                    setState(() => selected.quantity++);
                  },
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Phần nguồn kho + độ ưu tiên — theo stitch: dropdown + button group
  Widget _buildLogisticsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Dropdown chọn kho nguồn
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SOURCE WAREHOUSE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _sourceWarehouse,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colorScheme.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Central Master Warehouse (WH_MASTER_01)',
                    child: Text('Central Master Warehouse (WH_MASTER_01)', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: 'Direct Vendor Ship',
                    child: Text('Direct Vendor Ship', style: TextStyle(fontSize: 13)),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _sourceWarehouse = value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Chọn độ ưu tiên
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REQUEST PRIORITY',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children:
                    ['Normal', 'High', 'Urgent'].map((p) {
                      final isSelected = _priority == p;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: p != 'Urgent' ? 8 : 0,
                          ),
                          child: GestureDetector(
                            onTap: () => setState(() => _priority = p),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? colorScheme.secondaryContainer
                                        : colorScheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(100),
                                border:
                                    isSelected
                                        ? Border.all(
                                          color: colorScheme.primary
                                              .withValues(alpha: 0.3),
                                        )
                                        : null,
                              ),
                              child: Text(
                                p,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isSelected
                                          ? colorScheme.onSecondaryContainer
                                          : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Phần ngày giao dự kiến + ghi chú
  Widget _buildDateNotesSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chọn ngày
          Text(
            'EXPECTED DELIVERY DATE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 3)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );
              if (date != null) setState(() => _expectedDate = date);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _expectedDate != null
                        ? '${_expectedDate!.day}/${_expectedDate!.month}/${_expectedDate!.year}'
                        : 'mm/dd/yyyy',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          _expectedDate != null
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Ghi chú
          Text(
            'ADDITIONAL NOTES',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Reason for request, special handling instructions...',
              hintStyle: const TextStyle(fontSize: 13),
              filled: true,
              fillColor: colorScheme.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }



}

/// Class nội bộ đại diện sản phẩm đã chọn với số lượng
class _SelectedProduct {
  final ProductModel product;
  int quantity;

  _SelectedProduct({required this.product, required this.quantity});
}
