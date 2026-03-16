import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_routes.dart';
import 'features/store_manager/manager_main_screen.dart';
import 'features/store_manager/inventory/stock_import_request_screen.dart';
import 'features/store_manager/profile/manager_profile_screen.dart';
import 'features/store_manager/profile/manager_settings_screen.dart';
import 'features/store_manager/inventory/recent_requests_screen.dart';

/// Điểm khởi đầu ứng dụng Retail Chain Management System
/// Khởi tạo Firebase và chạy ứng dụng
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const RCMSApp());
}

/// Widget gốc của ứng dụng
/// Cấu hình theme (M3 Emerald Green) và route cho toàn bộ app
class RCMSApp extends StatelessWidget {
  const RCMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Retail Chain Management',
      debugShowCheckedModeBanner: false,
      // Áp dụng theme M3 Emerald Green
      theme: AppTheme.lightTheme,
      // Route mặc định: vào màn hình Store Manager
      // (Sẽ thay đổi thành Login screen khi team auth hoàn thành)
      initialRoute: AppRoutes.manager,
      // ===== BẢNG ROUTE =====
      // Mỗi actor thêm route của mình tại đây (1 dòng = 1 route)
      routes: {
        // ===== Routes Store Manager =====
        AppRoutes.manager: (context) => const ManagerMainScreen(),
        AppRoutes.managerProfile: (context) => const ManagerProfileScreen(),
        AppRoutes.managerSettings: (context) => const ManagerSettingsScreen(),
        AppRoutes.stockImportRequest: (context) => const StockImportRequestScreen(),
        AppRoutes.recentRequests: (context) => const RecentRequestsScreen(),

        // Route Admin (thêm sau bởi team member khác)
        // AppRoutes.admin: (_) => const AdminMainScreen(),

        // Route Staff (thêm sau bởi team member khác)
        // AppRoutes.staff: (_) => const StaffMainScreen(),
      },
    );
  }
}
