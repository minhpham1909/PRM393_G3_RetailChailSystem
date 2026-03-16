import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../core/services/firestore_service.dart';

/// Dịch vụ tạo dữ liệu giả (Mock Data) để phục vụ việc test
/// Cập nhật: Đọc dữ liệu từ file JSON trong assets/data và đẩy lên Firebase
class MockDataService {
  final FirestoreService _firestore = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> seedMockData() async {
    try {
      print('🚀 BẮT ĐẦU SEED DỮ LIỆU TỪ ASSETS...');

      // 1. Đọc và Seed Users & Auth
      await _seedUsers();

      // 2. Đọc và Seed Các bảng dữ liệu khác
      await _seedCollection('data/stores.json', 'stores', 'store_id');
      await _seedCollection('data/warehouses.json', 'warehouses', 'warehouse_id');
      await _seedCollection('data/categories.json', 'categories', 'category_id');
      await _seedCollection('data/products.json', 'products', 'sku');
      await _seedCollection('data/orders.json', 'orders', 'order_id');
      await _seedCollection('data/stock_requests.json', 'stock_requests', 'request_id');

      // 3. Seed Inventory (Đặc thù dạng Map)
      await _seedInventory();

      print('🎉 SEED DỮ LIỆU THÀNH CÔNG!');
    } catch (e) {
      print('❌ LỖI SEED DỮ LIỆU: $e');
    }
  }

  Future<void> _seedUsers() async {
    try {
      final String jsonString = await rootBundle.loadString('data/users.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      final List<dynamic> users = jsonData['users'] ?? [];

      print('\n--- SEED USERS ---');
      WriteBatch batch = _firestore.db.batch();

      for (var user in users) {
        final email = user['email'] as String;
        final passwordStr = user['password_hash'] as String;
        final password = passwordStr.replaceFirst('hashed_', ''); // Giả lập giải mã
        final uid = user['account_id'] as String;

        // Xóa thuộc tính thừa
        final dataToSave = Map<String, dynamic>.from(user);
        dataToSave.remove('password_hash');
        
        if (dataToSave['created_at'] != null) {
           dataToSave['created_at'] = Timestamp.fromDate(DateTime.parse(dataToSave['created_at']));
        }

        // Tạo tài khoản Firebase Auth
        try {
          // Lưu ý: Việc này trên client sẽ tự đăng nhập user mới tạo. 
          // Cần cảnh báo người dùng.
          await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          print('✅ Auth Created: $email');
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            print('⚠️ Auth Exists: $email');
          } else {
            print('❌ Auth Error cho $email: ${e.message}');
          }
        }

        // Tạo tài liệu trong collection 'users' dùng custom UID
        final docRef = _firestore.db.collection('users').doc(uid);
        batch.set(docRef, dataToSave);
      }
      
      await batch.commit();
      print('✅ Đã lưu bảng users vào Firestore');

    } catch (e) {
      print('❌ Lỗi _seedUsers: $e');
    }
  }

  Future<void> _seedCollection(String assetPath, String collectionName, String idField) async {
    try {
      final String jsonString = await rootBundle.loadString(assetPath);
      final List<dynamic> dataList = jsonDecode(jsonString);

      print('\n--- SEED $collectionName ---');
      WriteBatch batch = _firestore.db.batch();
      int counter = 0;

      for (var item in dataList) {
        final docId = item[idField];
        final docRef = docId != null 
            ? _firestore.db.collection(collectionName).doc(docId) 
            : _firestore.db.collection(collectionName).doc();

        final dataToSave = Map<String, dynamic>.from(item);
        dataToSave.remove('___comment');

        // Parse ngày tháng
        dataToSave.forEach((key, value) {
          if (value is String && value.endsWith('Z') && value.contains('T')) {
            try {
              dataToSave[key] = Timestamp.fromDate(DateTime.parse(value));
            } catch (_) {}
          }
        });

        batch.set(docRef, dataToSave);
        counter++;

        // Firestore batch limit is 500
        if (counter == 490) {
          await batch.commit();
          batch = _firestore.db.batch();
          counter = 0;
        }
      }

      await batch.commit();
      print('✅ Đã đẩy ${dataList.length} docs lên $collectionName');
    } catch (e) {
      print('⚠️ Bỏ qua $collectionName (Không tìm thấy file hoặc lỗi): $e');
    }
  }

  Future<void> _seedInventory() async {
    try {
      final String jsonString = await rootBundle.loadString('data/inventory.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      
      print('\n--- SEED INVENTORY ---');
      WriteBatch batch = _firestore.db.batch();
      int count = 0;

      jsonData.forEach((storeId, items) {
        if (storeId == '___comment') return;
        
        List<dynamic> itemList = items;
        for (var item in itemList) {
          final sku = item['product_sku'];
          final docRef = _firestore.db.collection('inventory').doc('${storeId}_$sku');
          
          final dataToSave = Map<String, dynamic>.from(item);
          dataToSave['store_id'] = storeId;
          
          batch.set(docRef, dataToSave);
          count++;
          
          if (count == 490) {
            batch.commit();
            batch = _firestore.db.batch();
            count = 0;
          }
        }
      });
      
      await batch.commit();
      print('✅ Đã lưu toàn bộ inventory');
    } catch (e) {
      print('⚠️ Lỗi _seedInventory: $e');
    }
  }

  Future<void> clearMockData() async {
    final collections = ['products', 'users', 'orders', 'categories', 'inventory', 'stock_requests', 'stores', 'warehouses'];
    for (String coll in collections) {
      final snapshot = await _firestore.db.collection(coll).get();
      WriteBatch batch = _firestore.db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('🗑️ Đã xóa $coll');
    }
  }
}
