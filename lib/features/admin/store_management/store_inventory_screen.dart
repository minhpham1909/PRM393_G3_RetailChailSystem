import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/store_model.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/excel_export_service.dart';

class StoreInventoryScreen extends StatefulWidget {
  final StoreModel store;

  const StoreInventoryScreen({super.key, required this.store});

  @override
  State<StoreInventoryScreen> createState() => _StoreInventoryScreenState();
}

class _StoreInventoryScreenState extends State<StoreInventoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ExcelExportService _excelService = ExcelExportService();
  
  Map<String, ProductModel> _productMap = {};
  bool _isLoadingProducts = true;
  bool _isExporting = false;
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

  Future<void> _exportToExcel(List<QueryDocumentSnapshot<Map<String, dynamic>>> items) async {
    setState(() => _isExporting = true);
    try {
      final exportData = items.map((doc) {
        final data = doc.data();
        final sku = data['product_sku'] ?? 'N/A';
        final product = _productMap[sku];
        
        return {
          'sku': sku,
          'name': product?.name ?? 'Unknown',
          'category': product?.category ?? 'N/A',
          'stock': data['stock'] ?? 0,
          'price': product?.price ?? 0.0,
        };
      }).toList();

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Inventory_${_currentStore.name.replaceAll(' ', '_')}_$timestamp';

      await _excelService.exportInventoryToExcel(
        data: exportData,
        fileName: fileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Inventory exported: $fileName.xlsx')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
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
                  await _firestoreService.db.collection('users').doc(selectedManagerId).update({
                    'store_id': _currentStore.storeId,
                  });
                  if (oldManagerId.isNotEmpty) {
                    try {
                      await _firestoreService.db.collection('users').doc(oldManagerId).update({
                        'store_id': '',
                      });
                    } catch (e) { /* ignore */ }
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

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestoreService.db
          .collection('inventory')
          .where('store_id', isEqualTo: _currentStore.storeId)
          .snapshots(),
      builder: (context, snapshot) {
        final hasData = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        final items = snapshot.data?.docs ?? [];

        return Scaffold(
          backgroundColor: colorScheme.surfaceContainerLowest,
          appBar: AppBar(
            title: const Text('Store Details'),
            backgroundColor: colorScheme.surfaceContainerLowest,
            scrolledUnderElevation: 0,
            actions: [
              if (hasData)
                IconButton(
                  onPressed: _isExporting ? null : () => _exportToExcel(items),
                  icon: _isExporting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_rounded),
                  tooltip: 'Export Inventory',
                ),
              const SizedBox(width: 8),
            ],
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
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()))
              else if (snapshot.hasError)
                SliverToBoxAdapter(child: Center(child: Text('Error: ${snapshot.error}')))
              else if (items.isEmpty)
                SliverToBoxAdapter(
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
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                          color: theme.colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                                  child: product?.image != null && product!.image!.isNotEmpty
                                      ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(product.image!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined)))
                                      : const Icon(Icons.inventory_2_outlined),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(product?.name ?? 'Unknown Product', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text('SKU: $sku • ${product?.category ?? "N/A"}', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('$stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: stock < 5 ? Colors.red : colorScheme.primary)),
                                    Text('units', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
