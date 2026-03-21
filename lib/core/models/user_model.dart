import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho tài khoản người dùng trong hệ thống
/// Dùng chung cho cả 2 actor: System Admin, Store Manager
class UserModel {
  final String accountId;
  final String email;
  final String fullName;
  final String role; // 'admin', 'store_manager'
  final String? phoneNum;
  final String? authMethod; // 'standard', 'google'
  final String? storeId; // Chỉ có với Store Manager

  UserModel({
    required this.accountId,
    required this.email,
    required this.fullName,
    required this.role,
    this.phoneNum,
    this.authMethod,
    this.storeId,
  });

  /// Chuyển đổi từ Firestore document sang UserModel
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      accountId: doc.id,
      email: data['email'] ?? '',
      fullName: data['full_name'] ?? '',
      role: data['role'] ?? 'store_manager',
      phoneNum: data['phone_number'],
      authMethod: data['auth_method'],
      storeId: data['store_id'],
    );
  }

  /// Chuyển đổi UserModel sang Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'full_name': fullName,
      'role': role,
      'phone_number': phoneNum,
      'auth_method': authMethod,
      'store_id': storeId,
    };
  }

  /// Tạo bản sao UserModel với các trường được cập nhật
  UserModel copyWith({
    String? accountId,
    String? email,
    String? fullName,
    String? role,
    String? phoneNum,
    String? authMethod,
    String? storeId,
  }) {
    return UserModel(
      accountId: accountId ?? this.accountId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phoneNum: phoneNum ?? this.phoneNum,
      authMethod: authMethod ?? this.authMethod,
      storeId: storeId ?? this.storeId,
    );
  }
}
