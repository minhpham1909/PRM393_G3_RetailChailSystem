import 'package:flutter/material.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/firestore_service.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, ProductModel> _productCache = {};
  bool _isLoadingProducts = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final snapshot = await _firestoreService.db.collection('products').get();
      final products = snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();
      
      if (mounted) {
        setState(() {
          _productCache = {for (var p in products) p.productId: p};
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading products for order detail: $e');
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} VND';
  }

  @override
  Widget build(BuildContext context) {
    final order = ModalRoute.of(context)!.settings.arguments as OrderModel;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Invoice #${order.orderId.substring(order.orderId.length - 6).toUpperCase()}'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Order Header
          _buildOrderHeader(context, order),
          
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              children: [
                Text('ORDER ITEMS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ],
            ),
          ),

          // Items List
          Expanded(
            child: _isLoadingProducts 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: order.items.length,
                  itemBuilder: (context, index) {
                    final item = order.items[index];
                    final product = _productCache[item.productId];
                    return _buildOrderItem(context, item, product);
                  },
                ),
          ),

          // Summary Footer
          _buildTotalFooter(context, order),
        ],
      ),
    );
  }

  Widget _buildOrderHeader(BuildContext context, OrderModel order) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderInfo('Date', '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}'),
              _buildHeaderInfo('Time', '${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderInfo('Payment', order.paymentMethod),
              _buildHeaderInfo('Status', order.status.toUpperCase(), isStatus: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(String label, String value, {bool isStatus = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant.withOpacity(0.7), fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isStatus ? Colors.green : colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItem(BuildContext context, OrderDetailModel item, ProductModel? product) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: product?.image != null && product!.image!.isNotEmpty
                ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(product.image!, fit: BoxFit.cover),
                )
                : const Icon(Icons.inventory_2_outlined, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product?.name ?? 'Unknown Product',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  '${_formatCurrency(item.unitPrice)} x ${item.quantity}',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(item.lineTotal),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalFooter(BuildContext context, OrderModel order) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              _formatCurrency(order.totalAmount),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
