import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho một cửa hàng (chi nhánh) trong chuỗi bán lẻ
class StoreModel {
  final String storeId;
  final String name;
  final String address;
  final String phoneNum;
  final String managerId;

  StoreModel({
    required this.storeId,
    required this.name,
    required this.address,
    this.phoneNum = '',
    this.managerId = '',
  });

  /// Chuyển đổi từ Firestore document sang StoreModel
  factory StoreModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoreModel(
      storeId: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      phoneNum: data['store_phoneNum'] ?? '',
      managerId: data['manager_id'] ?? '',
    );
  }

  /// Chuyển đổi StoreModel sang Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'store_phoneNum': phoneNum,
      'manager_id': managerId,
    };
  }
}
