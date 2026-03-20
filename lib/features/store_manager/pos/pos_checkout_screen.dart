import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/product_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/services/printing_service.dart';
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

  StreamSubscription? _userSubscription;

  // Profile info for order
  String? _managerId;
  String? _storeId;

  @override
  void initState() {
    super.initState();
    _listenToProfileInfo();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  /// Lắng nghe thông tin của người dùng đang đăng nhập để lấy managerId và storeId
  /// Dữ liệu sẽ tự động cập nhật nếu có thay đổi trên server.
  void _listenToProfileInfo() {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('Lỗi POS: Không có người dùng nào được xác thực.');
        // Có thể hiển thị lỗi cho người dùng ở đây nếu cần
        return;
      }

      // Lắng nghe user document bằng email thay vì UID, để tương thích với mock data seeder.
      // Seeder hiện tại tạo Auth user với UID tự động, nhưng Firestore doc lại dùng ID tùy chỉnh.
      _userSubscription = _firestoreService.db
          .collection('users')
          .where('email', isEqualTo: currentUser.email)
          .limit(1)
          .snapshots()
          .listen((querySnapshot) {
        if (querySnapshot.docs.isNotEmpty) {
          final userDoc = querySnapshot.docs.first;
          final userData = userDoc.data() as Map<String, dynamic>?;
          if (mounted && userData != null && userData['role'] == 'store_manager') {
            // Chỉ cập nhật state nếu dữ liệu thực sự thay đổi
            if (_managerId != userDoc.id || _storeId != userData['store_id']) {
              setState(() {
                _managerId = userDoc.id;
                _storeId = userData['store_id'];
              });
            }
          }
        } else {
          // Xử lý trường hợp không tìm thấy user doc
          debugPrint('Lỗi POS: Không tìm thấy thông tin người dùng trong Firestore.');
          if (mounted) setState(() { _managerId = null; _storeId = null; });
        }
      }, onError: (e) {
        debugPrint('Lỗi lắng nghe thông tin quản lý cho POS: $e');
        if (mounted) setState(() { _managerId = null; _storeId = null; });
      });
    } catch (e) {
      debugPrint('Lỗi thiết lập lắng nghe thông tin quản lý: $e');
    }
  }
  double get _total => _selectedProducts.fold(0.0, (sum, p) => sum + (p.product.price * p.quantity));

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

      late OrderModel createdOrder;
      
      // Lấy thông tin chi tiết sản phẩm để dùng sau khi thanh toán thành công
      // Điều này đảm bảo chúng ta có thông tin chính xác tại thời điểm thanh toán
      final productDetailsForReceipt = {
        for (var p in _selectedProducts) p.product.productId: p.product
      };

      // Run Transaction to ensure stock is updated atomically
      await _firestoreService.db.runTransaction((transaction) async {
        // 1. Đọc và kiểm tra tồn kho cho từng sản phẩm một cách tuần tự.
        // Việc này kém hiệu quả hơn so với đọc song song (Future.wait),
        // nhưng nó giúp tránh các lỗi tiềm ẩn trong các phiên bản cũ của plugin Firestore
        // khi xử lý nhiều thao tác đọc đồng thời trong một giao dịch.
        for (final sp in _selectedProducts) {
          final productRef = _firestoreService.db.collection('products').doc(sp.product.productId);
          final productDoc = await transaction.get(productRef);

          if (!productDoc.exists) {
            throw Exception('Sản phẩm ${sp.product.name} không tồn tại');
          }

          final stockData = productDoc.data()?['stock'];
          int currentStock = 0;
          if (stockData is num) {
            currentStock = stockData.toInt();
          }
          
          if (currentStock < sp.quantity) {
            throw Exception('Sản phẩm ${sp.product.name} không đủ tồn kho (Còn: $currentStock)');
          }
        }

        // 2. Nếu tất cả kiểm tra đều qua, giảm số lượng tồn kho cho tất cả sản phẩm
        for (var sp in _selectedProducts) {
          final productRef = _firestoreService.db.collection('products').doc(sp.product.productId);
          transaction.update(productRef, {
            'stock': FieldValue.increment(-sp.quantity),
          });
        }

        // 3. Tạo tài liệu Order
        final orderItems = _selectedProducts.map((sp) => OrderDetailModel(
          orderId: orderRef.id,
          productId: sp.product.productId,
          quantity: sp.quantity,
          unitPrice: sp.product.price,
        )).toList();

        final order = OrderModel(
          orderId: orderRef.id,
          managerId: _managerId!,
          storeId: _storeId!,
          totalAmount: _total,
          paymentMethod: _paymentMethod,
          createdAt: now,
          orderType: 'sale',
          status: 'paid',
          items: orderItems,
        );

        createdOrder = order;
        transaction.set(orderRef, order.toFirestore());
      });

      if (mounted) {
        await _showSuccessDialog(createdOrder, productDetailsForReceipt);
        setState(() {
          _selectedProducts.clear();
        });
      }
    } catch (e, s) {
      if (mounted) {
        // In lỗi chi tiết ra console để debug
        debugPrint('Lỗi thanh toán: $e');
        debugPrint('Stack trace: $s');

        // Tạo thông báo lỗi thân thiện với người dùng
        String errorMessage = e.toString();
        if (e is FirebaseException) {
          errorMessage = e.message ?? 'Lỗi không xác định từ Firebase.';
        } else if (e is Exception) {
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi thanh toán: $errorMessage'),
          backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showSuccessDialog(
      OrderModel order, Map<String, ProductModel> productDetails) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Thanh toán thành công!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text('Đơn hàng đã được ghi nhận và kho đã được cập nhật.',
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              PrintingService().printReceipt(
                order: order,
                productDetails: productDetails,
              );
            },
            child: const Text('In hóa đơn'),
          ),
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
                      _formatCurrency(_total),
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
                Text('${_formatCurrency(item.product.price)} ', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
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
                  setState(() {
                    // Kiểm tra số lượng tồn kho trước khi tăng
                    if (item.quantity + 1 <= item.product.stock) {
                      item.quantity++;
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sản phẩm ${item.product.name} chỉ còn ${item.product.stock} sản phẩm.')));
                    }
                  });
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
    final result = await showDialog<List<SelectedProduct>>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.all(20), // Thêm khoảng cách từ các cạnh màn hình
          child: ConstrainedBox( // Giới hạn chiều cao của nội dung dialog
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            child: ProductSelectionModal(
              initialSelected: _selectedProducts,
              actionLabel: 'Add to Cart',
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedProducts.clear();
        _selectedProducts.addAll(result);
      });
    }
  }
}
