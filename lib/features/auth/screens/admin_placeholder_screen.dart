import 'package:flutter/material.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/auth_service.dart';

/// Placeholder cho Admin (tạm thời)
/// Để test: đăng nhập admin sẽ đi vào màn hình này.
class AdminPlaceholderScreen extends StatelessWidget {
  const AdminPlaceholderScreen({super.key});

  
  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    // Tối ưu: Nên khởi tạo service một lần hoặc dùng DI (Provider, GetIt) thay vì trong build().
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
            onPressed: () async {
              await auth.signOut();
              await authService.signOut();
              if (context.mounted) {
                Navigator.popUntil(context, (r) => r.isFirst);
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Admin module chưa được tích hợp.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.adminProfile);
              },
              icon: const Icon(Icons.person_outline),
              label: const Text('Hồ sơ cá nhân'),
            ),
          ],
        ),
      ),
    );
  }
}
