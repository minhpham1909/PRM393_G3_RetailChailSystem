import 'package:cloud_firestore/cloud_firestore.dart';

class StockRequest {
  final String requestId;
  final String storeId;
  final String? storeName;
  final String managerId;
  final String? managerName;
  final String status;
  final String priority;
  final DateTime createdAt;
  final DateTime? expectedDate;
  final DateTime? approvedAt;
  final String notes;
  final List<Map<String, dynamic>> items;

  StockRequest({
    required this.requestId,
    required this.storeId,
    this.storeName,
    required this.managerId,
    this.managerName,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.expectedDate,
    this.approvedAt,
    required this.notes,
    required this.items,
  });

  factory StockRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    List<Map<String, dynamic>> parseItems(Map<String, dynamic> data) {
      final rawItems = data['items'];
      if (rawItems is List) {
        return rawItems
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList();
      }

      // Backward compatibility: manager previously wrote `products` with `sku` key.
      final rawProducts = data['products'];
      if (rawProducts is List) {
        return rawProducts
            .whereType<Map>()
            .map(
              (m) {
                final p = m.cast<String, dynamic>();
                return {
                  'product_id': p['product_id'],
                  'product_name': p['product_name'],
                  'product_sku': p['product_sku'] ?? p['sku'],
                  'quantity': p['quantity'] ?? 0,
                };
              },
            )
            .toList();
      }

      return [];
    }

    return StockRequest(
      requestId: doc.id,
      storeId: (data['store_id'] ?? data['storeId'] ?? '').toString(),
      storeName: data['store_name']?.toString(),
      managerId: (data['manager_id'] ?? data['managerId'] ?? '').toString(),
      managerName: data['manager_name']?.toString(),
      status: data['status'] ?? 'pending',
      priority: data['priority'] ?? 'Normal',
      createdAt: parseDate(data['created_at']) ?? DateTime.now(),
      expectedDate: parseDate(data['expected_date']),
      approvedAt: parseDate(data['approved_at']),
      notes: (data['notes'] ?? '').toString(),
      items: parseItems(data),
    );
  }
}
