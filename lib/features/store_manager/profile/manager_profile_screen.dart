import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/manager_app_bar.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/constants/app_routes.dart';

class ManagerProfileScreen extends StatefulWidget {
  const ManagerProfileScreen({super.key});

  @override
  State<ManagerProfileScreen> createState() => _ManagerProfileScreenState();
}

class _ManagerProfileScreenState extends State<ManagerProfileScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, dynamic>? _managerData;
  Map<String, dynamic>? _storeData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user != null && user.email != null) {
        // 1. Fetch Manager Data by Email
        final userSnap = await _db
            .collection('users')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        if (userSnap.docs.isNotEmpty) {
          _managerData = userSnap.docs.first.data();
          
          // 2. Fetch Store Data
          final storeId = _managerData?['store_id'];
          if (storeId != null) {
            final storeDoc = await _db.collection('stores').doc(storeId).get();
            if (storeDoc.exists) {
              _storeData = storeDoc.data();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditProfileModal() {
    final fullNameController = TextEditingController(text: _managerData?['full_name']);
    final emailController = TextEditingController(text: _managerData?['email']);
    final phoneController = TextEditingController(text: _managerData?['phone']);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Chỉnh sửa thông tin', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fullNameController,
                  decoration: const InputDecoration(labelText: 'Họ và tên', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Số điện thoại', border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Lưu ý: Nếu thay đổi Email, bạn có thể cần đăng nhập lại.',
                  style: TextStyle(fontSize: 11, color: Colors.orange, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('HỦY')),
            FilledButton(
              onPressed: isSaving ? null : () async {
                setModalState(() => isSaving = true);
                try {
                  final user = _authService.currentUser;
                  if (user != null) {
                    // Update Firestore
                    final query = await _db
                        .collection('users')
                        .where('email', isEqualTo: user.email)
                        .limit(1)
                        .get();
                    
                    if (query.docs.isNotEmpty) {
                      await query.docs.first.reference.update({
                        'full_name': fullNameController.text,
                        'email': emailController.text,
                        'phone': phoneController.text,
                      });

                      // Update Firebase Auth Email if changed
                      if (emailController.text != user.email) {
                        await user.verifyBeforeUpdateEmail(emailController.text);
                      }
                    }
                  }
                  
                  if (mounted) {
                    Navigator.pop(context);
                    _loadAllData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cập nhật thông tin thành công!'))
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e'))
                    );
                  }
                } finally {
                  setModalState(() => isSaving = false);
                }
              },
              child: isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('LƯU THAY ĐỔI'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPasswordChangeModal() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Đổi mật khẩu', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mật khẩu mới', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu mới', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('HỦY'),
            ),
            FilledButton(
              onPressed: isUpdating ? null : () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu mới không khớp')));
                  return;
                }
                setModalState(() => isUpdating = true);
                try {
                  final user = _authService.currentUser;
                  if (user != null) {
                    // Re-authenticate first would be better, but for now simple update
                    await user.updatePassword(newPasswordController.text);
                  }
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e (Cần đăng nhập lại để đổi pass)')));
                  }
                } finally {
                  setModalState(() => isUpdating = false);
                }
              },
              child: isUpdating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('LƯU MẬT KHẨU'),
            ),
          ],
        ),
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi hệ thống?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.pop(context);
              await _authService.signOut();
              if (mounted) Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is Timestamp) {
      final dt = date.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    if (date is String) {
      final dt = DateTime.tryParse(date);
      if (dt != null) return '${dt.day}/${dt.month}/${dt.year}';
    }
    return date.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: const ManagerAppBar(showBackButton: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: const ManagerAppBar(showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Head Profile Section
            _buildProfileHeader(colorScheme),
            const SizedBox(height: 32),

            // Manager Info Card
            _buildSectionHeader(context, 'THÔNG TIN CÁ NHÂN', onEdit: _showEditProfileModal),
            const SizedBox(height: 16),
            _buildInfoCard(colorScheme, [
              _buildInfoRow(Icons.account_circle_outlined, 'Account ID', _managerData?['account_id'] ?? 'N/A'),
              _buildInfoRow(Icons.email_outlined, 'Email', _managerData?['email'] ?? 'N/A'),
              _buildInfoRow(Icons.phone_outlined, 'Số điện thoại', _managerData?['phone'] ?? 'N/A'),
              _buildInfoRow(Icons.work_outline, 'Chức vụ', _managerData?['role']?.toString().toUpperCase() ?? 'STORE MANAGER'),
              _buildInfoRow(Icons.calendar_today_outlined, 'Ngày tham gia', _formatDate(_managerData?['created_at'])),
            ]),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _showPasswordChangeModal,
                icon: const Icon(Icons.lock_reset, size: 20),
                label: const Text('ĐỔI MẬT KHẨU'),
              ),
            ),

            const SizedBox(height: 32),

            // Store Info Card
            _buildSectionHeader(context, 'THÔNG TIN CHI NHÁNH'),
            const SizedBox(height: 16),
            _buildInfoCard(colorScheme, [
              _buildInfoRow(Icons.storefront, 'Tên cửa hàng', _storeData?['name'] ?? 'N/A'),
              _buildInfoRow(Icons.location_on_outlined, 'Địa chỉ', _storeData?['address'] ?? 'N/A'),
              _buildInfoRow(Icons.phone_in_talk_outlined, 'Hotline cửa hàng', _storeData?['store_phoneNum'] ?? 'N/A'),
              _buildInfoRow(Icons.info_outline, 'Trạng thái', _storeData?['status']?.toString().toUpperCase() ?? 'ACTIVE', isSuccess: true),
            ]),

            const SizedBox(height: 48),

            // Logout Button
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('ĐĂNG XUẤT'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error.withOpacity(0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ColorScheme colorScheme) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer.withOpacity(0.3),
                border: Border.all(color: colorScheme.primary, width: 2),
              ),
              child: Icon(Icons.person, size: 50, color: colorScheme.primary),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _managerData?['full_name'] ?? 'Store Manager',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          _storeData?['name'] ?? 'Loading Branch...',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, {VoidCallback? onEdit}) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        if (onEdit != null)
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 14),
            label: const Text('Sửa', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  Widget _buildInfoCard(ColorScheme colorScheme, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: children.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.5)),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isSuccess = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary.withOpacity(0.7)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant.withOpacity(0.8), fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isSuccess ? Colors.green : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
