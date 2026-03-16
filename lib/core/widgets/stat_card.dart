import 'package:flutter/material.dart';

/// Widget thẻ thống kê dùng chung (Dashboard, Inventory, Reports)
/// Hiển thị tiêu đề, giá trị số, và icon
/// Phong cách theo stitch template: rounded-xl, padding lớn, font bold
class StatCard extends StatelessWidget {
  /// Tiêu đề phía trên (ví dụ: "TOTAL ITEMS")
  final String title;

  /// Giá trị hiển thị lớn (ví dụ: "1,284")
  final String value;

  /// Icon Material hiển thị góc phải
  final IconData? icon;

  /// Màu nền của thẻ
  final Color? backgroundColor;

  /// Màu chữ
  final Color? textColor;

  /// Hàm gọi khi bấm vào thẻ
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = backgroundColor ?? colorScheme.surfaceContainerLow;
    final fgColor = textColor ?? colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Tiêu đề
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: fgColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            // Hàng: giá trị + icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Giá trị số lớn
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: fgColor,
                      height: 1,
                    ),
                  ),
                ),
                // Icon
                if (icon != null)
                  Icon(icon, color: fgColor.withValues(alpha: 0.6), size: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
