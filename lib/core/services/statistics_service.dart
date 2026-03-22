import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class StatisticsService {
  final FirestoreService _firestoreService = FirestoreService();

  /// Aggregates revenue for all stores for a specific day.
  /// This sums up all 'paid' orders for the given date and saves to 'daily_stats'.
  Future<void> aggregateDailyRevenue(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // 1. Fetch all 'paid' orders for this day
    final ordersSnap = await _firestoreService.db
        .collection('orders')
        .where('status', isEqualTo: 'paid')
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('created_at', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    if (ordersSnap.docs.isEmpty) return;

    // 2. Group orders by store_id
    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> storeOrders = {};
    for (var doc in ordersSnap.docs) {
      final data = doc.data();
      final storeId = data['store_id'] ?? 'unknown';
      storeOrders.putIfAbsent(storeId, () => []).add(doc);
    }

    // 3. Calculate stats for each store and save
    final batch = _firestoreService.db.batch();
    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    for (var storeId in storeOrders.keys) {
      final docs = storeOrders[storeId]!;
      double totalRevenue = 0;
      int orderCount = 0;

      for (var doc in docs) {
        final data = doc.data();
        totalRevenue += (data['total_amount'] ?? 0) as num;
        orderCount++;
      }

      final statDocId = '${dateKey}_$storeId';
      final statRef = _firestoreService.db.collection('daily_stats').doc(statDocId);

      batch.set(statRef, {
        'date': Timestamp.fromDate(startOfDay),
        'date_key': dateKey,
        'store_id': storeId,
        'revenue': totalRevenue,
        'order_count': orderCount,
        'last_updated': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Helper to get aggregated data for a range
  Stream<QuerySnapshot> getDailyStats(DateTime start, DateTime end, {String? storeId}) {
    Query query = _firestoreService.db
        .collection('daily_stats')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true);

    if (storeId != null && storeId != 'ALL') {
      query = query.where('store_id', isEqualTo: storeId);
    }

    return query.snapshots();
  }
}
