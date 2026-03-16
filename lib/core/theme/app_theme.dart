import 'package:flutter/material.dart';

/// Theme chung cho toàn bộ ứng dụng Retail Chain Management
/// Sử dụng Material Design 3 với màu Emerald Green làm chủ đạo
/// 
/// Quy ước màu sắc theo actor:
/// - System Admin: Deep Blue (primary)
/// - Store Manager: Emerald Green (secondary → seed color chính)
/// - Staff: Vibrant Orange (tertiary)
class AppTheme {
  AppTheme._(); // Không cho phép khởi tạo

  // ==================== MÀU SẮC CHÍNH ====================
  
  /// Màu chủ đạo cho Store Manager
  static const Color managerGreen = Color(0xFF1B6D24);
  
  /// Màu chủ đạo cho Admin
  static const Color adminBlue = Color(0xFF0D47A1);
  
  /// Màu chủ đạo cho Staff
  static const Color staffOrange = Color(0xFFE65100);

  // ==================== THEME SÁNG ====================

  /// Theme sáng cho ứng dụng (dùng Emerald Green làm seed)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: managerGreen,
        brightness: Brightness.light,
      ),
      // Font chữ Inter (Google Fonts) — giống stitch template
      fontFamily: 'Inter',
      // Thanh ứng dụng phía trên
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      // Thẻ (Card)
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // Trường nhập liệu
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      // Nút bấm chính
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
      ),
      // Nút nổi (FAB)
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      // Thanh điều hướng phía dưới
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    );
  }
}
