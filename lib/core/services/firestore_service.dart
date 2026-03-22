import 'package:cloud_firestore/cloud_firestore.dart';

/// Dịch vụ Firestore dùng chung cho toàn bộ ứng dụng
/// Cung cấp các phương thức CRUD cơ bản cho mọi collection
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Lấy instance Firestore (dùng khi cần truy vấn tùy chỉnh)
  FirebaseFirestore get db => _db;

  // ==================== CRUD CHUNG ====================

  /// Lấy tất cả document trong một collection
  Future<QuerySnapshot> getCollection(String collection) {
    return _db.collection(collection).get();
  }

  /// Lấy document theo ID
  Future<DocumentSnapshot> getDocument(String collection, String docId) {
    return _db.collection(collection).doc(docId).get();
  }

  /// Thêm document mới (tự động tạo ID)
  Future<DocumentReference> addDocument(
    String collection,
    Map<String, dynamic> data,
  ) {
    return _db.collection(collection).add(data);
  }

  /// Tạo/cập nhật document với ID chỉ định
  Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data, {
    bool merge = true,
  }) {
    return _db
        .collection(collection)
        .doc(docId)
        .set(data, SetOptions(merge: merge));
  }

  /// Cập nhật document
  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) {
    return _db.collection(collection).doc(docId).update(data);
  }

  /// Xóa document
  Future<void> deleteDocument(String collection, String docId) {
    return _db.collection(collection).doc(docId).delete();
  }

  // ==================== TRUY VẤN NÂNG CAO ====================

  /// Lắng nghe thay đổi realtime của collection (dùng cho StreamBuilder)
  Stream<QuerySnapshot> streamCollection(String collection) {
    return _db.collection(collection).snapshots();
  }

  /// Lắng nghe thay đổi realtime của document
  Stream<DocumentSnapshot> streamDocument(String collection, String docId) {
    return _db.collection(collection).doc(docId).snapshots();
  }

  /// Truy vấn collection có điều kiện lọc
  Query<Map<String, dynamic>> queryCollection(
    String collection, {
    String? field,
    dynamic isEqualTo,
    dynamic isLessThan,
    dynamic isGreaterThan,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _db.collection(collection);

    if (field != null && isEqualTo != null) {
      query = query.where(field, isEqualTo: isEqualTo);
    }
    if (field != null && isLessThan != null) {
      query = query.where(field, isLessThan: isLessThan);
    }
    if (field != null && isGreaterThan != null) {
      query = query.where(field, isGreaterThan: isGreaterThan);
    }
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    if (limit != null) {
      query = query.limit(limit);
    }

    return query;
  }

  // ==================== OPERATIONALS ====================

  /// Confirms receipt of a stock request.
  /// Updates request status to 'received' and increments branch inventory.
  Future<void> confirmStockRequestReceipt(String requestId, String storeId, List<dynamic> items) async {
    return _db.runTransaction((transaction) async {
      // 1. Update Request Status
      final requestRef = _db.collection('stock_requests').doc(requestId);
      transaction.update(requestRef, {
        'status': 'received',
        'received_at': FieldValue.serverTimestamp(),
      });

      // 2. Update Inventory for each item
      for (final item in items) {
        final productSku = item['product_sku'] ?? item['sku'];
        final quantity = (item['quantity'] ?? 0) as num;

        // Find inventory record for this store and product SKU
        final inventoryQuery = await _db.collection('inventory')
            .where('store_id', isEqualTo: storeId)
            .where('product_sku', isEqualTo: productSku)
            .limit(1)
            .get();

        if (inventoryQuery.docs.isNotEmpty) {
          final inventoryRef = inventoryQuery.docs.first.reference;
          transaction.update(inventoryRef, {
            'stock': FieldValue.increment(quantity),
            'last_updated': FieldValue.serverTimestamp(),
          });
        } else {
          // If no inventory record exists, create one (unlikely but safe)
          final newInventoryRef = _db.collection('inventory').doc();
          transaction.set(newInventoryRef, {
            'store_id': storeId,
            'product_sku': productSku,
            'stock': quantity,
            'last_updated': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }
}
