import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/services/firestore_service.dart';
import 'package:intl/intl.dart';
import '../../../core/models/order_model.dart';
import '../widgets/manager_app_bar.dart';
import 'order_detail_screen.dart';

/// Màn hình Báo cáo Chi nhánh (Store Report)
/// Hiển thị doanh thu thực tế, lọc theo ngày/tháng, và danh sách hóa đơn
class StoreReportScreen extends StatefulWidget {
  const StoreReportScreen({super.key});

  @override
  State<StoreReportScreen> createState() => _StoreReportScreenState();
}

class _StoreReportScreenState extends State<StoreReportScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  // Filter state
  DateTime _selectedDate = DateTime.now();
  String _filterMode = 'Day'; // 'Day' hoặc 'Month'

  // Data

  String _formatCurrency(double amount) {
    // Sử dụng intl để định dạng tiền tệ chuyên nghiệp và dễ bảo trì hơn
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'VND',
      decimalDigits: 0,
    ).format(amount);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // Rebuild will be triggered by setState, which creates a new stream
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Xác định khoảng thời gian lọc dựa trên state
    DateTime start;
    DateTime end;
    if (_filterMode == 'Day') {
      start = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      end = start.add(const Duration(days: 1));
    } else {
      start = DateTime(_selectedDate.year, _selectedDate.month, 1);
      end = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
    }

    // Tạo stream query
    final ordersStream = _firestoreService.db
        .collection('orders')
        .where('status', isEqualTo: 'paid')
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('created_at', isLessThan: Timestamp.fromDate(end))
        .orderBy('created_at', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const ManagerAppBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream: ordersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // Vẫn hiển thị bộ lọc và thẻ summary với giá trị 0
            return _buildReportBody(context, [], 0);
          }

          final invoices = snapshot.data!.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList();
          final totalRevenue = invoices.fold(
            0.0,
            (sum, order) => sum + order.totalAmount,
          );

          return _buildReportBody(context, invoices, totalRevenue);
        },
      ),
    );
  }

  /// Widget chứa toàn bộ body của màn hình báo cáo
  Widget _buildReportBody(
    BuildContext context,
    List<OrderModel> invoices,
    double totalRevenue,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final chartSpots = _prepareChartData(invoices, _filterMode, _selectedDate);
    // Tìm giá trị Y lớn nhất để co giãn biểu đồ
    final maxY = chartSpots.fold<double>(
      0.0,
      (max, spot) => spot.y > max ? spot.y : max,
    );

    // Sử dụng CustomScrollView để xử lý các layout có thể bị tràn màn hình một cách linh hoạt.
    // Cách này hiệu quả hơn là lồng các ListView hoặc dùng SingleChildScrollView với Column.
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildFilterSection(context)),
        if (chartSpots.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(
            child: _buildRevenueChart(context, chartSpots, maxY, _filterMode),
          ),
        ],
        SliverToBoxAdapter(
          child: _buildSummaryCard(context, invoices.length, totalRevenue),
        ),
        SliverToBoxAdapter(
          child: const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Text(
                  'RECENT INVOICES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (invoices.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(colorScheme),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.builder(
              itemCount: invoices.length,
              itemBuilder: (context, index) =>
                  _buildInvoiceItem(invoices[index]),
            ),
          ),
      ],
    );
  }

  /// Chuẩn bị dữ liệu cho biểu đồ từ danh sách hóa đơn
  List<FlSpot> _prepareChartData(
    List<OrderModel> invoices,
    String filterMode,
    DateTime selectedDate,
  ) {
    if (invoices.isEmpty) return [];

    if (filterMode == 'Month') {
      final daysInMonth = DateUtils.getDaysInMonth(
        selectedDate.year,
        selectedDate.month,
      );
      // Khởi tạo map với tất cả các ngày trong tháng, doanh thu = 0
      final Map<int, double> dailyRevenue = {
        for (var i = 1; i <= daysInMonth; i++) i: 0.0,
      };

      for (var order in invoices) {
        dailyRevenue.update(
          order.createdAt.day,
          (value) => value + order.totalAmount,
          ifAbsent: () => order.totalAmount,
        );
      }
      return dailyRevenue.entries
          .map((e) => FlSpot(e.key.toDouble(), e.value))
          .toList();
    } else {
      // Day
      // Khởi tạo map với tất cả các giờ trong ngày, doanh thu = 0
      final Map<int, double> hourlyRevenue = {
        for (var i = 0; i < 24; i++) i: 0.0,
      };
      for (var order in invoices) {
        hourlyRevenue.update(
          order.createdAt.hour,
          (value) => value + order.totalAmount,
          ifAbsent: () => order.totalAmount,
        );
      }
      return hourlyRevenue.entries
          .map((e) => FlSpot(e.key.toDouble(), e.value))
          .toList();
    }
  }

  Widget _buildFilterSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              // Day/Month Toggle
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'Day',
                      label: Text('Day'),
                      icon: Icon(Icons.today),
                    ),
                    ButtonSegment(
                      value: 'Month',
                      label: Text('Month'),
                      icon: Icon(Icons.calendar_month),
                    ),
                  ],
                  selected: {_filterMode},
                  onSelectionChanged: (val) {
                    setState(() {
                      _filterMode = val.first;
                      // Rebuild will be triggered by setState, which creates a new stream
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Date Picker Button
              IconButton.filledTonal(
                onPressed: _selectDate,
                icon: const Icon(Icons.event),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _filterMode == 'Day'
                ? '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'
                : 'Tháng ${_selectedDate.month}/${_selectedDate.year}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    int orderCount,
    double totalRevenue,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0), // Thêm margin top
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TOTAL REVENUE",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: colorScheme.onPrimary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatCurrency(totalRevenue),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onPrimary,
                  letterSpacing: -1,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.trending_up, color: colorScheme.onPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$orderCount Orders Successful',
            style: TextStyle(
              color: colorScheme.onPrimary.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(
    BuildContext context,
    List<FlSpot> spots,
    double maxY,
    String filterMode,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    // Hàm định dạng nhãn trục Y (ví dụ: 1,000,000 -> 1M)
    String formatYAxis(double value) {
      if (value >= 1000000) {
        return '${(value / 1000000).toStringAsFixed(1)}M';
      } else if (value >= 1000) {
        return '${(value / 1000).toStringAsFixed(0)}K';
      }
      return value.toStringAsFixed(0);
    }

    // Hàm tạo widget cho nhãn trục X
    Widget bottomTitleWidgets(double value, TitleMeta meta) {
      final style = TextStyle(
        fontSize: 10,
        color: colorScheme.onSurfaceVariant,
      );
      String text;
      if (filterMode == 'Month') {
        // Chỉ hiển thị nhãn cho các ngày 1, 5, 10, 15, ...
        if (value.toInt() % 5 == 0 || value.toInt() == 1) {
          text = value.toInt().toString();
        } else {
          return const SizedBox();
        }
      } else {
        // Day
        // Chỉ hiển thị nhãn cho các mốc 0h, 6h, 12h, 18h
        if (value.toInt() % 6 == 0) {
          text = '${value.toInt()}h';
        } else {
          return const SizedBox();
        }
      }
      return SideTitleWidget(
        axisSide: meta.axisSide,
        space: 4,
        child: Text(text, style: style),
      );
    }

    return Container(
      height: 250,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: LineChart(
        LineChartData(
          // Dữ liệu tooltip khi chạm vào
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (LineBarSpot spot) {
                return colorScheme.primary.withOpacity(0.8);
              },
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${_formatCurrency(spot.y)}\n',
                    TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: filterMode == 'Month'
                            ? 'Day ${spot.x.toInt()}'
                            : 'Hour ${spot.x.toInt()}',
                        style: TextStyle(
                          color: colorScheme.onPrimary.withOpacity(0.8),
                          fontWeight: FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          // Lưới
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: colorScheme.outlineVariant.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          // Tiêu đề các trục
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 1,
                getTitlesWidget: bottomTitleWidgets,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value == 0 || value >= meta.max)
                    return const SizedBox(); // Không hiển thị nhãn ở 0 và ở đỉnh
                  return Text(
                    formatYAxis(value),
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.left,
                  );
                },
              ),
            ),
          ),
          // Đường viền
          borderData: FlBorderData(show: false),
          // Giá trị min/max các trục
          minX: filterMode == 'Month' ? 1 : 0,
          maxX: filterMode == 'Month'
              ? DateUtils.getDaysInMonth(
                  _selectedDate.year,
                  _selectedDate.month,
                ).toDouble()
              : 23,
          minY: 0,
          maxY: maxY == 0
              ? 100000
              : maxY *
                    1.2, // Nếu max Y là 0, đặt một giá trị mặc định để biểu đồ không bị dẹt
          // Dữ liệu đường line
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: colorScheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.3),
                    colorScheme.primary.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 16),
          Text(
            'Không có hóa đơn nào',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItem(OrderModel order) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailScreen(order: order),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                order.paymentMethod == 'Cash'
                    ? Icons.payments_outlined
                    : Icons.account_balance_outlined,
                color: colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice #${order.orderId.substring(order.orderId.length - 6).toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')} - ${order.paymentMethod}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(order.totalAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    fontSize: 15,
                  ),
                ),
                const Text(
                  'Paid',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
