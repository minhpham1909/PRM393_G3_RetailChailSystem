import 'package:flutter/material.dart';
import '../../../core/services/mock_data_service.dart';

class ManagerSettingsScreen extends StatefulWidget {
  const ManagerSettingsScreen({super.key});

  @override
  State<ManagerSettingsScreen> createState() => _ManagerSettingsScreenState();
}

class _ManagerSettingsScreenState extends State<ManagerSettingsScreen> {
  final MockDataService _mockDataService = MockDataService();
  bool _isLoading = false;

  Future<void> _generateMockData() async {
    setState(() => _isLoading = true);
    try {
      await _mockDataService.seedMockData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mock Data Generated Successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating mock data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearMockData() async {
    setState(() => _isLoading = true);
    try {
      await _mockDataService.clearMockData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mock Data Cleared Successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing mock data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: colorScheme.surfaceContainerLowest,
      ),
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Developer Tools',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Generate Mock Data'),
            subtitle: const Text('Seed Firestore with sample products, staff, and orders.'),
            leading: const Icon(Icons.data_object),
            trailing: _isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _isLoading ? null : _generateMockData,
            tileColor: colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('Clear Mock Data'),
            subtitle: const Text('Delete all products, staff, and orders from Firestore.'),
            leading: const Icon(Icons.delete_outline),
            trailing: _isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _isLoading ? null : _clearMockData,
            iconColor: colorScheme.error,
            textColor: colorScheme.error,
            tileColor: colorScheme.errorContainer.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ],
      ),
    );
  }
}
