import 'package:flutter/material.dart';
import '../../../core/constants/app_routes.dart';

/// App Bar dùng chung cho các tab của Store Manager (Dashboard, Inventory, Team, Reports)
/// Thiết kế đồng bộ theo ảnh giao diện mẫu:
/// - Avatar bên trái
/// - Phụ đề "Store Manager" (màu xanh lá)
/// - Tiêu đề màn hình (chữ to)
/// - Icon Settings bên phải
class ManagerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const ManagerAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: colorScheme.surface,
      automaticallyImplyLeading: false, // Bỏ nút back mặc định
      title: Row(
        children: [
          // Avatar tròn bên trái (Profile)
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.managerProfile);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: colorScheme.primary,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Chữ Store Manager + Tiêu đề tab
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Store Manager',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Nút Cài đặt (Settings)
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.black87),
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.managerSettings);
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64);
}
