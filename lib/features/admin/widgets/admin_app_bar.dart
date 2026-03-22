import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/firestore_service.dart';

/// Shared app bar for Admin screens.
/// - Shows avatar, system administrator subtitle, admin name
/// - Tap to open Profile
class AdminAppBar extends StatefulWidget implements PreferredSizeWidget {
  final bool showBackButton;

  const AdminAppBar({super.key, this.showBackButton = false});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  State<AdminAppBar> createState() => _AdminAppBarState();
}

class _AdminAppBarState extends State<AdminAppBar> {
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription? _userSubscription;
  String _adminName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _listenToProfileData();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  void _listenToProfileData() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() { _adminName = 'Not Logged In'; });
      return;
    }

    _userSubscription = _firestoreService.db.collection('users')
      .where('email', isEqualTo: currentUser.email)
      .limit(1)
      .snapshots().listen((querySnapshot) {
      if (querySnapshot.docs.isEmpty || !mounted) return;

      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data();
      final newAdminName = userData['full_name'] ?? 'Administrator';
      
      if (newAdminName != _adminName) {
        setState(() {
          _adminName = newAdminName;
        });
      }
    }, onError: (e) {
      debugPrint('AdminAppBar listener error: $e');
      if (mounted) setState(() { _adminName = 'Error'; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: colorScheme.surface,
      automaticallyImplyLeading: widget.showBackButton,
      title: GestureDetector(
        onTap: () {
          if (!widget.showBackButton) {
            Navigator.pushNamed(context, AppRoutes.adminProfile);
          }
        },
        child: Container(
          color: Colors.transparent,
          child: Row(
            children: [
              // Round avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              
              // Subtitle + Admin name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'System Administrator',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _adminName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: const [
        SizedBox(width: 8),
      ],
    );
  }
}
