import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/order_model.dart';
import '../widgets/manager_app_bar.dart';
import '../widgets/product_selection_modal.dart';

class PosCheckoutScreen extends StatefulWidget {
  const PosCheckoutScreen({super.key});

  @override
  State<PosCheckoutScreen> createState() => _PosCheckoutScreenState();
}

class _PosCheckoutScreenState extends State<PosCheckoutScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final List<SelectedProduct> _selectedProducts = [];
  String _paymentMethod = 'Cash';
  bool _isProcessing = false;

  // Profile info for order
  String? _managerId;
  String? _storeId;

  @override
  void initState() {
    super.initState();
    _loadProfileInfo();
  }

  Future<void> _loadProfileInfo() async {
    try {
      final usersSnapshot = await _firestoreService.db
          .collection('users')
          .where('role', isEqualTo: 'store_manager')
          .limit(1)
          .get();

      if (usersSnapshot.docs.isNotEmpty) {
        final userData = usersSnapshot.docs.first.data();
        if (mounted) {
          setState(() {
            _managerId = usersSnapshot.docs.first.id;
            _storeId = userData['store_id'];
          });
        }
      }
    } catch (e) {
      debugPrint('Lỗi tải thông tin quản lý cho POS: $e');
    }
  }

  double get _subtotal => _selectedProducts.fold(0.0, (sum, p) => sum + (p.product.price * p.quantity));

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VND';
  }

  Future<void> _handleCheckout() async {
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn sản phẩm trước khi thanh toán')),
      );
      return;
    }

    if (_storeId == null || _managerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi: Không tìm thấy thông tin cửa hàng')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final now = DateTime.now();
      final orderRef = _firestoreService.db.collection('orders').doc();
      
      // Run Transaction to ensure stock is updated atomically
      await _firestoreService.db.runTransaction((transaction) async {
        // 1. Check stock for all items
        for (var sp in _selectedProducts) {
          final productRef = _firestoreService.db.collection('products').doc(sp.product.productId);
          final productDoc = await transaction.get(productRef);
          
          if (!productDoc.exists) {
            throw Exception('Sản phẩm ${sp.product.name} không tồn tại');
          }
          
          final currentStock = (productDoc.data()?['stock'] ?? 0).toInt();
          if (currentStock < sp.quantity) {
            throw Exception('Sản phẩm ${sp.product.name} không đủ tồn kho (Còn: $currentStock)');
          }
        }

        // 2. Decrement stock
        for (var sp in _selectedProducts) {
          final productRef = _firestoreService.db.collection('products').doc(sp.product.productId);
          transaction.update(productRef, {
            'stock_quantity': FieldValue.increment(-sp.quantity),
          });
        }

        // 3. Create Order document
        final orderItems = _selectedProducts.map((sp) => OrderDetailModel(
          orderDetailId: '', // Will be stored in the items array map
          orderId: orderRef.id,
          productId: sp.product.productId,
          quantity: sp.quantity,
          unitPrice: sp.product.price,
        )).toList();

        final order = OrderModel(
          orderId: orderRef.id,
          managerId: _managerId!,
          storeId: _storeId!,
          totalAmount: _subtotal,
          paymentMethod: _paymentMethod,
          createdAt: now,
          orderType: 'sale',
          status: 'paid',
          items: orderItems,
        );

        transaction.set(orderRef, order.toFirestore());
      });

      if (mounted) {
        _showSuccessDialog();
        setState(() {
          _selectedProducts.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi thanh toán: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thanh toán thành công!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text('Đơn hàng đã được ghi nhận và kho đã được cập nhật.', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const ManagerAppBar(),
      body: Column(
        children: [
          // Header / Summary Row
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CHECKOUT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    Text('${_selectedProducts.length} Items Selected', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () => _showProductSelectionModal(context),
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text('Add Items'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                ),
              ],
            ),
          ),

          // Items List
          Expanded(
            child: _selectedProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_basket_outlined, size: 64, color: colorScheme.surfaceContainerHighest),
                        const SizedBox(height: 16),
                        Text('Giỏ hàng trống', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _selectedProducts.length,
                    itemBuilder: (context, index) {
                      final item = _selectedProducts[index];
                      return _buildCartItem(item, index);
                    },
                  ),
          ),

          // Payment & Checkout Area
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Payment Method
                _buildPaymentMethodSelector(),
                const SizedBox(height: 24),
                
                // Totals
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(
                      _formatCurrency(_subtotal),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isProcessing ? null : _handleCheckout,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isProcessing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Complete Purchase', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(SelectedProduct item, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${_formatCurrency(item.product.price)} each', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: () {
                  setState(() {
                    if (item.quantity > 1) {
                      item.quantity--;
                    } else {
                      _selectedProducts.removeAt(index);
                    }
                  });
                },
              ),
              Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: () {
                  setState(() => item.quantity++);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PAYMENT METHOD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildMethodCard('Cash', Icons.payments_outlined),
            const SizedBox(width: 12),
            _buildMethodCard('Transfer', Icons.account_balance_outlined),
          ],
        ),
      ],
    );
  }

  Widget _buildMethodCard(String method, IconData icon) {
    final isSelected = _paymentMethod == method;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = method),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.3) : Colors.transparent,
            border: Border.all(
              color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(method, style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              )),
            ],
          ),
        ),
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
        actionLabel: 'Add to Cart',
      ),
    );

    if (result != null) {
      setState(() {
        _selectedProducts.clear();
        _selectedProducts.addAll(result);
      });
    }
  }
}
