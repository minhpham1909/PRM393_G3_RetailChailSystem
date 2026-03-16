import 'package:flutter/material.dart';
import 'dashboard/manager_dashboard_screen.dart';
import 'inventory/inventory_management_screen.dart';
import 'team/account_management_screen.dart';
import 'reports/store_report_screen.dart';
import 'profile/manager_profile_screen.dart';

/// Màn hình chính của Store Manager
/// Chứa Bottom Navigation Bar với 5 tab: Dashboard, Inventory, Team, Reports, Profile
/// Sử dụng IndexedStack để giữ trạng thái mỗi tab khi chuyển đổi
class ManagerMainScreen extends StatefulWidget {
  const ManagerMainScreen({super.key});

  @override
  State<ManagerMainScreen> createState() => _ManagerMainScreenState();
}

class _ManagerMainScreenState extends State<ManagerMainScreen> {
  /// Tab hiện tại đang được chọn
  int _currentIndex = 0;



  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      ManagerDashboardScreen(
        onNavigate: (index) {
          setState(() => _currentIndex = index);
        },
      ),
      const InventoryManagementScreen(),
      const AccountManagementScreen(),
      const StoreReportScreen(),
      const ManagerProfileScreen(),
    ];

    return Scaffold(
      // Sử dụng IndexedStack để giữ state khi chuyển tab
      body: IndexedStack(index: _currentIndex, children: screens),
      // Thanh điều hướng phía dưới — theo stitch template
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          // Tab 1: Dashboard
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          // Tab 2: Inventory (Tồn kho)
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          // Tab 3: Team (Nhân sự)
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Team',
          ),
          // Tab 4: Reports (Báo cáo)
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment),
            label: 'Reports',
          ),
          // Tab 5: Profile (Hồ sơ)
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
