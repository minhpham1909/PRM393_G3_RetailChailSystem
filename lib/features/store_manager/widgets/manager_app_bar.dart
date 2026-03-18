import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_routes.dart';
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _managerName = 'Loading...';
  String _storeName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final email = _auth.currentUser?.email;
      if (email == null || email.trim().isEmpty) {
        if (mounted) {
          setState(() {
            _managerName = 'Store Manager';
            _storeName = 'No Account';
          });
        }
        return;
      }

      final usersSnapshot = await _firestoreService.db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (usersSnapshot.docs.isNotEmpty) {
        final userData = usersSnapshot.docs.first.data();
        final storeId = userData['store_id'];
        
        String fetchedStoreName = 'No Store Assigned';
        if (storeId != null) {
          final storeDoc = await _firestoreService.db.collection('stores').doc(storeId).get();
          if (storeDoc.exists) {
            fetchedStoreName = storeDoc.data()?['name'] ?? 'Unknown Store';
          }
        }

        if (mounted) {
          setState(() {
            _managerName = userData['full_name'] ?? 'Store Manager';
            _storeName = fetchedStoreName;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _managerName = 'Store Manager';
            _storeName = 'No Dashboard Info';
          });
        }
      }
    } catch (e) {
      debugPrint('Lỗi tải dữ liệu app bar: $e');
      if (mounted) {
        setState(() {
          _managerName = 'Error';
          _storeName = 'Error Loading';
        });
      }
    }
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
