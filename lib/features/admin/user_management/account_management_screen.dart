import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firestore_service.dart';

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
  String _searchQuery = '';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Management'),
        elevation: 0,
      ),
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
              : [];

          // Filter based on search query
          final filteredManagers = managers
              .where((m) =>
                  m.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  m.email.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();

          return SingleChildScrollView(
            child: Column(
              children: [
                // Summary Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL STORE MANAGERS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        managers.length.toString(),
                        style:
                            Theme.of(context).textTheme.displayMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
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
                        child: FilledButton.icon(
                          onPressed: () => _showAddManagerDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add new Store Manager'),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Search
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by name or email...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
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
                      style: Theme.of(context).textTheme.bodyLarge,
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
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredManagers.length,
                          itemBuilder: (context, index) {
                            final manager = filteredManagers[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    manager.fullName.isNotEmpty
                                        ? manager.fullName[0].toUpperCase()
                                        : '?',
                                  ),
                                ),
                                title: Text(manager.fullName),
                                subtitle: Text(
                                  manager.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _showManagerDetailsDialog(manager),
                                trailing: PopupMenuButton<_ManagerMenuAction>(
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
                                      child: Text('View details'),
                                    ),
                                    PopupMenuItem(
                                      value: _ManagerMenuAction.edit,
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: _ManagerMenuAction.delete,
                                      child: Text('Delete'),
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
                const SizedBox(height: 16),
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
      builder: (context) => AlertDialog(
        title: const Text('Store Manager details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Name:', manager.fullName),
              _buildDetailRow('Email:', manager.email),
              _buildDetailRow('ID:', manager.accountId),
              if (manager.storeId != null)
                _buildDetailRow('Store ID:', manager.storeId!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddManagerDialog() {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final storeIdCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add new Store Manager'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: storeIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Store ID (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (emailCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all required fields')),
                );
                return;
              }

              try {
                // Lưu vào Firestore (không tạo auth account ở đây)
                await _firestoreService.db.collection('users').add({
                  'email': emailCtrl.text.trim(),
                  'full_name': nameCtrl.text.trim(),
                  'role': 'store_manager',
                  'store_id': storeIdCtrl.text.isEmpty ? null : storeIdCtrl.text.trim(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Store Manager added successfully')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditManagerDialog(UserModel manager) {
    final emailCtrl = TextEditingController(text: manager.email);
    final nameCtrl = TextEditingController(text: manager.fullName);
    final storeIdCtrl = TextEditingController(text: manager.storeId ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Store Manager'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: storeIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Store ID',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                // Tìm document cần update
                final query = await _firestoreService.db
                    .collection('users')
                    .where('email', isEqualTo: manager.email)
                    .where('role', isEqualTo: 'store_manager')
                    .get();

                if (query.docs.isNotEmpty) {
                  await query.docs.first.reference.update({
                    'full_name': nameCtrl.text.trim(),
                    'store_id': storeIdCtrl.text.isEmpty ? null : storeIdCtrl.text.trim(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Updated successfully')),
                    );
                  }
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(UserModel manager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm delete'),
        content: Text('Are you sure you want to delete ${manager.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                // Tìm và xóa document
                final query = await _firestoreService.db
                    .collection('users')
                    .where('email', isEqualTo: manager.email)
                    .where('role', isEqualTo: 'store_manager')
                    .get();

                if (query.docs.isNotEmpty) {
                  await query.docs.first.reference.delete();

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Deleted successfully')),
                    );
                  }
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
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
