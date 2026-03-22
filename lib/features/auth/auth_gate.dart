import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../core/constants/app_routes.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';

/// AuthGate:
/// - Nếu chưa đăng nhập -> điều hướng sang Login
/// - Nếu đã đăng nhập -> load thêm profile từ Firestore (users collection) để biết role
///   rồi điều hướng về màn hình tương ứng.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestore = FirestoreService();

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Lắng nghe thay đổi auth để tự redirect sau khi login/logout
    _auth.authStateChanges().listen((_) {
      if (!mounted) return;
      _navigated = false;
      _handleAuth();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_navigated) return;
    _navigated = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAuth();
    });
  }

  Future<void> _handleAuth() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    // Tìm account theo email trong collection users (luôn dùng lowercase để tránh lỗi Case Sensitive)
    try {
      final normalizedEmail = user.email?.toLowerCase();
      
      final snap = await _firestore
          .queryCollection('users', field: 'email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        final localRole = await _findLocalRoleByEmail(normalizedEmail);
        if (!mounted) return;

        if (localRole == 'admin') {
          Navigator.pushReplacementNamed(context, AppRoutes.admin);
          return;
        }

        if (localRole == 'store_manager') {
          Navigator.pushReplacementNamed(context, AppRoutes.manager);
          return;
        }

        await _auth.signOut();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      final doc = snap.docs.first;
      final userModel = UserModel.fromFirestore(doc);
      
      // Auto-Link UID: Nếu là tài khoản Google vừa đăng nhập lần đầu (chưa có UID trong Firestore)
      // thì chúng ta cập nhật UID vào để đồng bộ sau này.
      if (userModel.authMethod == 'google' && (userModel.authUid == null || userModel.authUid!.isEmpty)) {
        await doc.reference.update({'auth_uid': user.uid});
      }

      if (!mounted) return;
      if (userModel.role == 'admin') {
        Navigator.pushReplacementNamed(context, AppRoutes.admin);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.manager);
      }
    } catch (_) {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  Future<String?> _findLocalRoleByEmail(String? email) async {
    if (email == null || email.trim().isEmpty) return null;

    try {
      final normalizedEmail = email.trim().toLowerCase();
      final jsonString = await rootBundle.loadString('data/users.json');
      final Map<String, dynamic> jsonData =
          jsonDecode(jsonString) as Map<String, dynamic>;
      final List<dynamic> users = jsonData['users'] as List<dynamic>? ?? [];

      for (final user in users) {
        if (user is! Map<String, dynamic>) continue;
        final localEmail = (user['email'] as String? ?? '').trim().toLowerCase();
        if (localEmail == normalizedEmail) {
          return user['role'] as String?;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Checking session...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
