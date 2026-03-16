import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firestore_service.dart';

/// Màn hình Dashboard của Store Manager
/// Hiển thị: thông tin manager, doanh thu hôm nay, đơn hàng, nhân viên
/// Thiết kế theo stitch template: manager_profile
import '../widgets/manager_app_bar.dart';

class ManagerDashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const ManagerDashboardScreen({super.key, required this.onNavigate});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  // Dữ liệu thống kê
  double _todayRevenue = 0;
  int _totalOrders = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  /// Tải dữ liệu thống kê cho dashboard
  Future<void> _loadDashboardData() async {
    try {
      // Lấy tổng doanh thu hôm nay từ collection 'orders'
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final ordersSnapshot =
          await _firestoreService.db
              .collection('orders')
              .where(
                'created_at',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .where('status', isEqualTo: 'paid')
              .get();

      double revenue = 0;
      for (var doc in ordersSnapshot.docs) {
        revenue += (doc.data()['total_amount'] ?? 0).toDouble();
      }

      if (mounted) {
        setState(() {
          _todayRevenue = revenue;
          _totalOrders = ordersSnapshot.docs.length;
        });
      }
    } catch (e) {
      debugPrint('Lỗi tải dữ liệu dashboard: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const ManagerAppBar(title: 'Dashboard'),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== THẺ DOANH THU HÔM NAY =====
              _buildRevenueCard(context),
              const SizedBox(height: 16),

              // ===== HÀNG THỐNG KÊ: Đơn hàng + Nhân viên =====
              _buildStatsRow(context),
              const SizedBox(height: 32),

              // ===== ĐIỀU KHIỂN QUẢN LÝ =====
              _buildManagementControls(context),
              const SizedBox(height: 24),

              // ===== THÔNG BÁO CUỐI NGÀY =====
              _buildEndOfDayBanner(context),
            ],
          ),
        ),
      ),
    );
  }



  /// Thẻ doanh thu hôm nay — theo stitch: gradient xanh lá, số lớn
  Widget _buildRevenueCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TODAY'S REVENUE",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: colorScheme.onPrimary.withValues(alpha: 0.8),
                ),
              ),
              Icon(Icons.trending_up, color: colorScheme.onPrimary, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          // Số tiền lớn
          Text(
            '\$${_todayRevenue.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: colorScheme.onPrimary,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  /// Hàng thống kê: Đơn hàng và Nhân viên hoạt động
  Widget _buildStatsRow(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TODAY\'S ORDERS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_totalOrders',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          // Thanh tiến trình
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _totalOrders > 0 ? (_totalOrders / 100).clamp(0, 1) : 0,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: colorScheme.primary,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  /// Danh sách điều khiển quản lý — theo stitch: management controls nav
  Widget _buildManagementControls(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MANAGEMENT CONTROLS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        // Mục 1: Quản lý tồn kho
        _buildControlItem(
          context,
          icon: Icons.inventory_2_outlined,
          title: 'Inventory Management',
          subtitle: 'Restock levels & supplier status',
          onTap: () {
            // Chuyển sang tab Inventory (index 1)
            widget.onNavigate(1);
          },
        ),
        const SizedBox(height: 8),
        // Removed Staff Roster completely
        // Mục 3: Hiệu suất chi nhánh
        _buildControlItem(
          context,
          icon: Icons.assessment_outlined,
          title: 'Branch Performance',
          subtitle: 'Detailed sales analytics',
          onTap: () => widget.onNavigate(2), // Navigate to Reports
        ),
      ],
    );
  }

  /// Widget một mục trong danh sách điều khiển
  Widget _buildControlItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Icon tròn
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 14),
            // Tiêu đề và mô tả
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Mũi tên
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Banner thông báo cuối ngày — theo stitch: End of Day Report
  Widget _buildEndOfDayBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'End of Day Report',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start preparing the reconciliation report.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Nút bắt đầu
          FilledButton.tonal(
            onPressed: () {},
            child: const Text('Start Report'),
          ),
        ],
      ),
    );
  }
}

