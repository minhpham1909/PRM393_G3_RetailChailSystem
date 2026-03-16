import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';

/// Placeholder cho Admin (tạm thời)
/// Để test: đăng nhập admin sẽ đi vào màn hình này.
class AdminPlaceholderScreen extends StatelessWidget {
  const AdminPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) {
                Navigator.popUntil(context, (r) => r.isFirst);
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const Center(child: Text('Admin module chưa được tích hợp.')),
    );
  }
}
