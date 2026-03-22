import 'package:flutter/material.dart';
import 'dashboard/admin_dashboard_screen.dart';
import 'user_management/account_management_screen.dart';
import 'product_management/product_management_screen.dart';
import 'warehouse_management/import_request_management_screen.dart';
import 'reports/store_product_performance_screen.dart';
import 'reports/revenue_statistics_screen.dart';
import 'store_management/store_management_screen.dart';

/// Màn hình chính của Admin
/// Chứa Bottom Navigation Bar với 7 tab: Dashboard, MS, Products, Warehouse, Reports, Revenue Stats, Stores
/// Sử dụng IndexedStack để giữ trạng thái mỗi tab khi chuyển đổi
class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  /// Tab hiện tại đang được chọn
  int _currentIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      AdminDashboardScreen(
        onNavigate: (index) {
          setState(() => _currentIndex = index);
        },
      ),
      const AccountManagementScreen(),
      const ProductManagementScreen(),
      const ImportRequestManagementScreen(),
      const StoreProductPerformanceScreen(),
      const RevenueStatisticsScreen(),
      const StoreManagementScreen(),
    ];

    return Scaffold(
      // Sử dụng IndexedStack để giữ state khi chuyển tab
      body: IndexedStack(index: _currentIndex, children: screens),
      // Thanh điều hướng phía dưới
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          // Tab 0: Dashboard
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          // Tab 1: MS
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'MS',
          ),
          // Tab 2: Products
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          // Tab 3: Warehouse
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Warehouse',
          ),
          // Tab 4: Reports
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment),
            label: 'Reports',
          ),
          // Tab 5: Revenue Stats
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'Revenue',
          ),
          // Tab 6: Stores
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Stores',
          ),
        ],
      ),
    );
  }
}
