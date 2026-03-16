import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firestore_service.dart';
import '../widgets/manager_app_bar.dart';

/// Màn hình Quản lý Tài khoản Nhân viên (Account Management)
/// Cho phép Store Manager xem, tìm kiếm, và quản lý tài khoản staff
/// Thiết kế theo stitch template: account_management
class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  // Danh sách nhân viên
  List<UserModel> _staffList = [];
  List<UserModel> _filteredList = [];
  bool _isLoading = true;

  // Bộ điều khiển ô tìm kiếm
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStaffAccounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Tải danh sách tài khoản nhân viên từ Firestore
  Future<void> _loadStaffAccounts() async {
    try {
      final snapshot =
          await _firestoreService.db
              .collection('users')
              .where('role', isEqualTo: 'staff')
              .get();

      final staff =
          snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();

      if (mounted) {
        setState(() {
          _staffList = staff;
          _filteredList = staff;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Lỗi tải danh sách nhân viên: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Lọc danh sách theo từ khóa tìm kiếm
  void _filterStaff(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredList = _staffList;
      } else {
        _filteredList =
            _staffList
                .where(
                  (user) =>
                      user.fullName.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      user.email.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
      }
    });
  }

  /// Hiển thị dialog thêm nhân viên mới
  void _showAddStaffDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Thêm nhân viên mới'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Họ tên',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () async {
                  if (nameCtrl.text.isNotEmpty && emailCtrl.text.isNotEmpty) {
                    // Tạo tài khoản nhân viên mới trong Firestore
                    await _firestoreService.addDocument('users', {
                      'full_name': nameCtrl.text,
                      'email': emailCtrl.text,
                      'role': 'staff',
                      'is_active': true,
                    });
                    if (context.mounted) Navigator.pop(context);
                    _loadStaffAccounts(); // Tải lại danh sách
                  }
                },
                child: const Text('Thêm'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalStaff = _staffList.length;
    final activeStaff = _staffList.where((s) => s.isActive).length;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: const ManagerAppBar(title: 'Staff Management'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStaffAccounts,
          child: CustomScrollView(
            slivers: [
              // ===== HEADER =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tiêu đề nhỏ
                      Text(
                        'TEAM DIRECTORY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Tiêu đề lớn
                      Text(
                        'Account Management',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ===== Ô TÌM KIẾM =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterStaff,
                    decoration: InputDecoration(
                      hintText: 'Search by name, role, or store...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: () {},
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),

              // ===== THẺ THỐNG KÊ: Tổng nhân viên + Đang hoạt động =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      // Thẻ tổng nhân viên (xanh dương đậm)
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(
                                  Icons.groups,
                                  color: colorScheme.onPrimaryContainer,
                                  size: 28,
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$totalStaff',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                    Text(
                                      'TOTAL STAFF',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1,
                                        color: colorScheme.onPrimaryContainer
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Thẻ đang hoạt động
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      color: colorScheme.primary,
                                      size: 10,
                                    ),
                                    Text(
                                      'ACTIVE NOW',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$activeStaff',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      'IN STORE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ===== TIÊU ĐỀ DANH SÁCH =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ACCESS CONTROL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ===== DANH SÁCH NHÂN VIÊN =====
              _isLoading
                  ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                  : _filteredList.isEmpty
                  ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No staff accounts found',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    sliver: SliverList.separated(
                      itemCount: _filteredList.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        return _buildStaffItem(_filteredList[index]);
                      },
                    ),
                  ),
            ],
          ),
        ),
      ),
      // Nút thêm nhân viên (FAB)
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStaffDialog,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  /// Widget hiển thị một nhân viên trong danh sách
  /// Theo stitch: avatar, tên, role badge, trạng thái, mũi tên
  Widget _buildStaffItem(UserModel user) {
    final colorScheme = Theme.of(context).colorScheme;

    // Chọn màu badge theo vai trò
    Color roleBgColor;
    Color roleTextColor;
    switch (user.role) {
      case 'admin':
        roleBgColor = colorScheme.primaryContainer;
        roleTextColor = colorScheme.onPrimaryContainer;
        break;
      case 'manager':
        roleBgColor = colorScheme.secondaryContainer;
        roleTextColor = colorScheme.onSecondaryContainer;
        break;
      default:
        roleBgColor = colorScheme.tertiaryContainer;
        roleTextColor = colorScheme.onTertiaryContainer;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: roleBgColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.person, color: roleTextColor, size: 24),
          ),
          const SizedBox(width: 12),
          // Thông tin nhân viên
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tên
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                // Badge vai trò + cửa hàng
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: roleBgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        user.role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: roleTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Trạng thái + mũi tên
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          user.isActive
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    user.isActive ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color:
                          user.isActive
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: colorScheme.outlineVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
