import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho đơn hàng (giao dịch bán hàng)
/// Dùng cho Manager (nhập đơn hàng/báo cáo)
class OrderModel {
  final String orderId;
  final String managerId;
  final String storeId;
  final double totalAmount;
  final String paymentMethod; // 'Cash' hoặc 'Transfer'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String orderType; // 'sale' hoặc 'stock_request'
  final String status; // 'pending', 'paid', 'completed', 'cancelled'

  OrderModel({
    required this.orderId,
    required this.managerId,
    required this.storeId,
    required this.totalAmount,
    required this.paymentMethod,
    required this.createdAt,
    this.updatedAt,
    required this.orderType,
    this.status = 'pending',
  });

  /// Chuyển đổi từ Firestore document sang OrderModel
  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      orderId: doc.id,
      managerId: data['manager_id'] ?? '',
      storeId: data['store_id'] ?? '',
      totalAmount: (data['total_amount'] ?? 0).toDouble(),
      paymentMethod: data['payment_method'] ?? 'Cash',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      orderType: data['order_type'] ?? 'sale',
      status: data['status'] ?? 'pending',
    );
  }

  /// Chuyển đổi OrderModel sang Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'manager_id': managerId,
      'store_id': storeId,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'order_type': orderType,
      'status': status,
    };
  }
}

/// Model chi tiết từng sản phẩm trong đơn hàng
class OrderDetailModel {
  final String orderDetailId;
  final String orderId;
  final String productId;
  final int quantity;
  final double unitPrice;

  OrderDetailModel({
    required this.orderDetailId,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });

  /// Chuyển đổi từ Firestore document sang OrderDetailModel
  factory OrderDetailModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderDetailModel(
      orderDetailId: doc.id,
      orderId: data['order_id'] ?? '',
      productId: data['product_id'] ?? '',
      quantity: (data['quantity'] ?? 0).toInt(),
      unitPrice: (data['unit_price'] ?? 0).toDouble(),
    );
  }

  /// Chuyển đổi OrderDetailModel sang Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }

  /// Tính tổng tiền của dòng sản phẩm
  double get lineTotal => quantity * unitPrice;
}
