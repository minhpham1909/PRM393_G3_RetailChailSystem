import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/product_model.dart';
import '../../../core/models/store_model.dart';
import '../../../core/services/firestore_service.dart';
import '../widgets/admin_app_bar.dart';

class _ProductPerf {
  int soldQty = 0;
  double revenue = 0;
  DateTime? lastSoldAt;
}

DateTime? _parseOrderDate(Map<String, dynamic> data) {
  final dynamic createdAt = data['created_at'] ?? data['order_date'];
  if (createdAt is Timestamp) return createdAt.toDate();
  if (createdAt is String) return DateTime.tryParse(createdAt);
  return null;
}

bool _isPaidOrder(Map<String, dynamic> data) {
  final status = (data['status'] ?? '').toString().toLowerCase();
  // POS uses "paid"; seeded mock uses "completed".
  return status == 'paid' || status == 'completed';
}

class StoreProductPerformanceScreen extends StatefulWidget {
  const StoreProductPerformanceScreen({super.key});

  @override
  State<StoreProductPerformanceScreen> createState() =>
      _StoreProductPerformanceScreenState();
}

class _StoreProductPerformanceScreenState
    extends State<StoreProductPerformanceScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  String? _selectedStoreId;
  String _search = '';

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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const AdminAppBar(),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.db.collection('stores').snapshots(),
        builder: (context, storesSnap) {
          if (storesSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (storesSnap.hasError) {
            return Center(child: Text('Failed to load stores: ${storesSnap.error}'));
          }

          final stores = (storesSnap.data?.docs ?? [])
              .map((d) => StoreModel.fromFirestore(d))
              .toList();
          stores.sort((a, b) => a.name.compareTo(b.name));
          
          stores.insert(0, StoreModel(
            storeId: 'ALL',
            name: 'All Stores',
            address: '',
          ));

          if (stores.isEmpty) {
            return const Center(child: Text('No stores found in the system'));
          }

          final effectiveStoreId = _selectedStoreId ?? stores.first.storeId;

          return StreamBuilder<QuerySnapshot>(
            stream: _firestoreService.db.collection('products').snapshots(),
            builder: (context, productsSnap) {
              if (productsSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (productsSnap.hasError) {
                return Center(
                  child: Text('Failed to load products: ${productsSnap.error}'),
                );
              }

              final products = (productsSnap.data?.docs ?? [])
                  .map((d) => ProductModel.fromFirestore(d))
                  .toList();
              products.sort((a, b) => a.name.compareTo(b.name));

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: effectiveStoreId == 'ALL'
                    ? _firestoreService.db.collection('orders').snapshots()
                    : _firestoreService.db
                        .collection('orders')
                        .where('store_id', isEqualTo: effectiveStoreId)
                        .snapshots(),
                builder: (context, ordersSnap) {
                  if (ordersSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (ordersSnap.hasError) {
                    return Center(
                      child: Text('Failed to load orders: ${ordersSnap.error}'),
                    );
                  }

                  final orders = ordersSnap.data?.docs ?? [];
                  final perfByProductId = <String, _ProductPerf>{};

                  for (final doc in orders) {
                    final data = doc.data();
                    if (!_isPaidOrder(data)) continue;

                    final orderDate = _parseOrderDate(data) ?? DateTime.now();
                    final items = data['items'];
                    if (items is! List) continue;

                    for (final rawItem in items) {
                      if (rawItem is! Map) continue;
                      final item = rawItem.cast<String, dynamic>();

                      final dynamic rawProductId =
                          item['product_id'] ?? item['product_sku'] ?? item['sku'];
                      final productId = (rawProductId ?? '').toString();
                      if (productId.isEmpty) continue;

                        final quantityData = item['quantity'];
                        final int qty = quantityData is num
                          ? quantityData.toInt()
                          : int.tryParse((quantityData ?? '').toString()) ?? 0;

                        final unitPriceData = item['unit_price'];
                        final double unitPrice = unitPriceData is num
                          ? unitPriceData.toDouble()
                          : double.tryParse((unitPriceData ?? '').toString()) ??
                            0;

                      final perf = perfByProductId.putIfAbsent(
                        productId,
                        () => _ProductPerf(),
                      );
                      perf.soldQty += qty;
                      perf.revenue += qty * unitPrice;
                      if (perf.lastSoldAt == null ||
                          orderDate.isAfter(perf.lastSoldAt!)) {
                        perf.lastSoldAt = orderDate;
                      }
                    }
                  }

                  final normalizedSearch = _search.trim().toLowerCase();
                  final rows = products.where((p) {
                    if (normalizedSearch.isEmpty) return true;
                    return p.name.toLowerCase().contains(normalizedSearch) ||
                        p.sku.toLowerCase().contains(normalizedSearch);
                  }).toList();

                  rows.sort((a, b) {
                    final aSold = perfByProductId[a.productId]?.soldQty ?? 0;
                    final bSold = perfByProductId[b.productId]?.soldQty ?? 0;
                    final bySold = bSold.compareTo(aSold);
                    if (bySold != 0) return bySold;
                    return a.name.compareTo(b.name);
                  });

                  final totalSkus = products.length;
                  final sellingSkus = products
                      .where((p) => (perfByProductId[p.productId]?.soldQty ?? 0) > 0)
                      .length;
                  final noSalesSkus = totalSkus - sellingSkus;
                  final totalRevenue = perfByProductId.values.fold<double>(
                    0,
                    (sum, p) => sum + p.revenue,
                  );

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStorePicker(context, stores, effectiveStoreId),
                        const SizedBox(height: 12),
                        _buildSummaryRow(
                          context,
                          totalSkus: totalSkus,
                          sellingSkus: sellingSkus,
                          noSalesSkus: noSalesSkus,
                          totalRevenue: totalRevenue,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          onChanged: (v) => setState(() => _search = v),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Search by SKU or name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'PRODUCTS (${rows.length})',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            final product = rows[index];
                            final perf = perfByProductId[product.productId];
                            final soldQty = perf?.soldQty ?? 0;
                            final revenue = perf?.revenue ?? 0;
                            final lastSoldAt = perf?.lastSoldAt;

                            final isRunning = soldQty > 0;
                            final badgeBg = isRunning
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHigh;
                            final badgeFg = isRunning
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurfaceVariant;

                            final lastSoldStr = lastSoldAt == null
                                ? 'Never sold'
                                : DateFormat('dd/MM/yyyy').format(lastSoldAt);

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: product.image != null && product.image!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.network(
                                            product.image!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                Icon(Icons.inventory_2_outlined, color: colorScheme.onSurfaceVariant),
                                          ),
                                        )
                                      : Icon(
                                          Icons.inventory_2_outlined,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                ),
                                title: Text(
                                  product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  'SKU: ${product.sku} • ${product.category}\nLast sold: $lastSoldStr',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                isThreeLine: true,
                                trailing: SizedBox(
                                  height: 48,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
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
                                            isRunning ? 'RUNNING' : 'NO SALES',
                                            style: TextStyle(
                                              fontSize: 9,
                                              height: 1.0,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.6,
                                              color: badgeFg,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Qty: $soldQty • ${_formatCurrency(revenue)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            height: 1.0,
                                            fontWeight: FontWeight.w700,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStorePicker(
    BuildContext context,
    List<StoreModel> stores,
    String effectiveStoreId,
  ) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<String>(
          key: ValueKey(effectiveStoreId),
          initialValue: effectiveStoreId,
          items: stores
              .map(
                (s) => DropdownMenuItem(
                  value: s.storeId,
                  child: Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _selectedStoreId = v;
            });
          },
          decoration: const InputDecoration(
            labelText: 'Select store',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required int totalSkus,
    required int sellingSkus,
    required int noSalesSkus,
    required double totalRevenue,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget card({required String label, required String value}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 520;
        if (isWide) {
          return Row(
            children: [
              card(label: 'TOTAL SKUs', value: '$totalSkus'),
              const SizedBox(width: 10),
              card(label: 'RUNNING', value: '$sellingSkus'),
              const SizedBox(width: 10),
              card(label: 'NO SALES', value: '$noSalesSkus'),
              const SizedBox(width: 10),
              card(label: 'REVENUE', value: _formatCurrency(totalRevenue)),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                card(label: 'TOTAL SKUs', value: '$totalSkus'),
                const SizedBox(width: 10),
                card(label: 'RUNNING', value: '$sellingSkus'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                card(label: 'NO SALES', value: '$noSalesSkus'),
                const SizedBox(width: 10),
                card(label: 'REVENUE', value: _formatCurrency(totalRevenue)),
              ],
            ),
          ],
        );
      },
    );
  }
}
