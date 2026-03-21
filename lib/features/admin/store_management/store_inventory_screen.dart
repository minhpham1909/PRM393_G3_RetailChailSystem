import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/store_model.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/services/firestore_service.dart';

class StoreInventoryScreen extends StatefulWidget {
  final StoreModel store;

  const StoreInventoryScreen({super.key, required this.store});

  @override
  State<StoreInventoryScreen> createState() => _StoreInventoryScreenState();
}

class _StoreInventoryScreenState extends State<StoreInventoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  
  Map<String, ProductModel> _productMap = {};
  bool _isLoadingProducts = true;
  late StoreModel _currentStore;

  @override
  void initState() {
    super.initState();
    _currentStore = widget.store;
    _loadProducts();
    _listenToStoreChanges();
  }

  void _listenToStoreChanges() {
    _firestoreService.db
        .collection('stores')
        .doc(_currentStore.storeId)
        .snapshots()
        .listen((docSnapshot) {
      if (docSnapshot.exists && mounted) {
        setState(() {
          _currentStore = StoreModel.fromFirestore(docSnapshot);
        });
      }
    });
  }

  Future<void> _loadProducts() async {
    try {
      final snapshot = await _firestoreService.getCollection('products');
      final Map<String, ProductModel> map = {};
      for (var doc in snapshot.docs) {
        final prod = ProductModel.fromFirestore(doc);
        map[prod.sku] = prod;
      }
      if (mounted) {
        setState(() {
          _productMap = map;
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  void _showEditStoreDialog() {
    final nameCtrl = TextEditingController(text: _currentStore.name);
    final addressCtrl = TextEditingController(text: _currentStore.address);
    final phoneCtrl = TextEditingController(text: _currentStore.phoneNum);
    String? selectedManagerId = _currentStore.managerId.isNotEmpty ? _currentStore.managerId : null;

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.storefront, color: colorScheme.primary, size: 40),
          title: const Text('Edit Store Info', style: TextStyle(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Store Name',
                      prefixIcon: const Icon(Icons.store_mall_directory),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: addressCtrl,
                    decoration: InputDecoration(
                      labelText: 'Address',
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _firestoreService.db
                        .collection('users')
                        .where('role', isEqualTo: 'store_manager')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final managers = snapshot.data!.docs;
                      // Ensure selectedManagerId exists in the list to prevent Dropdown crash
                      bool managerExists = selectedManagerId == null || managers.any((doc) => doc.id == selectedManagerId);
                      if (!managerExists) selectedManagerId = null;

                      return DropdownButtonFormField<String>(
                        value: selectedManagerId,
                        decoration: InputDecoration(
                          labelText: 'Assign Manager',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                        ),
                        items: managers.map((doc) {
                          final data = doc.data();
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text('${data['full_name']} (${doc.id})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          selectedManagerId = val;
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              onPressed: () async {
                if (nameCtrl.text.isEmpty || addressCtrl.text.isEmpty) return;

                final String oldManagerId = _currentStore.managerId;

                await _firestoreService.db.collection('stores').doc(_currentStore.storeId).update({
                  'name': nameCtrl.text,
                  'address': addressCtrl.text,
                  'store_phoneNum': phoneCtrl.text,
                  'manager_id': selectedManagerId ?? '',
                });

                if (selectedManagerId != null && selectedManagerId != oldManagerId) {
                  // Reassign new manager
                  await _firestoreService.db.collection('users').doc(selectedManagerId).update({
                    'store_id': _currentStore.storeId,
                  });
                  // Unassign old manager if exists
                  if (oldManagerId.isNotEmpty) {
                    try {
                      await _firestoreService.db.collection('users').doc(oldManagerId).update({
                        'store_id': '',
                      });
                    } catch (e) {
                      // ignore if old manager was deleted
                    }
                  }
                }

                if (context.mounted) Navigator.pop(context);
              },
              label: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStoreInfoCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _currentStore.name,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _showEditStoreDialog,
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit Store',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow(Icons.location_on_outlined, _currentStore.address, theme),
            const SizedBox(height: 12),
            _infoRow(Icons.phone_outlined, _currentStore.phoneNum.isNotEmpty ? _currentStore.phoneNum : 'No phone number provided', theme),
            const SizedBox(height: 12),
            _infoRow(Icons.badge_outlined, 'Manager ID: ${_currentStore.managerId.isNotEmpty ? _currentStore.managerId : 'Unassigned'}', theme),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoadingProducts) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(title: const Text('Loading Details...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Store Details'),
        backgroundColor: colorScheme.surfaceContainerLowest,
        scrolledUnderElevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildStoreInfoCard(theme),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                'Branch Inventory',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestoreService.db
                .collection('inventory')
                .where('store_id', isEqualTo: _currentStore.storeId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
              }

              if (snapshot.hasError) {
                return SliverToBoxAdapter(child: Center(child: Text('Error: ${snapshot.error}')));
              }

              final items = snapshot.data?.docs ?? [];

              if (items.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No stock items found for this specific store in the "inventory" collection.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final data = items[index].data();
                      final sku = data['product_sku'] ?? 'N/A';
                      final stock = data['stock'] ?? 0;
                      
                      final product = _productMap[sku];

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        color: colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Image
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: product != null && product.image != null && product.image!.isNotEmpty
                                    ? Image.network(
                                        product.image!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, stack) => Icon(Icons.broken_image, color: colorScheme.onSurfaceVariant),
                                      )
                                    : Icon(Icons.inventory_2, color: colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(width: 16),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product?.name ?? 'Unknown Product',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'SKU: $sku',
                                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: stock > 10
                                                ? Colors.green.withValues(alpha: 0.1)
                                                : Colors.orange.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '$stock in stock',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: stock > 10 ? Colors.green[700] : Colors.orange[800],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              );
            },
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }
}
