import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/user_model.dart';

/// ProtectedRoute:
/// Wrapper widget to protect routes based on authentication and roles.
class ProtectedRoute extends StatefulWidget {
  final Widget child;
  final List<String>? allowedRoles;

  const ProtectedRoute({
    super.key,
    required this.child,
    this.allowedRoles,
  });

  @override
  State<ProtectedRoute> createState() => _ProtectedRouteState();
}

class _ProtectedRouteState extends State<ProtectedRoute> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestore = FirestoreService();
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final user = _auth.currentUser;
    
    if (user == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
      return;
    }

    if (widget.allowedRoles == null || widget.allowedRoles!.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final snap = await _firestore
          .queryCollection('users', field: 'email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      final userModel = UserModel.fromFirestore(snap.docs.first);
      
      if (widget.allowedRoles!.contains(userModel.role)) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        // Not authorized for this role
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You do not have permission to access this page')),
          );
          Navigator.pushReplacementNamed(context, '/');
        }
      }
    } catch (e) {
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return widget.child;
  }
}
