import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project_prm393/core/models/product_model.dart';
import 'package:project_prm393/core/services/firestore_service.dart';
import 'package:project_prm393/core/services/printing_service.dart';
import '../../../core/models/order_model.dart';

/// Invoice detail screen.
class OrderDetailScreen extends StatefulWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final PrintingService _printingService = PrintingService();
  Map<String, ProductModel> _productDetails = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProductDetails();
  }

  /// Load product details for items in this order.
  Future<void> _loadProductDetails() async {
    if (widget.order.items.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final productFutures = widget.order.items.map((item) {
        return _firestoreService.getDocument('products', item.productId);
      }).toList();

      final productDocs = await Future.wait(productFutures);

      final productMap = <String, ProductModel>{};
      for (var doc in productDocs) {
        if (doc.exists) {
          final product = ProductModel.fromFirestore(doc);
          productMap[product.productId] = product;
        }
      }

      if (mounted) {
        setState(() {
          _productDetails = productMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load product details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'VND',
      decimalDigits: 0,
    ).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: _isLoading
                ? null
                : () {
                    _printingService.printReceipt(
                      order: widget.order,
                      productDetails: _productDetails,
                    );
                  },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(colorScheme),
                  const SizedBox(height: 24),
                  Text(
                    'Items (${widget.order.items.length})',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildItemsList(colorScheme),
                  const Divider(height: 32),
                  _buildTotals(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Invoice #${widget.order.orderId.substring(widget.order.orderId.length - 6).toUpperCase()}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.order.status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.calendar_today_outlined,
            'Date',
            DateFormat('dd/MM/yyyy, HH:mm').format(widget.order.createdAt),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.payment_outlined,
            'Payment',
            widget.order.paymentMethod,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildItemsList(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.order.items.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: colorScheme.outlineVariant.withOpacity(0.2),
        ),
        itemBuilder: (context, index) {
          final item = widget.order.items[index];
          final product = _productDetails[item.productId];
          final productName = product?.name ?? 'Loading...';

          return ListTile(
            title: Text(
              productName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${item.quantity} x ${_formatCurrency(item.unitPrice)}',
            ),
            trailing: Text(
              _formatCurrency(item.lineTotal),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTotals() {
    return Column(
      children: [
        _buildTotalRow(
          'Total',
          _formatCurrency(widget.order.totalAmount),
          isTotal: true,
        ),
      ],
    );
  }

  Widget _buildTotalRow(String title, String value, {bool isTotal = false}) {
    final style = isTotal
        ? const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
        : const TextStyle(fontSize: 16);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: style.copyWith(
            color: isTotal
                ? null
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: style),
      ],
    );
  }
}
