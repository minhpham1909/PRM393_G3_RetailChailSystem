import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/excel_export_service.dart';
import '../../../core/models/stock_request_model.dart';

class RecentRequestsScreen extends StatefulWidget {
  const RecentRequestsScreen({super.key});

  @override
  State<RecentRequestsScreen> createState() => _RecentRequestsScreenState();
}

class _RecentRequestsScreenState extends State<RecentRequestsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ExcelExportService _excelService = ExcelExportService();
  List<StockRequest> _recentRequests = [];
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
          _recentRequests = snapshot.docs
              .map((doc) => StockRequest.fromFirestore(doc))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load recent requests: $e');
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

  void _showRequestDetails(StockRequest request) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Request Details',
                        style: Theme.of(context).textTheme.titleLarge),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _excelService.exportStockRequestToExcel(request: request),
                  icon: const Icon(Icons.file_download, size: 18),
                  label: const Text('Export Excel', style: TextStyle(fontSize: 12)),
                ),
                const Divider(),
                _buildDetailRow('ID:', request.requestId),
                _buildDetailRow('Status:', request.status.toUpperCase().replaceAll('_', ' ')),
                _buildDetailRow('Date:', DateFormat('dd/MM/yyyy HH:mm').format(request.createdAt)),
                _buildDetailRow('Priority:', request.priority),
                _buildDetailRow('Notes:', request.notes),
                const SizedBox(height: 16),
                Text('Items (${request.items.length}):',
                    style: Theme.of(context).textTheme.titleMedium),
                const Divider(),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: request.items.length,
                  itemBuilder: (context, index) {
                    final item = request.items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['product_name'] ?? 'Unknown'),
                                Text('SKU: ${item['product_sku'] ?? '-'}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Text('x${item['quantity']}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (request.status == 'approved' || request.status == 'in_transit')
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _handleConfirmReceipt(request),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Confirm Goods Receipt'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleConfirmReceipt(StockRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Receipt'),
        content: const Text('Are you sure you have received all items in this request? This will update your store inventory.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      // Close the details dialog before processing
      Navigator.pop(context);
      
      setState(() => _isLoading = true);
      try {
        await _firestoreService.confirmStockRequestReceipt(
          request.requestId,
          request.storeId,
          request.items,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Inventory updated successfully!'), backgroundColor: Colors.green),
          );
          _loadRecentRequests();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 70, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildRecentRequestCard(StockRequest request) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = request.status;

    Color borderColor;
    Color badgeBg;
    Color badgeText;
    switch (status) {
      case 'in_transit':
        borderColor = colorScheme.primary.withOpacity(0.4);
        badgeBg = colorScheme.primary.withOpacity(0.1);
        badgeText = colorScheme.primary;
        break;
      case 'approved':
      case 'accepted':
        borderColor = colorScheme.primary.withOpacity(0.4);
        badgeBg = colorScheme.primaryContainer;
        badgeText = colorScheme.onPrimaryContainer;
        break;
      case 'rejected':
        borderColor = colorScheme.error.withOpacity(0.4);
        badgeBg = colorScheme.errorContainer;
        badgeText = colorScheme.error;
        break;
      case 'received':
        borderColor = Colors.teal.withOpacity(0.4);
        badgeBg = Colors.teal.shade50;
        badgeText = Colors.teal.shade700;
        break;
      default:
        borderColor = Colors.amber.withOpacity(0.4);
        badgeBg = Colors.amber.shade50;
        badgeText = Colors.amber.shade700;
    }

    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(request.createdAt);

    return InkWell(
      onTap: () => _showRequestDetails(request),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: borderColor, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                  'REQ-${request.requestId.substring(0, 5)}',
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
            const SizedBox(height: 6),
            ...request.items.take(2).map((item) => Text(
                  '${item['product_name']} (x${item['quantity']})',
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )),
            if (request.items.length > 2)
              Text('+ ${request.items.length - 2} more items...',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'To: Warehouse',
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
      ),
    );
  }
}
