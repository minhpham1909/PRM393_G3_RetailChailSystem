import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/product_model.dart';
import '../widgets/product_selection_modal.dart';

/// Stock Import Request screen.
/// Allows a Store Manager to create a stock import request for their store.
/// Designed based on stitch template: stock_import_request
class StockImportRequestScreen extends StatefulWidget {
  const StockImportRequestScreen({super.key});

  @override
  State<StockImportRequestScreen> createState() =>
      _StockImportRequestScreenState();
}

class _StockImportRequestScreenState extends State<StockImportRequestScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  // Danh sách sản phẩm đã chọn để nhập hàng
  final List<SelectedProduct> _selectedProducts = [];

  // Thông tin form
  final String _sourceWarehouse = 'Central Master Warehouse (WH_MASTER_01)';
  String _priority = 'Normal';
  DateTime? _expectedDate;
  final TextEditingController _notesController = TextEditingController();

  // Trạng thái đang tìm kiếm (dùng cho loading indicator)

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lấy product từ argument nếu có
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is ProductModel && _selectedProducts.isEmpty) {
      setState(() {
        _selectedProducts.add(SelectedProduct(product: args, quantity: 1));
      });
    }
  }

  /// Gửi yêu cầu nhập hàng
  Future<void> _submitRequest() async {
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 product')),
      );
      return;
    }

    final stockError = await _validateCentralStockBeforeSubmit();
    if (stockError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(stockError)),
        );
      }
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to submit a request')),
        );
        return;
      }

      String managerId = currentUser.uid;
      String storeId = '';
      try {
        final userQuery = await _firestoreService.db
            .collection('users')
            .where('email', isEqualTo: currentUser.email)
            .limit(1)
            .get();
        if (userQuery.docs.isNotEmpty) {
          final userDoc = userQuery.docs.first;
          final userData = userDoc.data();
          managerId = userDoc.id;
          storeId = (userData['store_id'] ?? '').toString();
        }
      } catch (_) {
        // Fallback to uid; keep storeId empty if not resolvable.
      }

      final items = _selectedProducts
          .map(
            (p) => {
              'product_id': p.product.productId,
              'product_name': p.product.name,
              'product_sku': p.product.sku,
              'quantity': p.quantity,
            },
          )
          .toList();

      // Tạo document yêu cầu nhập hàng trong Firestore
      await _firestoreService.addDocument('stock_requests', {
        'store_id': storeId,
        'manager_id': managerId,
        // New canonical field used by Admin side + mock schema.
        'items': items,
        // Legacy field kept for backward compatibility with older UI.
        'products': items
            .map(
              (i) => {
                'product_id': i['product_id'],
                'product_name': i['product_name'],
                'sku': i['product_sku'],
                'quantity': i['quantity'],
              },
            )
            .toList(),
        'source_warehouse': _sourceWarehouse,
        'priority': _priority,
        'expected_date': _expectedDate != null ? Timestamp.fromDate(_expectedDate!) : null,
        'notes': _notesController.text,
        'status': 'pending',
        'created_at': Timestamp.now(),
        'total_items': _selectedProducts.fold(0, (sum, p) => sum + p.quantity),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Stock import request submitted successfully!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to submit request: $e')),
        );
      }
    }
  }

  /// Validate tồn kho kho trung tâm trước khi submit.
  /// - Không cho request sản phẩm stock = 0
  /// - Chặn nếu quantity vượt quá stock hiện tại
  ///
  /// Trả về string lỗi nếu không hợp lệ, null nếu OK.
  Future<String?> _validateCentralStockBeforeSubmit() async {
    for (final selected in _selectedProducts) {
      try {
        final doc = await _firestoreService.db
            .collection('products')
            .doc(selected.product.productId)
            .get();
        if (!doc.exists) {
          return '❌ Product no longer exists: ${selected.product.name}';
        }
        final data = doc.data() as Map<String, dynamic>;
        final currentStock = (data['stock'] ?? 0).toInt();
        if (currentStock <= 0) {
          return '❌ Out of stock in central warehouse: ${selected.product.name} (${selected.product.sku})';
        }
        if (selected.quantity > currentStock) {
          return '❌ Requested quantity exceeds central warehouse stock (${selected.product.sku}). Max: $currentStock';
        }
      } catch (e) {
        return '❌ Unable to check stock for ${selected.product.sku}: $e';
      }
    }
    return null;
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

          // Nút mở Modal chọn sản phẩm
          OutlinedButton.icon(
            onPressed: () => _showProductSelectionModal(context),
            icon: const Icon(Icons.add_shopping_cart, size: 18),
            label: const Text('Browse & Select Products'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Danh sách sản phẩm đã chọn
          if (_selectedProducts.isNotEmpty) ...[
            const SizedBox(height: 16),
            ..._selectedProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final selected = entry.value;
              return _buildSelectedProductItem(selected, index);
            }),
          ],
        ],
      ),
    );
  }

  /// Widget hiển thị sản phẩm đã chọn với stepper số lượng
  Widget _buildSelectedProductItem(SelectedProduct selected, int index) {
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
                // Hiển thị số lượng cho phép chọn hoặc nhập
                InkWell(
                  onTap: () => _showEditQuantityDialog(index, selected),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${selected.quantity}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                // Nút tăng
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () {
                    final maxQty = selected.product.stock;
                    if (selected.quantity >= maxQty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '❌ Insufficient central stock (${selected.product.sku}). Max: $maxQty',
                          ),
                        ),
                      );
                      return;
                    }
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
              // Kho Hàng Chỉ Đọc
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warehouse, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _sourceWarehouse,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
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

  Future<void> _showProductSelectionModal(BuildContext context) async {
    final result = await showModalBottomSheet<List<SelectedProduct>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductSelectionModal(
        initialSelected: _selectedProducts,
        actionLabel: 'Add Items to Request',
      ),
    );

    if (result != null) {
      setState(() {
        _selectedProducts.clear();
        _selectedProducts.addAll(result);
      });
    }
  }

  Future<void> _showEditQuantityDialog(int index, SelectedProduct selected) async {
    final TextEditingController qtyController = TextEditingController(text: selected.quantity.toString());
    
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Quantity', style: TextStyle(fontSize: 16)),
          content: TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final newQty = int.tryParse(qtyController.text);
                if (newQty == null || newQty <= 0) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('❌ Invalid quantity')),
                  );
                  return;
                }

                final maxQty = selected.product.stock;
                if (newQty > maxQty) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '❌ Quantity exceeds central warehouse stock (${selected.product.sku}). Max: $maxQty',
                      ),
                    ),
                  );
                  return;
                }

                setState(() => selected.quantity = newQty);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

}
