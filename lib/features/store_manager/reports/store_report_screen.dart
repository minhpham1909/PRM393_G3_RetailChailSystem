import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/order_model.dart';
import '../widgets/manager_app_bar.dart';
import '../../../core/constants/app_routes.dart'; // Added this import

/// Màn hình Báo cáo Chi nhánh (Store Report)
/// Hiển thị doanh thu thực tế, lọc theo ngày/tháng, và danh sách hóa đơn
class StoreReportScreen extends StatefulWidget {
  const StoreReportScreen({super.key});

  @override
  State<StoreReportScreen> createState() => _StoreReportScreenState();
}

class _StoreReportScreenState extends State<StoreReportScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  // Filter state
  DateTime _selectedDate = DateTime.now();
  String _filterMode = 'Day'; // 'Day' hoặc 'Month'

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} VND';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    DateTime start;
    DateTime end;

    if (_filterMode == 'Day') {
      start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      end = start.add(const Duration(days: 1));
    } else {
      start = DateTime(_selectedDate.year, _selectedDate.month, 1);
      end = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const ManagerAppBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.db
            .collection('orders')
            .where('status', isEqualTo: 'paid')
            .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('created_at', isLessThan: Timestamp.fromDate(end))
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Kiểm tra lỗi index
            if (snapshot.error.toString().contains('requires an index')) {
                return Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                                const SizedBox(height: 16),
                                const Text(
                                    'The query requires a composite index.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                    snapshot.error.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                ),
                            ],
                        ),
                    ),
                );
            }
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final invoices = snapshot.data!.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
          final totalRevenue = invoices.fold(0.0, (sum, order) => sum + order.totalAmount);

          return Column(
            children: [
              // Filter Section
              _buildFilterSection(context),
              
              // Summary Header
              _buildSummaryHeader(context, totalRevenue, invoices.length),

              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Text('RECENT INVOICES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ],
                ),
              ),

              // Invoices List
              Expanded(
                child: invoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: colorScheme.surfaceContainerHighest),
                            const SizedBox(height: 16),
                            Text('No invoices found', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: invoices.length,
                        itemBuilder: (context, index) {
                          final order = invoices[index];
                          return InkWell(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.orderDetail,
                                arguments: order,
                              );
                            },
                            child: _buildInvoiceItem(order),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Day', label: Text('Day'), icon: Icon(Icons.today)),
                    ButtonSegment(value: 'Month', label: Text('Month'), icon: Icon(Icons.calendar_month)),
                  ],
                  selected: {_filterMode},
                  onSelectionChanged: (val) {
                    setState(() => _filterMode = val.first);
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: _selectDate,
                icon: const Icon(Icons.event),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _filterMode == 'Day'
                ? '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'
                : 'Month ${_selectedDate.month}/${_selectedDate.year}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context, double totalRevenue, int orderCount) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TOTAL REVENUE",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: colorScheme.onPrimary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatCurrency(totalRevenue),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onPrimary,
                  letterSpacing: -1,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.trending_up, color: colorScheme.onPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$orderCount Orders Successful',
            style: TextStyle(color: colorScheme.onPrimary.withValues(alpha: 0.7), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItem(OrderModel order) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              order.paymentMethod == 'Cash' ? Icons.payments_outlined : Icons.account_balance_outlined,
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice #${order.orderId.substring(order.orderId.length - 6).toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  '${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')} - ${order.paymentMethod}',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(order.totalAmount),
                style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 16),
              ),
              const Text(
                'Paid',
                style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
