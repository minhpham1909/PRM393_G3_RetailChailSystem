import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import 'firestore_service.dart';

class PrintingService {
  /// Hàm chính để gọi in, nhận vào dữ liệu hóa đơn
  Future<void> printReceipt({
    required OrderModel order,
    required Map<String, ProductModel> productDetails,
  }) async {
    // Lấy thông tin cửa hàng từ Firestore một cách linh động
    String storeName = 'N/A';
    String storeAddress = 'N/A';
    final storeDoc = await FirestoreService().db.collection('stores').doc(order.storeId).get();
    if (storeDoc.exists) {
      storeName = storeDoc.data()?['name'] ?? storeName;
      storeAddress = storeDoc.data()?['address'] ?? storeAddress;
    }

    // 1. Tải logo và font chữ từ assets
    final logoData = await rootBundle.load('assets/images/logo.png');
    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');

    final logo = pw.MemoryImage(logoData.buffer.asUint8List());
    final font = pw.Font.ttf(fontData);
    final boldFont = pw.Font.ttf(fontBoldData);

    // 2. Tạo nội dung PDF với các assets đã tải
    final Uint8List pdfBytes = await _generateReceiptPdf(
      logo: logo,
      font: font,
      boldFont: boldFont,
      order: order,
      storeName: storeName,
      storeAddress: storeAddress,
      productDetails: productDetails,
    );

    // 3. Sử dụng thư viện printing để hiển thị màn hình xem trước và in
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name:
          'Receipt-${order.orderId.substring(order.orderId.length - 6).toUpperCase()}',
    );
  }

  /// Hàm nội bộ để tạo file PDF từ dữ liệu
  Future<Uint8List> _generateReceiptPdf({
    required pw.ImageProvider logo,
    required pw.Font font,
    required pw.Font boldFont,
    required OrderModel order,
    required String storeName,
    required String storeAddress,
    required Map<String, ProductModel> productDetails,
  }) async {
    final pdf = pw.Document(
      // Áp dụng theme với font chữ tùy chỉnh cho toàn bộ tài liệu
      theme: pw.ThemeData.withFont(
        base: font,
        bold: boldFont,
      ),
    );

    // Tổng tiền
    final total = order.totalAmount;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Định dạng cho giấy in nhiệt cuộn 80mm
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header với Logo
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(storeName,
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold, fontSize: 14)),
                          pw.Text(storeAddress,
                              style: const pw.TextStyle(fontSize: 9)),
                        ]),
                  ),
                  pw.SizedBox(
                    height: 35,
                    width: 35,
                    child: pw.Image(logo),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Order Info
              pw.Text(
                  'Receipt: #${order.orderId.substring(order.orderId.length - 6).toUpperCase()}'),
              pw.Text('Date: ${DateFormat('dd/MM/yyyy, HH:mm').format(order.createdAt)}'),
              pw.Divider(height: 20),

              // Items Table
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                cellStyle: const pw.TextStyle(fontSize: 10),
                // Tùy chỉnh độ rộng các cột
                columnWidths: {
                  0: const pw.FlexColumnWidth(3.5), // Item
                  1: const pw.FlexColumnWidth(1.5),   // SL
                  2: const pw.FlexColumnWidth(2.5),   // Price
                  3: const pw.FlexColumnWidth(2.5), // Total
                },
                // Tùy chỉnh căn lề cho từng cột
                cellAlignments: {
                  0: pw.Alignment.centerLeft, // Căn trái cho cột Item
                  1: pw.Alignment.center,     // Căn giữa cho cột SL
                  2: pw.Alignment.centerRight, // Căn phải cho các cột số
                  3: pw.Alignment.centerRight,
                },
                // Tùy chỉnh tiêu đề cột
                headers: ['Item', 'SL', 'Price', 'Total'],
                // Tùy chỉnh dữ liệu cho mỗi dòng
                data: order.items.map((item) {
                  final product = productDetails[item.productId];
                  return [
                    product?.name ?? 'N/A', // Cột 0: Item
                    item.quantity.toString(), // Cột 1: SL
                    NumberFormat.decimalPattern('vi_VN').format(item.unitPrice), // Cột 2: Price
                    NumberFormat.decimalPattern('vi_VN').format(item.lineTotal), // Cột 3: Total
                  ];
                }).toList(),
              ),
              pw.Divider(),

              // Total
              _buildTotalRow('Total:', NumberFormat.decimalPattern('vi_VN').format(total), isTotal: true),
              pw.SizedBox(height: 30),

              // Footer
              pw.Center(child: pw.Text('Thank you for your purchase!')),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildTotalRow(String title, String value, {bool isTotal = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text(title, style: isTotal ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12) : null),
        pw.SizedBox(width: 10),
        pw.Text(value, style: isTotal ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12) : null),
      ],
    );
  }
}