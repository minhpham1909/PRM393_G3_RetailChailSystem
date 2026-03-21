import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/store_model.dart';
import '../../../../core/services/firestore_service.dart';
import '../widgets/admin_app_bar.dart';
import 'store_inventory_screen.dart';

class StoreManagementScreen extends StatefulWidget {
  const StoreManagementScreen({super.key});

  @override
  State<StoreManagementScreen> createState() => _StoreManagementScreenState();
}

class _StoreManagementScreenState extends State<StoreManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  void _showAddStoreDialog() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String? selectedManagerId;

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.storefront, color: colorScheme.primary, size: 40),
          title: const Text('Add New Store', style: TextStyle(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Store Name',
                      prefixIcon: const Icon(Icons.store_mall_directory),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: addressCtrl,
                    decoration: InputDecoration(
                      labelText: 'Address',
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _firestoreService.db
                        .collection('users')
                        .where('role', isEqualTo: 'store_manager')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final managers = snapshot.data!.docs;
                      return DropdownButtonFormField<String>(
                        value: selectedManagerId,
                        decoration: InputDecoration(
                          labelText: 'Assign Manager',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                        ),
                        items: managers.map((doc) {
                          final data = doc.data();
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text('${data['full_name']} (${doc.id})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          selectedManagerId = val;
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              onPressed: () async {
                if (nameCtrl.text.isEmpty || addressCtrl.text.isEmpty) return;

                final String newStoreId = 'STORE_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

                await _firestoreService.db.collection('stores').doc(newStoreId).set({
                  'store_id': newStoreId,
                  'name': nameCtrl.text,
                  'address': addressCtrl.text,
                  'store_phoneNum': phoneCtrl.text,
                  'manager_id': selectedManagerId ?? '',
                  'status': 'active',
                  'created_at': FieldValue.serverTimestamp(),
                });

                if (selectedManagerId != null) {
                  await _firestoreService.db.collection('users').doc(selectedManagerId).update({
                    'store_id': newStoreId,
                  });
                }

                if (context.mounted) Navigator.pop(context);
              },
              label: const Text('Add Store'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const AdminAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStoreDialog,
        icon: const Icon(Icons.add_business),
        label: const Text('Add Store'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.db.collection('stores').orderBy('created_at').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final stores = snapshot.data?.docs ?? [];

          if (stores.isEmpty) {
            return const Center(child: Text('No stores found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: stores.length,
            itemBuilder: (context, index) {
              final data = stores[index].data();
              final storeModel = StoreModel.fromFirestore(stores[index]);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.storefront, color: colorScheme.onPrimaryContainer),
                  ),
                  title: Text(
                    storeModel.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${storeModel.address}\nManager: ${data['manager_id'] ?? 'N/A'}\nPhone: ${data['store_phoneNum'] ?? 'N/A'}',
                  ),
                  isThreeLine: true,
                  trailing: Icon(Icons.inventory_2_outlined, color: colorScheme.primary),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StoreInventoryScreen(store: storeModel),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
