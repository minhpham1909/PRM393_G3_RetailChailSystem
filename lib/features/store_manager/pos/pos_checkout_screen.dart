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

  /// Listen to the current signed-in user profile to get managerId and storeId.
  /// Data updates automatically if server-side changes occur.
  void _listenToProfileInfo() {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('POS error: No authenticated user.');
        // You can show a user-facing error here if needed.
        return;
      }

      // Listen to the user document by email (not UID) for mock-data seeder compatibility.
      // Seeder creates Auth users with auto UIDs, but Firestore docs use custom IDs.
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
            // Update state only when data actually changes.
            if (_managerId != userDoc.id || _storeId != userData['store_id']) {
              setState(() {
                _managerId = userDoc.id;
                _storeId = userData['store_id'];
              });
            }
          }
        } else {
          // User doc not found.
          debugPrint('POS error: User profile not found in Firestore.');
          if (mounted) setState(() { _managerId = null; _storeId = null; });
        }
      }, onError: (e) {
        debugPrint('POS error listening to manager profile: $e');
        if (mounted) setState(() { _managerId = null; _storeId = null; });
      });
    } catch (e) {
      debugPrint('POS error setting up profile listener: $e');
    }
  }
  double get _total => _selectedProducts.fold(0.0, (sum, p) => sum + (p.product.price * p.quantity));

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VND';
  }

  Future<void> _handleCheckout() async {
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select items before checkout')),
      );
      return;
    }

    if (_storeId == null || _managerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Store information not found')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final now = DateTime.now();
      final orderRef = _firestoreService.db.collection('orders').doc();

      late OrderModel createdOrder;
      
      // Keep product details for receipt after a successful checkout.
      // This ensures we have consistent info at the time of checkout.
      final productDetailsForReceipt = {
        for (var p in _selectedProducts) p.product.productId: p.product
      };

      // Pre-fetch inventory doc IDs for the selected SKUs in this store
      final inventorySnap = await _firestoreService.db
          .collection('inventory')
          .where('store_id', isEqualTo: _storeId)
          .where('product_sku', whereIn: _selectedProducts.map((p) => p.product.sku).toSet().toList())
          .get();
      
      final Map<String, DocumentReference> skuToInventoryRef = {
        for (var doc in inventorySnap.docs) doc.data()['product_sku']: doc.reference
      };

      // Run Transaction to ensure stock is updated atomically
      await _firestoreService.db.runTransaction((transaction) async {
        // 1. Read and validate stock
        for (final sp in _selectedProducts) {
          final inventoryRef = skuToInventoryRef[sp.product.sku];
          if (inventoryRef == null) {
            throw Exception('Branch inventory record not found for ${sp.product.name} (${sp.product.sku})');
          }

          final inventoryDoc = await transaction.get(inventoryRef);
          if (!inventoryDoc.exists) {
            throw Exception('Stock record missing for ${sp.product.name}');
          }

          final inventoryData = inventoryDoc.data() as Map<String, dynamic>?;
          final stock = (inventoryData?['stock'] ?? 0) as num;
          if (stock < sp.quantity) {
            throw Exception('Not enough branch stock for ${sp.product.name} (Available: $stock)');
          }
          
          // Fallback check on products collection if needed
          final productRef = _firestoreService.db.collection('products').doc(sp.product.productId);
          final productDoc = await transaction.get(productRef);
          if (productDoc.exists) {
            final globalStock = (productDoc.data()?['stock'] ?? 0) as num;
            if (globalStock < sp.quantity) {
              // Just a safety check
            }
          }
        }

        // 2. Decrement stock for all items
        for (var sp in _selectedProducts) {
          final inventoryRef = skuToInventoryRef[sp.product.sku]!;
          transaction.update(inventoryRef, {
            'stock': FieldValue.increment(-sp.quantity),
          });

          // Also update global products collection to keep it in sync for now
          final productRef = _firestoreService.db.collection('products').doc(sp.product.productId);
          transaction.update(productRef, {
            'stock': FieldValue.increment(-sp.quantity),
          });
        }

        // 3. Create the order document.
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
        // Log details for debugging.
        debugPrint('Checkout error: $e');
        debugPrint('Stack trace: $s');

        // Create a user-friendly message.
        String errorMessage = e.toString();
        if (e is FirebaseException) {
          errorMessage = e.message ?? 'Unknown Firebase error.';
        } else if (e is Exception) {
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Checkout failed: $errorMessage'),
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
        title: const Text('Payment successful!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text('The order has been recorded and inventory has been updated.',
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
            child: const Text('Print receipt'),
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
                        Text('Cart is empty', style: TextStyle(color: colorScheme.onSurfaceVariant)),
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
                    // Check stock before increasing quantity.
                    if (item.quantity + 1 <= item.product.stock) {
                      item.quantity++;
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${item.product.name} has only ${item.product.stock} units left.')),
                      );
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
          insetPadding: const EdgeInsets.all(20), // Add padding from screen edges.
          child: ConstrainedBox( // Constrain dialog content height.
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            child: ProductSelectionModal(
              initialSelected: _selectedProducts,
              actionLabel: 'Add to Cart',
              storeId: _storeId,
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
