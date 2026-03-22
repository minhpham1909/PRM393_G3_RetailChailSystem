import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/stock_request_model.dart';

class ExcelExportService {
  /// Exports revenue data to an Excel file.
  Future<void> exportRevenueToExcel({
    required List<Map<String, dynamic>> data,
    required String fileName,
    String? storeName,
    String? managerName,
  }) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Revenue Report'];
    excel.delete('Sheet1'); // Remove default sheet

    // Add Metadata Header if provided
    if (storeName != null || managerName != null) {
      if (storeName != null) sheetObject.appendRow([TextCellValue('Store:'), TextCellValue(storeName)]);
      if (managerName != null) sheetObject.appendRow([TextCellValue('Seller:'), TextCellValue(managerName)]);
      sheetObject.appendRow([TextCellValue('Export Date:'), TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()))]);
      sheetObject.appendRow([]); // Spacer
    }

    // Add Headers
    List<String> headers = ['Period', 'Revenue (VND)', 'Orders Count', 'Store Name'];
    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

    // Add Data Rows
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VND');
    
    for (var row in data) {
      sheetObject.appendRow([
        TextCellValue(row['period']?.toString() ?? ''),
        TextCellValue(currencyFormat.format(row['revenue'] ?? 0)),
        IntCellValue(row['count'] ?? 0),
        TextCellValue(row['storeName'] ?? 'All Stores'),
      ]);
    }

    await _saveExcel(excel, fileName);
  }

  /// Exports detailed invoice data to an Excel file.
  Future<void> exportDetailedInvoicesToExcel({
    required List<Map<String, dynamic>> data,
    required String fileName,
    required String storeName,
    required String managerName,
  }) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Detailed Revenue'];
    excel.delete('Sheet1');

    // Add Metadata Header
    sheetObject.appendRow([TextCellValue('Store:'), TextCellValue(storeName)]);
    sheetObject.appendRow([TextCellValue('Seller:'), TextCellValue(managerName)]);
    sheetObject.appendRow([TextCellValue('Export Date:'), TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()))]);
    sheetObject.appendRow([]); // Spacer

    // Add Table Headers
    List<String> headers = ['Order ID', 'Date/Time', 'Payment Method', 'Amount (VND)', 'Status'];
    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VND');

    for (var row in data) {
      sheetObject.appendRow([
        TextCellValue(row['order_id']?.toString() ?? ''),
        TextCellValue(row['created_at']?.toString() ?? ''),
        TextCellValue(row['payment_method']?.toString() ?? ''),
        TextCellValue(currencyFormat.format(row['total_amount'] ?? 0)),
        TextCellValue(row['status']?.toString() ?? ''),
      ]);
    }

    await _saveExcel(excel, fileName);
  }

  /// Exports inventory data to an Excel file.
  Future<void> exportInventoryToExcel({
    required List<Map<String, dynamic>> data,
    required String fileName,
    String? storeName,
    String? managerName,
  }) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Inventory Report'];
    excel.delete('Sheet1');

    // Add Metadata Header if provided
    if (storeName != null || managerName != null) {
      if (storeName != null) sheetObject.appendRow([TextCellValue('Store:'), TextCellValue(storeName)]);
      if (managerName != null) sheetObject.appendRow([TextCellValue('Seller:'), TextCellValue(managerName)]);
      sheetObject.appendRow([TextCellValue('Export Date:'), TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()))]);
      sheetObject.appendRow([]); // Spacer
    }

    // Add Headers
    List<String> headers = ['SKU', 'Product Name', 'Category', 'Stock', 'Price (VND)', 'Status'];
    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

    // Add Data Rows
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VND');

    for (var row in data) {
      final stock = row['stock'] ?? 0;
      String status = 'In Stock';
      if (stock <= 0) status = 'Out of Stock';
      else if (stock < 5) status = 'Low Stock';

      sheetObject.appendRow([
        TextCellValue(row['sku']?.toString() ?? ''),
        TextCellValue(row['name']?.toString() ?? ''),
        TextCellValue(row['category']?.toString() ?? ''),
        IntCellValue(stock),
        TextCellValue(currencyFormat.format(row['price'] ?? 0)),
        TextCellValue(status),
      ]);
    }

    await _saveExcel(excel, fileName);
  }

  /// Exports a specific stock request to an Excel file.
  Future<void> exportStockRequestToExcel({
    required StockRequest request,
    String? storeName,
    String? managerName,
  }) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Stock Request Details'];
    excel.delete('Sheet1');

    // Header Info
    final friendlyId = request.requestId.length > 6 
        ? '#${request.requestId.substring(request.requestId.length - 6).toUpperCase()}' 
        : '#${request.requestId}';
    
    sheetObject.appendRow([TextCellValue('Request ID:'), TextCellValue(friendlyId)]);
    sheetObject.appendRow([TextCellValue('Store:'), TextCellValue(storeName ?? request.storeId)]);
    sheetObject.appendRow([TextCellValue('Manager:'), TextCellValue(managerName ?? request.managerId)]);
    sheetObject.appendRow([TextCellValue('Status:'), TextCellValue(request.status.toUpperCase())]);
    sheetObject.appendRow([TextCellValue('Priority:'), TextCellValue(request.priority)]);
    sheetObject.appendRow([TextCellValue('Date:'), TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(request.createdAt))]);
    if (request.notes.isNotEmpty) {
      sheetObject.appendRow([TextCellValue('Notes:'), TextCellValue(request.notes)]);
    }
    sheetObject.appendRow([]); // Spacer

    // Items Table
    sheetObject.appendRow([
      TextCellValue('SKU'),
      TextCellValue('Product Name'),
      TextCellValue('Quantity'),
    ]);

    for (var item in request.items) {
      sheetObject.appendRow([
        TextCellValue(item['product_sku']?.toString() ?? ''),
        TextCellValue(item['product_name']?.toString() ?? ''),
        IntCellValue(item['quantity'] ?? 0),
      ]);
    }

    final timestamp = DateFormat('yyyyMMdd').format(DateTime.now());
    final fileName = 'Request_${friendlyId.replaceAll('#', '')}_$timestamp';
    await _saveExcel(excel, fileName);
  }

  /// Helper to save the excel file
  Future<void> _saveExcel(Excel excel, String fileName) async {
    final bytes = excel.save();
    if (bytes == null) return;

    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Select Save Location',
        fileName: '$fileName.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile != null) {
        if (!outputFile.endsWith('.xlsx')) {
          outputFile += '.xlsx';
        }
        final file = File(outputFile);
        await file.writeAsBytes(bytes);
      }
    } else {
      // Fallback for Mobile/Web using file_saver
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    }
  }
}
