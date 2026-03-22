import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/store_model.dart';
import '../widgets/admin_app_bar.dart';

class LowStockMonitorScreen extends StatefulWidget {
  const LowStockMonitorScreen({super.key});

  @override
  State<LowStockMonitorScreen> createState() => _LowStockMonitorScreenState();
}

class _LowStockMonitorScreenState extends State<LowStockMonitorScreen> {
  int _threshold = 50;
  final TextEditingController _thresholdController = TextEditingController(text: '50');

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const AdminAppBar(),
      body: Column(
        children: [
          // Filter Header
          Container(
            padding: const EdgeInsets.all(16),
            color: colorScheme.surfaceContainerLow,
            child: Row(
              children: [
                const Icon(Icons.filter_list),
                const SizedBox(width: 12),
                const Text('Stock Threshold:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  height: 40,
                  child: TextField(
                    controller: _thresholdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onSubmitted: (value) {
                      final val = int.tryParse(value);
                      if (val != null) {
                        setState(() => _threshold = val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    final val = int.tryParse(_thresholdController.text);
                    if (val != null) {
                      setState(() => _threshold = val);
                    }
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),

          // Monitor List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('stores').snapshots(),
              builder: (context, storesSnap) {
                if (storesSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final stores = storesSnap.data?.docs ?? [];
                if (stores.isEmpty) {
                  return const Center(child: Text('No stores found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: stores.length,
                  itemBuilder: (context, index) {
                    final storeDoc = stores[index];
                    final store = StoreModel.fromFirestore(storeDoc);
                    return _buildStoreSection(context, store);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSection(BuildContext context, StoreModel store) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('inventory')
          .where('store_id', isEqualTo: store.storeId)
          .where('stock', isLessThan: _threshold)
          .snapshots(),
      builder: (context, inventorySnap) {
        if (!inventorySnap.hasData) return const SizedBox.shrink();
        
        final items = inventorySnap.data!.docs;
        if (items.isEmpty) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        store.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${items.length} Alerts',
                        style: TextStyle(
                          color: colorScheme.onErrorContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index].data();
                  final stock = item['stock'] ?? 0;
                  final sku = item['product_sku'] ?? 'Unknown';
                  
                  return ListTile(
                    dense: true,
                    title: Text('SKU: $sku', style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Text(
                      '$stock Units',
                      style: TextStyle(
                        color: stock < 10 ? Colors.red : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: LinearProgressIndicator(
                      value: stock / _threshold,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      color: stock < 10 ? Colors.red : Colors.orange,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
