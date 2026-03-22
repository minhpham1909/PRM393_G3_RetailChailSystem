import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/services/auth_service.dart';
import '../../store_manager/widgets/manager_app_bar.dart';

class AccountProfileScreen extends StatefulWidget {
  final String actorLabel;
  final bool showStoreInfo;
  final bool useManagerAppBar;

  const AccountProfileScreen({
    super.key,
    required this.actorLabel,
    this.showStoreInfo = false,
    this.useManagerAppBar = false,
  });

  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
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
        final userSnap = await _db
            .collection('users')
            .where('email', isEqualTo: user.email?.toLowerCase())
            .limit(1)
            .get();

        if (userSnap.docs.isNotEmpty) {
          _userData = userSnap.docs.first.data();
          _userData?['id'] = userSnap.docs.first.id;

          if (widget.showStoreInfo) {
            final storeId = _userData?['store_id'];
            if (storeId != null) {
              final storeDoc = await _db.collection('stores').doc(storeId).get();
              if (storeDoc.exists) {
                _storeData = storeDoc.data();
              }
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
    final fullNameController =
        TextEditingController(text: _userData?['full_name']);
    final emailController = TextEditingController(text: _userData?['email']);
    final phoneController = TextEditingController(text: _userData?['phone']);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Edit profile',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: If you change your email, you may need to sign in again.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setModalState(() => isSaving = true);
                      try {
                        final user = _authService.currentUser;
                        if (user != null) {
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

                            if (emailController.text != user.email) {
                              await user.verifyBeforeUpdateEmail(
                                emailController.text,
                              );
                            }
                          }
                        }

                        if (mounted) {
                          Navigator.pop(context);
                          _loadAllData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile updated successfully!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      } finally {
                        setModalState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('SAVE CHANGES'),
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
    bool showOldPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Change password',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPasswordController,
                  obscureText: !showOldPassword,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showOldPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setModalState(() {
                          showOldPassword = !showOldPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: !showNewPassword,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showNewPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setModalState(() {
                          showNewPassword = !showNewPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: !showConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm new password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setModalState(() {
                          showConfirmPassword = !showConfirmPassword;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: isUpdating
                  ? null
                  : () async {
                      if (newPasswordController.text !=
                          confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('New passwords do not match'),
                          ),
                        );
                        return;
                      }
                      setModalState(() => isUpdating = true);
                      try {
                        final user = _authService.currentUser;
                        if (user != null) {
                          await user.updatePassword(newPasswordController.text);
                        }
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Updated successfully!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Error: $e (You may need to sign in again to change your password)',
                              ),
                            ),
                          );
                        }
                      } finally {
                        setModalState(() => isUpdating = false);
                      }
                    },
              child: isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('SAVE PASSWORD'),
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
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _authService.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (route) => false,
                );
              }
            },
            child: const Text('Sign out'),
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
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileHeader(colorScheme),
            const SizedBox(height: 32),
            _buildSectionHeader(
              context,
              'PERSONAL INFORMATION',
              onEdit: _showEditProfileModal,
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              colorScheme,
              [
                _buildInfoRow(
                  Icons.account_circle_outlined,
                  'Account ID',
                  _userData?['account_id'] ?? _userData?['id'] ?? (_userData?['auth_method'] == 'google' ? 'GOOGLE_AUTH' : 'N/A'),
                ),
                _buildInfoRow(
                  Icons.email_outlined,
                  'Email',
                  _userData?['email'] ?? 'N/A',
                ),
                _buildInfoRow(
                  Icons.phone_outlined,
                  'Phone number',
                  _userData?['phone_number'] ?? _userData?['phone'] ?? 'N/A',
                ),
                _buildInfoRow(
                  Icons.work_outline,
                  'Role',
                  _userData?['role']?.toString().toUpperCase() ??
                      widget.actorLabel.toUpperCase(),
                ),
                _buildInfoRow(
                  Icons.calendar_today_outlined,
                  'Joined',
                  _formatDate(_userData?['created_at']),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _showPasswordChangeModal,
                icon: const Icon(Icons.lock_reset, size: 20),
                label: const Text('CHANGE PASSWORD'),
              ),
            ),
            if (widget.showStoreInfo) ...[
              const SizedBox(height: 32),
              _buildSectionHeader(context, 'BRANCH INFORMATION'),
              const SizedBox(height: 16),
              _buildInfoCard(
                colorScheme,
                [
                  _buildInfoRow(
                    Icons.storefront,
                    'Store name',
                    _storeData?['name'] ?? 'N/A',
                  ),
                  _buildInfoRow(
                    Icons.location_on_outlined,
                    'Address',
                    _storeData?['address'] ?? 'N/A',
                  ),
                  _buildInfoRow(
                    Icons.phone_in_talk_outlined,
                    'Store hotline',
                    _storeData?['store_phoneNum'] ?? 'N/A',
                  ),
                  _buildInfoRow(
                    Icons.info_outline,
                    'Status',
                    _storeData?['status']?.toString().toUpperCase() ?? 'ACTIVE',
                    isSuccess: true,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 48),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('SIGN OUT'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error.withOpacity(0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (widget.useManagerAppBar) {
      return const ManagerAppBar(showBackButton: true);
    }

    return AppBar(
      title: const Text('Profile'),
      backgroundColor: Theme.of(context).colorScheme.surface,
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
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _userData?['full_name'] ?? widget.actorLabel,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          widget.showStoreInfo
              ? (_storeData?['name'] ?? 'Loading Branch...')
              : (_userData?['role']?.toString().toUpperCase() ??
                  widget.actorLabel.toUpperCase()),
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    VoidCallback? onEdit,
  }) {
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
            label: const Text('Edit', style: TextStyle(fontSize: 12)),
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
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: colorScheme.outlineVariant.withOpacity(0.5),
        ),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isSuccess = false,
  }) {
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
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
