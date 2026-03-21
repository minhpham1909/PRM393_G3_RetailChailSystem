// Test cơ bản cho ứng dụng RCMS
// Kiểm tra xem app khởi chạy thành công không

import 'package:flutter_test/flutter_test.dart';
import 'package:retail_chain_system/main.dart';

void main() {
  testWidgets('App khởi chạy thành công', (WidgetTester tester) async {
    // Xây dựng ứng dụng
    await tester.pumpWidget(const RCMSApp());

    // Xác nhận app hiển thị thành công
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
