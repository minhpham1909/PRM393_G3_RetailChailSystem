/// Định nghĩa tên các route trong ứng dụng
/// Mỗi actor chỉ cần thêm route của mình tại đây
/// Tránh conflict: mỗi nhóm route được gom theo phần riêng
class AppRoutes {
  AppRoutes._(); // Không cho phép khởi tạo

  // ===== Route chung =====
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';

  // ===== Route Store Manager =====
  static const String manager = '/manager';
  static const String managerProfile = '/manager/profile';
  static const String managerSettings = '/manager/settings';
  static const String stockImportRequest = '/manager/stock_import_request';
  static const String recentRequests = '/manager/recent_requests';

  // Admin Routes (thêm sau)
  static const String admin = '/admin';

  // Staff Routes (thêm sau)
  static const String staff = '/staff';
}
