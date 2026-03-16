import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho sản phẩm trong danh mục Master Data
/// Dùng chung cho Admin (quản lý), Manager (xem tồn kho), Staff (bán hàng)
class ProductModel {
  final String productId;
  final String sku;
  final String name;
  final String category;
  final double price;
  final String? image;
  final int stock;

  ProductModel({
    required this.productId,
    required this.sku,
    required this.name,
    required this.category,
    required this.price,
    this.image,
    required this.stock,
  });

  /// Chuyển đổi từ Firestore document sang ProductModel
  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      productId: doc.id,
      sku: data['sku'] ?? '',
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      image: data['image'],
      stock: (data['stock'] ?? 0).toInt(),
    );
  }

  /// Chuyển đổi ProductModel sang Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'sku': sku,
      'name': name,
      'category': category,
      'price': price,
      'image': image,
      'stock': stock,
    };
  }

  /// Xác định trạng thái tồn kho dựa trên số lượng
  String get stockStatus {
    if (stock <= 0) return 'Out of Stock';
    if (stock <= 5) return 'Critical';
    if (stock <= 20) return 'Low Stock';
    return 'Stable';
  }

  /// Tạo bản sao ProductModel với các trường được cập nhật
  ProductModel copyWith({
    String? productId,
    String? sku,
    String? name,
    String? category,
    double? price,
    String? image,
    int? stock,
  }) {
    return ProductModel(
      productId: productId ?? this.productId,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      image: image ?? this.image,
      stock: stock ?? this.stock,
    );
  }
}
