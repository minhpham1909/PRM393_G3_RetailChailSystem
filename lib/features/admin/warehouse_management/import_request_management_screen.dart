import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/excel_export_service.dart';
import '../../../core/services/printing_service.dart';
import '../../../core/models/stock_request_model.dart';
import '../widgets/admin_app_bar.dart';

class ImportRequestManagementScreen extends StatefulWidget {
  const ImportRequestManagementScreen({super.key});

  @override
  State<ImportRequestManagementScreen> createState() =>
      _ImportRequestManagementScreenState();
}

class _ImportRequestManagementScreenState extends State<ImportRequestManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ExcelExportService _excelService = ExcelExportService();
  final PrintingService _printingService = PrintingService();
  String _filterStatus = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AdminAppBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.db
            .collection('stock_requests')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.hasData
              ? snapshot.data!.docs.map((doc) => StockRequest.fromFirestore(doc)).toList()
              : [];

          final pending = requests.where((r) => r.status == 'pending').length;
          final approved = requests.where((r) => r.status == 'approved').length;
          final rejected = requests.where((r) => r.status == 'rejected').length;

          final filtered = _filterStatus == 'all'
              ? requests
              : requests.where((r) => r.status == _filterStatus).toList();

          return SingleChildScrollView(
            child: Column(
              children: [
                // Summary Cards
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          context,
                          'PENDING',
                          pending.toString(),
                          Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          context,
                          'APPROVED',
                          approved.toString(),
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          context,
                          'REJECTED',
                          rejected.toString(),
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                // Filter Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildFilterChip('All', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Pending', 'pending'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Approved', 'approved'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Rejected', 'rejected'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Requests List
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('No stock import requests',
                        style: Theme.of(context).textTheme.bodyLarge),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('REQUESTS (${filtered.length})',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: Colors.grey[600])),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final request = filtered[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: _buildStatusIcon(request.status),
                                title: Text('Request from ${request.storeId}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ID: ${request.requestId}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      DateFormat('dd/MM/yyyy HH:mm')
                                          .format(request.createdAt),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                trailing: _buildStatusBadge(request.status),
                                onTap: () => _showRequestDetailsDialog(request),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  )),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filterStatus = value),
    );
  }

  Widget _buildStatusIcon(String status) {
    if (status == 'approved') {
      return Container(
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(8),
        child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
      );
    } else if (status == 'rejected') {
      return Container(
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(8),
        child: const Icon(Icons.cancel, color: Colors.red, size: 24),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(8),
      child: const Icon(Icons.hourglass_empty, color: Colors.amber, size: 24),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor, textColor;
    String text;

    switch (status) {
      case 'approved':
        bgColor = Colors.green;
        textColor = Colors.white;
        text = 'Approved';
        break;
      case 'rejected':
        bgColor = Colors.red;
        textColor = Colors.white;
        text = 'Rejected';
        break;
      default:
        bgColor = Colors.amber;
        textColor = Colors.black87;
        text = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  void _showRequestDetailsDialog(StockRequest request) {
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
                    Text('Request details',
                        style: Theme.of(context).textTheme.titleLarge),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _excelService.exportStockRequestToExcel(request: request),
                      icon: const Icon(Icons.file_download, size: 18),
                      label: const Text('Excel', style: TextStyle(fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: () => _printingService.printStockRequestInvoice(request: request),
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Invoice', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const Divider(),
                _buildDetailRow('ID:', request.requestId),
                _buildDetailRow('Store:', request.storeId),
                _buildDetailRow('Priority:', request.priority),
                _buildDetailRow('Status:', request.status.toUpperCase()),
                _buildDetailRow('Created at:', DateFormat('dd/MM/yyyy HH:mm').format(request.createdAt)),
                _buildDetailRow('Notes:', request.notes),
                const SizedBox(height: 16),
                Text('Requested items (${request.items.length}):',
                    style: Theme.of(context).textTheme.titleMedium),
                const Divider(),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: request.items.length,
                  itemBuilder: (context, index) {
                    final item = request.items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['product_name'] ?? '?'),
                                Text('SKU: ${item['product_sku'] ?? '?'}',
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('x${item['quantity']}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (request.status == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _rejectRequest(request);
                          },
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _approveRequest(request);
                          },
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  )
                else
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

  void _approveRequest(StockRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm approval'),
        content: Text('Are you sure you want to approve request ${request.requestId}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await _firestoreService.db
                    .collection('stock_requests')
                    .doc(request.requestId)
                    .update({'status': 'approved', 'approved_at': Timestamp.now()});
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Request approved')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _rejectRequest(StockRequest request) {
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Request: ${request.requestId}'),
            const SizedBox(height: 16),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Rejection reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await _firestoreService.db
                    .collection('stock_requests')
                    .doc(request.requestId)
                    .update({
                  'status': 'rejected',
                  'notes': notesCtrl.text.isNotEmpty
                      ? '${request.notes}\n[Rejected: ${notesCtrl.text}]'
                      : request.notes,
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Request rejected')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
