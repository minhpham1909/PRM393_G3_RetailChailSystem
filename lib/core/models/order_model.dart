import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper function to robustly parse date data from Firestore.
/// It can handle both Timestamp and ISO 8601 String formats.
DateTime? _parseDate(dynamic dateData) {
  if (dateData == null) return null;
  if (dateData is Timestamp) {
    return dateData.toDate();
  } else if (dateData is String) {
    // Use tryParse to avoid crashing on invalid string formats.
    return DateTime.tryParse(dateData);
  }
  // Return null if the data is of an unexpected type.
  return null;
}

class OrderModel {
  final String orderId;
  final String managerId;
  final String storeId;
  final double totalAmount;
  final String paymentMethod;
  final DateTime createdAt;
  final String orderType;
  final String status;
  final List<OrderDetailModel> items;
  final DateTime? expectedDate; // For stock requests

  OrderModel({
    required this.orderId,
    required this.managerId,
    required this.storeId,
    required this.totalAmount,
    required this.paymentMethod,
    required this.createdAt,
    required this.orderType,
    required this.status,
    required this.items,
    this.expectedDate,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      orderId: doc.id,
      managerId: data['manager_id'] ?? '',
      storeId: data['store_id'] ?? '',
      totalAmount: (data['total_amount'] ?? 0.0).toDouble(),
      paymentMethod: data['payment_method'] ?? 'N/A',
      // Use the robust parser for date fields
      createdAt: _parseDate(data['created_at']) ?? DateTime.now(),
      expectedDate: _parseDate(data['expected_date']),
      orderType: data['order_type'] ?? 'sale',
      status: data['status'] ?? 'unknown',
      items: (data['items'] as List<dynamic>?)
              ?.map((itemData) => OrderDetailModel.fromMap(itemData, doc.id))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'manager_id': managerId,
      'store_id': storeId,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'created_at': Timestamp.fromDate(createdAt),
      'order_type': orderType,
      'status': status,
      'items': items.map((item) => item.toMap()).toList(),
      // Ensure expectedDate is also stored as a Timestamp
      if (expectedDate != null) 'expected_date': Timestamp.fromDate(expectedDate!),
    };
  }
}

class OrderDetailModel {
  final String orderId;
  final String productId;
  final int quantity;
  final double unitPrice;
  double get lineTotal => quantity * unitPrice;

  OrderDetailModel({
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });

  factory OrderDetailModel.fromMap(Map<String, dynamic> map, String orderId) {
    return OrderDetailModel(
      orderId: orderId,
      productId: map['product_id'] ?? '',
      quantity: (map['quantity'] ?? 0).toInt(),
      unitPrice: (map['unit_price'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }
}