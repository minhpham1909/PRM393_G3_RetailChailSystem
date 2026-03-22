import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/firestore_service.dart';

/// Shared app bar for Store Manager screens.
/// - Shows avatar, manager name, store name
/// - Tap to open Profile
class ManagerAppBar extends StatefulWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final List<Widget>? actions;

  const ManagerAppBar({super.key, this.showBackButton = false, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  State<ManagerAppBar> createState() => _ManagerAppBarState();
}

class _ManagerAppBarState extends State<ManagerAppBar> {
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription? _userSubscription;
  String _managerName = 'Loading...';
  String _storeName = 'Loading...';
  String? _currentStoreId;

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
      if (mounted) setState(() { _managerName = 'Not Logged In'; _storeName = 'N/A'; });
      return;
    }

    // Listen by email (not UID) for mock-data seeder compatibility.
    _userSubscription = _firestoreService.db.collection('users')
      .where('email', isEqualTo: currentUser.email)
      .limit(1)
      .snapshots().listen((querySnapshot) async {
      if (querySnapshot.docs.isEmpty || !mounted) return;

      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data();
      final newManagerName = userData['full_name'] ?? 'Store Manager';
      final newStoreId = userData['store_id'];
      
      String newStoreName = _storeName;

      // Fetch store name only if storeId has changed
      if (newStoreId != _currentStoreId) {
        _currentStoreId = newStoreId;
        if (newStoreId != null) {
          try {
            final storeDoc = await _firestoreService.db.collection('stores').doc(newStoreId).get();
            newStoreName = storeDoc.exists ? (storeDoc.data()?['name'] ?? 'Unknown Store') : 'No Store Assigned';
          } catch (e) {
            debugPrint('Failed to load store name for AppBar: $e');
            newStoreName = 'Error Loading Store';
          }
        } else {
          newStoreName = 'No Store Assigned';
        }
      }

      // Update state only if data has changed
      if (newManagerName != _managerName || newStoreName != _storeName) {
        if (mounted) {
          setState(() {
            _managerName = newManagerName;
            _storeName = newStoreName;
          });
        }
      }
    }, onError: (e) {
      debugPrint('AppBar listener error: $e');
      if (mounted) setState(() { _managerName = 'Error'; _storeName = 'Error'; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: colorScheme.surface,
      automaticallyImplyLeading: widget.showBackButton, // Show back button when requested.
      title: GestureDetector(
        onTap: () {
          if (!widget.showBackButton) {
            Navigator.pushNamed(context, AppRoutes.managerProfile);
          }
        },
        child: Container(
          color: Colors.transparent, // Capture taps across the whole row.
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
                  Icons.person,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              
              // Store name + manager name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _storeName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _managerName,
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
      actions: [
        if (widget.actions != null) ...widget.actions!,
        // Settings
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.black87),
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.managerSettings);
          }
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
