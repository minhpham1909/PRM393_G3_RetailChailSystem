import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/order_model.dart';
import '../../../core/models/store_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/excel_export_service.dart';
import '../../store_manager/reports/order_detail_screen.dart';
import '../widgets/admin_app_bar.dart';

enum GroupBy { day, month }

class RevenueStatisticsScreen extends StatefulWidget {
  const RevenueStatisticsScreen({super.key});

  @override
  State<RevenueStatisticsScreen> createState() =>
      _RevenueStatisticsScreenState();
}

class _RevenueStatisticsScreenState extends State<RevenueStatisticsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ExcelExportService _excelService = ExcelExportService();

  String _selectedStoreId = 'ALL';
  GroupBy _groupBy = GroupBy.day;
  bool _isExporting = false;

  Future<void> _exportToExcel(
    List<MapEntry<String, _RevenueData>> sortedData,
    List<StoreModel> stores,
  ) async {
    setState(() => _isExporting = true);
    try {
      String? storeName;
      String? managerName;

      if (_selectedStoreId != 'ALL') {
        final store = stores.firstWhere((s) => s.storeId == _selectedStoreId);
        storeName = store.name;
        
        if (store.managerId.isNotEmpty) {
          final managerDoc = await _firestoreService.db.collection('users').doc(store.managerId).get();
          if (managerDoc.exists) {
            managerName = managerDoc.data()?['name'] ?? managerDoc.data()?['email'];
          }
        }
      }

      final exportData = sortedData.map((e) => {
        'period': e.key,
        'revenue': e.value.revenue,
        'count': e.value.orderCount,
        'storeName': _selectedStoreId == 'ALL' ? 'All Stores' : storeName,
      }).toList();

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Revenue_Report_${_selectedStoreId}_$timestamp';

      await _excelService.exportRevenueToExcel(
        data: exportData,
        fileName: fileName,
        storeName: storeName,
        managerName: managerName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel report saved: $fileName.xlsx')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'VND',
      decimalDigits: 0,
    ).format(amount);
  }

  DateTime? _parseOrderDate(Map<String, dynamic> data) {
    final dynamic createdAt = data['created_at'] ?? data['order_date'];
    if (createdAt is Timestamp) return createdAt.toDate();
    if (createdAt is String) return DateTime.tryParse(createdAt);
    return null;
  }

  bool _isPaidOrder(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    return status == 'paid' || status == 'completed';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestoreService.db.collection('stores').snapshots(),
      builder: (context, storesSnap) {
        if (storesSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            appBar: AdminAppBar(),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final stores = (storesSnap.data?.docs ?? [])
            .map((d) => StoreModel.fromFirestore(d))
            .toList();
        stores.sort((a, b) => a.name.compareTo(b.name));
        if (!stores.any((s) => s.storeId == 'ALL')) {
          stores.insert(0, StoreModel(
            storeId: 'ALL',
            name: 'All Stores',
            address: '',
          ));
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _selectedStoreId == 'ALL'
              ? _firestoreService.db.collection('orders').snapshots()
              : _firestoreService.db
                  .collection('orders')
                  .where('store_id', isEqualTo: _selectedStoreId)
                  .snapshots(),
          builder: (context, ordersSnap) {
            if (ordersSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                appBar: AdminAppBar(),
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final orders = ordersSnap.data?.docs ?? [];
            final Map<String, _RevenueData> groupedData = {};
            double totalRevenue = 0;
            int totalOrders = 0;

            for (final doc in orders) {
              final data = doc.data();
              if (!_isPaidOrder(data)) continue;
              final orderDate = _parseOrderDate(data);
              if (orderDate == null) continue;

              final double orderTotal = (data['total_amount'] ?? 0).toDouble();
              final String dateKey = _groupBy == GroupBy.day
                  ? DateFormat('dd/MM/yyyy').format(orderDate)
                  : DateFormat('MM/yyyy').format(orderDate);
              final String sortKey = _groupBy == GroupBy.day
                  ? DateFormat('yyyy-MM-dd').format(orderDate)
                  : DateFormat('yyyy-MM').format(orderDate);

              groupedData.putIfAbsent(dateKey, () => _RevenueData(sortKey: sortKey));
              final group = groupedData[dateKey]!;
              group.revenue += orderTotal;
              group.orderCount++;
              group.orders.add(OrderModel.fromFirestore(doc));
              totalRevenue += orderTotal;
              totalOrders++;
            }

            final List<MapEntry<String, _RevenueData>> sortedGroupedData =
                groupedData.entries.toList()
                  ..sort((a, b) => b.value.sortKey.compareTo(a.value.sortKey));

            return Scaffold(
              backgroundColor: colorScheme.surface,
              appBar: AdminAppBar(
                actions: [
                  IconButton(
                    onPressed: _isExporting 
                      ? null 
                      : () => _exportToExcel(sortedGroupedData, stores),
                    icon: _isExporting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_rounded),
                    tooltip: 'Export to Excel',
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedStoreId,
                              items: stores.map((s) => DropdownMenuItem(
                                value: s.storeId,
                                child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _selectedStoreId = v);
                              },
                              decoration: const InputDecoration(
                                labelText: 'Select Store',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SegmentedButton<GroupBy>(
                              segments: const [
                                ButtonSegment(value: GroupBy.day, label: Text('By Day'), icon: Icon(Icons.today)),
                                ButtonSegment(value: GroupBy.month, label: Text('By Month'), icon: Icon(Icons.calendar_month)),
                              ],
                              selected: {_groupBy},
                              onSelectionChanged: (Set<GroupBy> newSelection) {
                                setState(() => _groupBy = newSelection.first);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryCard(context, totalRevenue: totalRevenue, totalOrders: totalOrders),
                    const SizedBox(height: 16),
                    Text('PERIOD DETAILED', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    if (sortedGroupedData.isEmpty)
                      Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('No paid orders found', style: Theme.of(context).textTheme.bodyLarge)))
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedGroupedData.length,
                        itemBuilder: (context, index) {
                          final entry = sortedGroupedData[index];
                          final revenueStr = _formatCurrency(entry.value.revenue);

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                leading: Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(10)),
                                  child: Icon(_groupBy == GroupBy.day ? Icons.calendar_today_outlined : Icons.date_range_outlined, color: colorScheme.onSecondaryContainer),
                                ),
                                title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${entry.value.orderCount} order(s)'),
                                trailing: Text(
                                  revenueStr,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                children: [
                                  const Divider(height: 1),
                                  ...entry.value.orders.map((order) {
                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      leading: const Icon(Icons.receipt_outlined, size: 20),
                                      title: Text('Order ${order.orderId}'),
                                       subtitle: Text(DateFormat('HH:mm').format(order.createdAt)),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(_formatCurrency(order.totalAmount), style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                                          Text(
                                            order.status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: order.status.toLowerCase() == 'paid' || order.status.toLowerCase() == 'completed' ? Colors.green : Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OrderDetailScreen(order: order))),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required double totalRevenue,
    required int totalOrders,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              colorScheme.primary.withAlpha(220),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOTAL REVENUE',
              style: TextStyle(
                color: colorScheme.onPrimary,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatCurrency(totalRevenue),
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.onPrimary.withAlpha(28),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 16,
                    color: colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$totalOrders successful order(s)',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueData {
  final String sortKey;
  double revenue = 0;
  int orderCount = 0;
  final List<OrderModel> orders = [];

  _RevenueData({required this.sortKey});
}
