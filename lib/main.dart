import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/models/order_model.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_routes.dart';
import 'features/store_manager/manager_main_screen.dart';
import 'features/store_manager/reports/order_detail_screen.dart';
import 'features/store_manager/inventory/stock_import_request_screen.dart';
import 'features/store_manager/profile/manager_profile_screen.dart';
import 'features/store_manager/profile/manager_settings_screen.dart';
import 'features/store_manager/inventory/recent_requests_screen.dart';
import 'features/store_manager/inventory/product_detail_screen.dart';
import 'features/auth/auth_gate.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/auth/screens/admin_placeholder_screen.dart';
import 'features/auth/widgets/protected_route.dart';

/// Điểm khởi đầu ứng dụng Retail Chain Management System
/// Khởi tạo Firebase và chạy ứng dụng
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
      // Route mặc định: AuthGate (tự điều hướng theo session + role)
      initialRoute: '/',
      // ===== BẢNG ROUTE =====
      // Mỗi actor thêm route của mình tại đây (1 dòng = 1 route)
      routes: {
        // Root gate
        '/': (context) => const AuthGate(),

        // ===== Auth routes =====
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.forgotPassword: (context) => const ForgotPasswordScreen(),

        // ===== Routes Store Manager =====
        AppRoutes.manager: (context) => const ProtectedRoute(
          allowedRoles: ['store_manager'],
          child: ManagerMainScreen(),
        ),
        AppRoutes.managerProfile: (context) => const ProtectedRoute(
          allowedRoles: ['store_manager'],
          child: ManagerProfileScreen(),
        ),
        AppRoutes.managerSettings: (context) => const ProtectedRoute(
          allowedRoles: ['store_manager'],
          child: ManagerSettingsScreen(),
        ),
        AppRoutes.stockImportRequest: (context) => const ProtectedRoute(
          allowedRoles: ['store_manager'],
          child: StockImportRequestScreen(),
        ),
        AppRoutes.recentRequests: (context) => const ProtectedRoute(
          allowedRoles: ['store_manager'],
          child: RecentRequestsScreen(),
        ),
        AppRoutes.productDetail: (context) => const ProtectedRoute(
          allowedRoles: ['store_manager'],
          child: ProductDetailScreen(),
        ),
        AppRoutes.orderDetail: (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          // Safely handle the case where arguments are provided and are of the correct type.
          if (args is OrderModel) {
            return ProtectedRoute(
              allowedRoles: const ['store_manager'],
              child: OrderDetailScreen(order: args),
            );
          }
          // Display an error screen if the arguments are missing or incorrect.
          return const Scaffold(
            body: Center(child: Text('Error: Order data not provided.')),
          );
        },

        // ===== Routes Admin =====
        AppRoutes.admin: (context) => const ProtectedRoute(
          allowedRoles: ['admin'],
          child: AdminPlaceholderScreen(),
        ),
      },
    );
  }
}
