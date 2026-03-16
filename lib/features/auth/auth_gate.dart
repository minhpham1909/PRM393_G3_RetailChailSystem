import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

    // Tìm account theo email trong collection users
    try {
      final snap = await _firestore
          .queryCollection('users', field: 'email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      final userModel = UserModel.fromFirestore(snap.docs.first);

      if (!mounted) return;
      if (userModel.role == 'admin') {
        Navigator.pushReplacementNamed(context, AppRoutes.admin);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.manager);
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
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
