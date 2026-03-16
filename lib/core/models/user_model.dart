import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho tài khoản người dùng trong hệ thống
/// Dùng chung cho cả 3 actor: System Admin, Store Manager, Staff
class UserModel {
  final String accountId;
  final String email;
  final String fullName;
  final String role; // 'admin', 'manager', 'staff'
  final String? storeId; // Chỉ có với Store Manager và Staff
  final bool isActive;

  UserModel({
    required this.accountId,
    required this.email,
    required this.fullName,
    required this.role,
    this.storeId,
    this.isActive = true,
  });

  /// Chuyển đổi từ Firestore document sang UserModel
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      accountId: doc.id,
      email: data['email'] ?? '',
      fullName: data['full_name'] ?? '',
      role: data['role'] ?? 'staff',
      storeId: data['store_id'],
      isActive: data['is_active'] ?? true,
    );
  }

  /// Chuyển đổi UserModel sang Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'full_name': fullName,
      'role': role,
      'store_id': storeId,
      'is_active': isActive,
    };
  }

  /// Tạo bản sao UserModel với các trường được cập nhật
  UserModel copyWith({
    String? accountId,
    String? email,
    String? fullName,
    String? role,
    String? storeId,
    bool? isActive,
  }) {
    return UserModel(
      accountId: accountId ?? this.accountId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      storeId: storeId ?? this.storeId,
      isActive: isActive ?? this.isActive,
    );
  }
}
