import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../widgets/admin_app_bar.dart';

enum _ManagerMenuAction { details, edit, delete }

/// Store Manager account management screen.
/// Admin can: create, read, update, delete Store Manager accounts.
class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  String _searchQuery = '';
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: const AdminAppBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.db
            .collection('users')
            .where('role', isEqualTo: 'store_manager')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final managers = snapshot.hasData
              ? snapshot.data!.docs.map((doc) => UserModel.fromFirestore(doc)).toList()
              : <UserModel>[];

          // Filter based on search query
          final filteredManagers = managers
              .where((m) =>
                  m.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  m.email.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();

          return SingleChildScrollView(
            child: Column(
              children: [
                // Compact Summary Card
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    color: colorScheme.primaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.manage_accounts, color: colorScheme.onPrimaryContainer),
                              const SizedBox(width: 12),
                              Text(
                                'TOTAL STORE MANAGERS',
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            managers.length.toString(),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Actions & Search
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Add button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: () => _showAddManagerDialog(),
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add new Store Manager'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Search
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by name or email...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colorScheme.outlineVariant),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colorScheme.outlineVariant),
                          ),
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Managers List
                if (filteredManagers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No Store Managers found',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MANAGERS LIST (${filteredManagers.length})',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredManagers.length,
                          itemBuilder: (context, index) {
                            final manager = filteredManagers[index];
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              color: colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                leading: CircleAvatar(
                                  backgroundColor: colorScheme.primaryContainer,
                                  foregroundColor: colorScheme.onPrimaryContainer,
                                  child: Text(
                                    manager.fullName.isNotEmpty
                                        ? manager.fullName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(manager.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  manager.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                                ),
                                onTap: () => _showManagerDetailsDialog(manager),
                                trailing: PopupMenuButton<_ManagerMenuAction>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (action) {
                                    switch (action) {
                                      case _ManagerMenuAction.details:
                                        _showManagerDetailsDialog(manager);
                                        break;
                                      case _ManagerMenuAction.edit:
                                        _showEditManagerDialog(manager);
                                        break;
                                      case _ManagerMenuAction.delete:
                                        _showDeleteConfirmDialog(manager);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: _ManagerMenuAction.details,
                                      child: ListTile(
                                        leading: Icon(Icons.visibility, size: 20),
                                        title: Text('View details'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: _ManagerMenuAction.edit,
                                      child: ListTile(
                                        leading: Icon(Icons.edit, size: 20),
                                        title: Text('Edit'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: _ManagerMenuAction.delete,
                                      child: ListTile(
                                        leading: Icon(Icons.delete, size: 20, color: Colors.red),
                                        title: Text('Delete', style: TextStyle(color: Colors.red)),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showManagerDetailsDialog(UserModel manager) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.badge, color: colorScheme.primary, size: 40),
          title: const Text('Store Manager Details', style: TextStyle(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(Icons.person, 'Name', manager.fullName),
                _buildDetailRow(Icons.email, 'Email', manager.email),
                _buildDetailRow(Icons.phone, 'Phone', manager.phoneNum ?? 'Not set'),
                _buildDetailRow(Icons.security, 'Auth Type', manager.authMethod?.toUpperCase() ?? 'STANDARD'),
                _buildDetailRow(Icons.fingerprint, 'ID', manager.accountId),
                if (manager.storeId != null && manager.storeId!.isNotEmpty)
                  _buildDetailRow(Icons.store, 'Store ID', manager.storeId!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showAddManagerDialog() {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final storeIdCtrl = TextEditingController();

    bool isGoogleAuth = false;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final colorScheme = Theme.of(context).colorScheme;

          return AlertDialog(
            icon: Icon(Icons.person_add, color: colorScheme.primary, size: 40),
            title: const Text('Create Store Manager', style: TextStyle(fontWeight: FontWeight.bold)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Auth Method Toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setDialogState(() => isGoogleAuth = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !isGoogleAuth ? colorScheme.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Standard (Pass)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: !isGoogleAuth ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setDialogState(() => isGoogleAuth = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isGoogleAuth ? colorScheme.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Google Auth',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isGoogleAuth ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    TextFormField(
                      controller: emailCtrl,
                      decoration: InputDecoration(
                        labelText: isGoogleAuth ? 'Gmail Address' : 'Email Address',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        hintText: isGoogleAuth ? 'example@gmail.com' : 'manager@rcms.vn',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 12),
                    if (!isGoogleAuth) ...[
                      TextFormField(
                        controller: passwordCtrl,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                        ),
                        obscureText: true,
                        enabled: !isLoading,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: storeIdCtrl,
                      decoration: InputDecoration(
                        labelText: 'Store ID (optional)',
                        prefixIcon: const Icon(Icons.store),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                      enabled: !isLoading,
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            actions: [
              if (!isLoading)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              FilledButton.icon(
                icon: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check),
                onPressed: isLoading ? null : () async {
                  if (emailCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Email and Full Name are required')),
                    );
                    return;
                  }
                  
                  if (!isGoogleAuth && passwordCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password is required for Standard account')),
                    );
                    return;
                  }

                  setDialogState(() => isLoading = true);

                  try {
                    String? newUid;
                    
                    if (!isGoogleAuth) {
                       // Create Real Auth Account only if Standard
                       newUid = await _authService.createAccountWithoutLogin(
                        emailCtrl.text.trim(),
                        passwordCtrl.text,
                      );
                      if (newUid == null) throw Exception("Failed to create Auth account.");
                    }

                    // Generate custom ID MGR_xxx
                    final customId = await _generateManagerId();

                    // Save to Firestore
                    await _firestoreService.db.collection('users').doc(customId).set({
                      'email': emailCtrl.text.trim(),
                      'full_name': nameCtrl.text.trim(),
                      'role': 'store_manager',
                      'phone_number': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                      'store_id': storeIdCtrl.text.trim().isEmpty ? null : storeIdCtrl.text.trim(),
                      'auth_method': isGoogleAuth ? 'google' : 'standard',
                      'auth_uid': newUid, // will be null for Google accounts until they sign in
                      'created_at': FieldValue.serverTimestamp(),
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Store Manager account created successfully')),
                      );
                    }
                  } catch (e) {
                    setDialogState(() => isLoading = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                label: Text(isLoading ? 'Creating...' : 'Create Account'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditManagerDialog(UserModel manager) {
    final nameCtrl = TextEditingController(text: manager.fullName);
    final phoneCtrl = TextEditingController(text: manager.phoneNum ?? '');
    final storeIdCtrl = TextEditingController(text: manager.storeId ?? '');

    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final colorScheme = Theme.of(context).colorScheme;

          return AlertDialog(
            icon: Icon(Icons.manage_accounts, color: colorScheme.primary, size: 40),
            title: const Text('Edit Store Manager', style: TextStyle(fontWeight: FontWeight.bold)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: manager.email,
                      decoration: InputDecoration(
                        labelText: 'Email Address (Cannot change)',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                      enabled: false,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: storeIdCtrl,
                      decoration: InputDecoration(
                        labelText: 'Store ID',
                        prefixIcon: const Icon(Icons.store),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                      enabled: !isLoading,
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            actions: [
              if (!isLoading)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              FilledButton.icon(
                icon: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                onPressed: isLoading ? null : () async {
                  if (nameCtrl.text.trim().isEmpty) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
                     return;
                  }

                  setDialogState(() => isLoading = true);

                  try {
                    await _firestoreService.db.collection('users').doc(manager.accountId).update({
                      'full_name': nameCtrl.text.trim(),
                      'phone_number': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                      'store_id': storeIdCtrl.text.trim().isEmpty ? null : storeIdCtrl.text.trim(),
                      'updated_at': FieldValue.serverTimestamp(),
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Updated successfully')),
                      );
                    }
                  } catch (e) {
                    setDialogState(() => isLoading = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                label: Text(isLoading ? 'Saving...' : 'Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(UserModel manager) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.warning, color: Colors.red, size: 40),
          title: const Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to permanently delete the account for ${manager.fullName}? This action cannot be undone and will revoke their access.'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                try {
                  // Note: Firebase Auth account isn't deleted automatically here without Cloud Functions or Auth Admin SDK.
                  // For MVP, we delete the Firestore doc which effectively strips off their role access.
                  await _firestoreService.db.collection('users').doc(manager.accountId).delete();

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Store Manager deleted')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  /// Tự động sinh ID MGR_001, MGR_002... dựa trên các record hiện có
  Future<String> _generateManagerId() async {
    try {
      final snapshot = await _firestoreService.db
          .collection('users')
          .where('role', isEqualTo: 'store_manager')
          .get();

      int maxId = 0;
      for (var doc in snapshot.docs) {
        final id = doc.id;
        if (id.startsWith('MGR_')) {
          final numPart = id.substring(4);
          final num = int.tryParse(numPart);
          if (num != null && num > maxId) {
            maxId = num;
          }
        }
      }

      final nextId = maxId + 1;
      return 'MGR_${nextId.toString().padLeft(3, '0')}';
    } catch (e) {
      // Fallback in case of error (dù hơi hiếm)
      return 'MGR_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    }
  }
}
