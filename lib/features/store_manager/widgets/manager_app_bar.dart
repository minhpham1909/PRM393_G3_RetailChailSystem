import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';

/// App Bar dùng chung cho các tab của Store Manager
/// - Hiển thị Avatar, Tên Store Manager, Tên Store
/// - Bấm vào sẽ chuyển sang Profile
class ManagerAppBar extends StatefulWidget implements PreferredSizeWidget {
  final bool showBackButton;

  const ManagerAppBar({super.key, this.showBackButton = false});

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

    // Lắng nghe user document bằng email thay vì UID, để tương thích với mock data seeder.
    _userSubscription = _firestoreService.db.collection('users')
      .where('email', isEqualTo: currentUser.email)
      .limit(1)
      .snapshots().listen((querySnapshot) async {
      if (querySnapshot.docs.isEmpty || !mounted) return;

      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data()!;
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
            debugPrint('Lỗi tải tên cửa hàng cho AppBar: $e');
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
      debugPrint('Lỗi lắng nghe dữ liệu AppBar: $e');
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
      automaticallyImplyLeading: widget.showBackButton, // Hiển thị nút back nếu được yêu cầu
      title: GestureDetector(
        onTap: () {
          if (!widget.showBackButton) {
            Navigator.pushNamed(context, AppRoutes.managerProfile);
          }
        },
        child: Container(
          color: Colors.transparent, // Để nhận tap trên toàn Row
          child: Row(
            children: [
              // Avatar tròn
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
              
              // Tên Manager + Tên Store
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
        // Nút Cài đặt (Settings)
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
