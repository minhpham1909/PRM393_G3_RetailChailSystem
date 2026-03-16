import 'package:flutter/material.dart';
import '../../../core/services/firestore_service.dart';

class RecentRequestsScreen extends StatefulWidget {
  const RecentRequestsScreen({super.key});

  @override
  State<RecentRequestsScreen> createState() => _RecentRequestsScreenState();
}

class _RecentRequestsScreenState extends State<RecentRequestsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Map<String, dynamic>> _recentRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentRequests();
  }

  Future<void> _loadRecentRequests() async {
    try {
      final snapshot = await _firestoreService.db
          .collection('stock_requests')
          .orderBy('created_at', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _recentRequests = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Lỗi tải yêu cầu gần đây: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Recent Requests'),
        backgroundColor: colorScheme.surfaceContainerLowest,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRecentRequests,
              child: _recentRequests.isEmpty
                  ? Center(
                      child: Text(
                        'No recent requests',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _recentRequests.length,
                      itemBuilder: (context, index) {
                        return _buildRecentRequestCard(_recentRequests[index]);
                      },
                    ),
            ),
    );
  }

  Widget _buildRecentRequestCard(Map<String, dynamic> request) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = request['status'] ?? 'pending';

    Color borderColor;
    Color badgeBg;
    Color badgeText;
    switch (status) {
      case 'in_transit':
        borderColor = colorScheme.primary.withValues(alpha: 0.4);
        badgeBg = colorScheme.primary.withValues(alpha: 0.1);
        badgeText = colorScheme.primary;
        break;
      case 'approved':
      case 'accepted':
        borderColor = colorScheme.primary.withValues(alpha: 0.4);
        badgeBg = colorScheme.primaryContainer;
        badgeText = colorScheme.onPrimaryContainer;
        break;
      case 'rejected':
        borderColor = colorScheme.error.withValues(alpha: 0.4);
        badgeBg = colorScheme.errorContainer;
        badgeText = colorScheme.error;
        break;
      default:
        borderColor = Colors.amber.withValues(alpha: 0.4);
        badgeBg = Colors.amber.shade50;
        badgeText = Colors.amber.shade700;
    }

    // Lấy ngày giờ
    String dateStr = 'Unknown date';
    if (request['created_at'] != null) {
      final dt = request['created_at'].toDate();
      dateStr = '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }

    // Danh sách sản phẩm (nếu có)
    String itemsText = '${request['total_items'] ?? 0} Items';
    if (request['items'] != null && request['items'] is List) {
      final items = request['items'] as List;
      if (items.isNotEmpty) {
        itemsText = items.map((i) => i['name'] ?? 'Item').join(', ');
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REQ-${request['id']?.toString().substring(0, 5) ?? ''}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase().replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            itemsText,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'To: ${request['source_warehouse'] ?? 'Main Warehouse'}',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              Text(
                dateStr,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
