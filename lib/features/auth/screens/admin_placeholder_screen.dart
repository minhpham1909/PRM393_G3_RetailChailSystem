import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/auth_service.dart';

/// Admin placeholder (temporary)
/// For testing: signing in as admin lands on this screen.
class AdminPlaceholderScreen extends StatelessWidget {
  const AdminPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Retail Management'),
        leading: IconButton(
          tooltip: 'Admin profile',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.adminProfile),
          icon: CircleAvatar(
            backgroundColor: colorScheme.primary.withAlpha(26),
            child: Icon(
              Icons.person,
              color: colorScheme.primary,
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value != 'logout') return;
              await authService.signOut();
              if (context.mounted) {
                Navigator.popUntil(context, (r) => r.isFirst);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'logout',
                child: Text('Sign out'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopKpiCard(context),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 520;
                final cardWidth = isWide
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _buildStatCard(
                        context,
                        icon: Icons.storefront,
                        iconBg: colorScheme.tertiaryContainer,
                        iconFg: colorScheme.onTertiaryContainer,
                        label: 'STORE MANAGERS',
                        valueStream: FirebaseFirestore.instance
                            .collection('users')
                            .where('role', isEqualTo: 'store_manager')
                            .snapshots(),
                        valueFormatter: (snap) => '${snap.size}',
                        subtitle: 'Active accounts',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildStatCard(
                        context,
                        icon: Icons.inventory_2,
                        iconBg: colorScheme.secondaryContainer,
                        iconFg: colorScheme.onSecondaryContainer,
                        label: 'TOTAL PRODUCTS',
                        valueStream: FirebaseFirestore.instance
                            .collection('products')
                            .snapshots(),
                        valueFormatter: (snap) => '${snap.size}',
                        subtitle: 'Master SKU data',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _buildSectionHeader(
              context,
              title: 'Quick Actions',
            ),
            const SizedBox(height: 10),
            _buildNavTile(
              context,
              icon: Icons.people_alt_outlined,
              title: 'User Management',
              subtitle: 'Control access levels',
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.accountManagement,
              ),
            ),
            const SizedBox(height: 10),
            _buildNavTile(
              context,
              icon: Icons.inventory_2_outlined,
              title: 'Product Master',
              subtitle: 'Global SKU control',
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.productManagement,
              ),
            ),
            const SizedBox(height: 10),
            _buildNavTile(
              context,
              icon: Icons.local_shipping_outlined,
              title: 'Central Warehouse',
              subtitle: 'Process store import requests',
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.importRequestManagement,
              ),
            ),
            const SizedBox(height: 10),
            _buildNavTile(
              context,
              icon: Icons.query_stats_outlined,
              title: 'Store Product Performance',
              subtitle: 'Track running vs no-sales SKUs',
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.storeProductPerformance,
              ),
            ),
            const SizedBox(height: 18),
            _buildSectionHeader(
              context,
              title: 'System Activity',
              trailing: TextButton(
                onPressed: () {},
                child: const Text('View all logs'),
              ),
            ),
            const SizedBox(height: 10),
            _buildActivityCard(
              context,
              items: const [
                _ActivityItem(
                  icon: Icons.verified_user_outlined,
                  title: 'New admin role assigned',
                  subtitle: '24 minutes ago • Security Log',
                ),
                _ActivityItem(
                  icon: Icons.price_change_outlined,
                  title: 'Global Price Update',
                  subtitle: '1 hour ago • Product Master',
                ),
                _ActivityItem(
                  icon: Icons.store_mall_directory_outlined,
                  title: 'Store #142 went online',
                  subtitle: '3 hours ago • Store Management',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildSectionHeader(
              context,
              title: 'System Health',
            ),
            const SizedBox(height: 10),
            _buildHealthCard(context),
            const SizedBox(height: 18),
            _buildUptimeCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopKpiCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('stock_requests').snapshots(),
      builder: (context, snapshot) {
        final totalRequests = snapshot.data?.size ?? 0;

        return Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: const EdgeInsets.all(18),
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
                  'TOTAL IMPORT REQUESTS',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$totalRequests',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 34,
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
                        Icons.trending_up,
                        size: 16,
                        color: colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Realtime from Firestore',
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
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    Widget? trailing,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String label,
    required Stream<QuerySnapshot<Map<String, dynamic>>> valueStream,
    required String Function(QuerySnapshot<Map<String, dynamic>> snap) valueFormatter,
    required String subtitle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconFg),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: valueStream,
              builder: (context, snapshot) {
                final value = snapshot.data == null ? '—' : valueFormatter(snapshot.data!);
                return Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(
    BuildContext context, {
    required List<_ActivityItem> items,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++)
            Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    child: Icon(items[i].icon, color: colorScheme.onSurfaceVariant),
                  ),
                  title: Text(
                    items[i].title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(items[i].subtitle),
                ),
                if (i != items.length - 1) const Divider(height: 0),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHealthCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget row({
      required String name,
      required String status,
      required Color dot,
      required Color statusColor,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              height: 8,
              width: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              status,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      child: Column(
        children: [
          row(
            name: 'Cloud Infrastructure',
            status: 'STABLE',
            dot: colorScheme.tertiary,
            statusColor: colorScheme.tertiary,
          ),
          const Divider(height: 0),
          row(
            name: 'Inventory Sync',
            status: 'SYNCED',
            dot: colorScheme.tertiary,
            statusColor: colorScheme.tertiary,
          ),
          const Divider(height: 0),
          row(
            name: 'Payment Gateway',
            status: 'LATENCY',
            dot: colorScheme.error,
            statusColor: colorScheme.error,
          ),
        ],
      ),
    );
  }

  Widget _buildUptimeCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(18),
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
              'SERVER UPTIME',
              style: TextStyle(
                color: colorScheme.onPrimary,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '99.98%',
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
