import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';

/// Store Manager dashboard screen.
/// Shows: manager info, today's revenue, orders.
/// Designed based on the stitch template: manager_profile
import '../widgets/manager_app_bar.dart';

class ManagerDashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const ManagerDashboardScreen({super.key, required this.onNavigate});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription? _userSubscription;
  StreamSubscription? _ordersSubscription;

  // Current manager store ID
  String? _storeId;

  // Summary data
  double _todayRevenue = 0;
  int _totalOrders = 0;

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VND';
  }

  @override
  void initState() {
    super.initState();
    _listenToProfileAndDashboardData();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _ordersSubscription?.cancel();
    super.dispose();
  }

  /// Listen to the user profile to get storeId, then listen to dashboard data.
  void _listenToProfileAndDashboardData() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Listen by email (not UID) for mock-data seeder compatibility.
    _userSubscription = _firestoreService.db
        .collection('users')
        .where('email', isEqualTo: currentUser.email)
        .limit(1)
        .snapshots()
        .listen((querySnapshot) {
          if (querySnapshot.docs.isEmpty || !mounted) return;

          final userDoc = querySnapshot.docs.first;
          final newStoreId = userDoc.data()['store_id'];

          // Re-subscribe to the dashboard stream only if storeId changes.
          if (newStoreId != null && newStoreId != _storeId) {
            _storeId = newStoreId;
            _listenToDashboardData(newStoreId);
          }
        });
  }

  /// Listen to today's orders to update the dashboard in real-time.
  void _listenToDashboardData(String storeId) {
    // Cancel the old subscription before creating a new one.
    _ordersSubscription?.cancel();

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final query = _firestoreService.db
        .collection('orders')
        .where('store_id', isEqualTo: storeId)
        .where(
          'created_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('status', isEqualTo: 'paid');

    _ordersSubscription = query.snapshots().listen(
      (snapshot) {
        if (!mounted) return;

        double revenue = 0;
        for (var doc in snapshot.docs) {
          revenue += (doc.data()['total_amount'] ?? 0).toDouble();
        }

        setState(() {
          _todayRevenue = revenue;
          _totalOrders = snapshot.docs.length;
        });
      },
      onError: (e) {
        debugPrint('Failed to load dashboard data: $e');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const ManagerAppBar(),
      body: RefreshIndicator(
        // Stream already updates automatically; onRefresh is just for UX.
        onRefresh: () async {},
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== TODAY'S REVENUE CARD =====
              _buildRevenueCard(context),
              const SizedBox(height: 16),

              // ===== STATS ROW =====
              _buildStatsRow(context),
              const SizedBox(height: 32),

              // ===== MANAGEMENT CONTROLS =====
              _buildManagementControls(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Today's revenue card.
  Widget _buildRevenueCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
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
          // Amount
          Text(
            _formatCurrency(_todayRevenue),
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

  /// Stats card for today's orders.
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
          // Progress bar
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

  /// Management controls list.
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
        // Inventory
        _buildControlItem(
          context,
          icon: Icons.inventory_2_outlined,
          title: 'Inventory Management',
          subtitle: 'Restock levels & supplier status',
          onTap: () {
            // Navigate to Inventory (tab index 1)
            widget.onNavigate(1);
          },
        ),
        const SizedBox(height: 8),
        // Removed Staff Roster completely
        // Branch performance
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

  /// Single control item widget.
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
            // Icon
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
            // Title & subtitle
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
            // Chevron
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
}
