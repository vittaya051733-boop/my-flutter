import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'utils/app_colors.dart';

enum _IncomePeriod { day, week, month }

class ShippingScreen extends StatefulWidget {
  const ShippingScreen({super.key});

  @override
  State<ShippingScreen> createState() => _ShippingScreenState();
}

class _ShippingScreenState extends State<ShippingScreen> {
  _IncomePeriod _period = _IncomePeriod.day;
  bool _exportingPdf = false;
  late final Future<void> _localeReady;

  @override
  void initState() {
    super.initState();
    _localeReady = initializeDateFormatting('th_TH');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream(String uid) {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('shopOwnerId', isEqualTo: uid)
        .snapshots();
  }

  Future<void> _exportPdf(_IncomeReport report) async {
    if (_exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      final bytes = await _buildPdf(report);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      await FileSaver.instance.saveFile(
        name: 'income_summary_$timestamp',
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('บันทึกไฟล์ PDF แล้ว')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('สร้าง PDF ไม่สำเร็จ: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<Uint8List> _buildPdf(_IncomeReport report) async {
    final pdf = pw.Document();
    final money = NumberFormat('#,##0.00');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            'Income Summary',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Period: ${report.periodLabelEn}'),
          pw.Text(
            'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
          ),
          pw.SizedBox(height: 18),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              _pdfMetricRow(
                'Total revenue',
                '${money.format(report.totalRevenue)} THB',
              ),
              _pdfMetricRow(
                'Product revenue',
                '${money.format(report.productRevenue)} THB',
              ),
              _pdfMetricRow(
                'Penalty fee',
                '${money.format(report.penaltyFee)} THB',
              ),
              _pdfMetricRow('Completed orders', '${report.orderCount}'),
              _pdfMetricRow('Rejected orders', '${report.rejectedOrderCount}'),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Revenue by bucket',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfCell('Label', bold: true),
                  _pdfCell('Orders', bold: true),
                  _pdfCell('Revenue', bold: true),
                ],
              ),
              ...report.buckets.map(
                (bucket) => pw.TableRow(
                  children: [
                    _pdfCell(bucket.label),
                    _pdfCell('${bucket.orderCount}'),
                    _pdfCell('${money.format(bucket.revenue)} THB'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Recent completed orders',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.6),
              1: pw.FlexColumnWidth(2.2),
              2: pw.FlexColumnWidth(1.3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfCell('Date', bold: true),
                  _pdfCell('Order', bold: true),
                  _pdfCell('Total', bold: true),
                ],
              ),
              ...report.orders
                  .take(20)
                  .map(
                    (order) => pw.TableRow(
                      children: [
                        _pdfCell(
                          DateFormat(
                            'yyyy-MM-dd HH:mm',
                          ).format(order.completedAt),
                        ),
                        _pdfCell(
                          order.orderCode.isEmpty
                              ? order.orderId
                              : order.orderCode,
                        ),
                        _pdfCell('${money.format(order.total)} THB'),
                      ],
                    ),
                  ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Recent rejected orders',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.6),
              1: pw.FlexColumnWidth(2.2),
              2: pw.FlexColumnWidth(1.3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfCell('Date', bold: true),
                  _pdfCell('Order', bold: true),
                  _pdfCell('Penalty', bold: true),
                ],
              ),
              ...report.rejectedOrders
                  .take(20)
                  .map(
                    (order) => pw.TableRow(
                      children: [
                        _pdfCell(
                          DateFormat(
                            'yyyy-MM-dd HH:mm',
                          ).format(order.rejectedAt),
                        ),
                        _pdfCell(
                          order.orderCode.isEmpty
                              ? order.orderId
                              : order.orderCode,
                        ),
                        _pdfCell('${money.format(order.penalty)} THB'),
                      ],
                    ),
                  ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.TableRow _pdfMetricRow(String label, String value) {
    return pw.TableRow(
      children: [_pdfCell(label, bold: true), _pdfCell(value)],
    );
  }

  pw.Widget _pdfCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('สรุปรายได้'),
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('กรุณาเข้าสู่ระบบ')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('สรุปรายได้'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: FutureBuilder<void>(
        future: _localeReady,
        builder: (context, localeSnapshot) {
          if (localeSnapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (localeSnapshot.hasError) {
            return Center(
              child: Text('โหลดรูปแบบวันที่ไม่สำเร็จ: ${localeSnapshot.error}'),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _ordersStream(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
              }

              final report = _IncomeReport.fromDocs(
                docs: snapshot.data?.docs ?? const [],
                period: _period,
              );

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _PeriodSelector(
                    value: _period,
                    onChanged: (value) => setState(() => _period = value),
                  ),
                  const SizedBox(height: 14),
                  _SummaryHeader(report: report),
                  const SizedBox(height: 14),
                  _MetricGrid(report: report),
                  const SizedBox(height: 14),
                  _ChartCard(report: report),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _exportingPdf ? null : () => _exportPdf(report),
                    icon: _exportingPdf
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      _exportingPdf ? 'กำลังสร้าง PDF...' : 'สร้างไฟล์ PDF',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _RecentOrdersCard(report: report),
                  const SizedBox(height: 14),
                  _RejectedOrdersCard(report: report),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _IncomeReport {
  const _IncomeReport({
    required this.period,
    required this.start,
    required this.end,
    required this.buckets,
    required this.orders,
    required this.rejectedOrders,
  });

  final _IncomePeriod period;
  final DateTime start;
  final DateTime end;
  final List<_IncomeBucket> buckets;
  final List<_IncomeOrder> orders;
  final List<_RejectedOrder> rejectedOrders;

  double get totalRevenue =>
      orders.fold(0, (runningTotal, order) => runningTotal + order.total);
  double get productRevenue => orders.fold(
    0,
    (runningTotal, order) => runningTotal + order.productTotal,
  );
  double get penaltyFee => rejectedOrders.fold(
    0,
    (runningTotal, order) => runningTotal + order.penalty,
  );
  int get orderCount => orders.length;
  int get rejectedOrderCount => rejectedOrders.length;

  String get periodLabel {
    switch (period) {
      case _IncomePeriod.day:
        return 'รายวัน';
      case _IncomePeriod.week:
        return 'รายสัปดาห์';
      case _IncomePeriod.month:
        return 'รายเดือน';
    }
  }

  String get periodLabelEn {
    switch (period) {
      case _IncomePeriod.day:
        return 'Daily';
      case _IncomePeriod.week:
        return 'Weekly';
      case _IncomePeriod.month:
        return 'Monthly';
    }
  }

  String get rangeLabel {
    final date = DateFormat('d MMM yyyy', 'th_TH');
    final last = end.subtract(const Duration(milliseconds: 1));
    if (_sameDay(start, last)) return date.format(start);
    return '${date.format(start)} - ${date.format(last)}';
  }

  static _IncomeReport fromDocs({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required _IncomePeriod period,
  }) {
    final now = DateTime.now();
    final start = _periodStart(now, period);
    final end = _periodEnd(start, period);
    final bucketCount = switch (period) {
      _IncomePeriod.day => 24,
      _IncomePeriod.week => 7,
      _IncomePeriod.month => DateUtils.getDaysInMonth(start.year, start.month),
    };

    final buckets = List<_IncomeBucket>.generate(
      bucketCount,
      (index) => _IncomeBucket(label: _bucketLabel(start, period, index)),
    );
    final orders = <_IncomeOrder>[];
    final rejectedOrders = <_RejectedOrder>[];

    for (final doc in docs) {
      final data = doc.data();
      final status = (data['status'] as String?)?.trim().toLowerCase() ?? '';

      if (_isRejectedOrder(data)) {
        final rejectedAt =
            _readDateTime(data['shopRejectedAt']) ??
            _readDateTime(data['rejectedAt']) ??
            _readDateTime(data['cancelledAt']) ??
            _readDateTime(data['updatedAt']) ??
            _readDateTime(data['createdAt']);
        if (rejectedAt != null &&
            !rejectedAt.isBefore(start) &&
            rejectedAt.isBefore(end)) {
          rejectedOrders.add(
            _RejectedOrder(
              orderId: doc.id,
              orderCode:
                  (data['orderCode'] ?? data['orderNumber'])
                      ?.toString()
                      .trim() ??
                  '',
              rejectedAt: rejectedAt,
              penalty: _readPenalty(data),
              reason:
                  (data['cancelReason'] ?? data['rejectReason'])
                      ?.toString()
                      .trim() ??
                  '',
            ),
          );
        }
      }

      if (status != 'delivered') continue;

      final completedAt =
          _readDateTime(data['deliveredAt']) ??
          _readDateTime(data['deliveryCompletedAt']) ??
          _readDateTime(data['updatedAt']) ??
          _readDateTime(data['createdAt']);
      if (completedAt == null ||
          completedAt.isBefore(start) ||
          !completedAt.isBefore(end)) {
        continue;
      }

      final total =
          _readDouble(data['totalAmount']) ??
          _readDouble(data['grandTotal']) ??
          _readDouble(data['totalPrice']) ??
          0;
      final shipping =
          _readDouble(data['shippingFee']) ??
          _readDouble(data['deliveryFee']) ??
          _readDouble(data['deliveryCharge']) ??
          0;
      final productTotal = _readProductTotal(
        data,
        total: total,
        shipping: shipping,
      );
      final order = _IncomeOrder(
        orderId: doc.id,
        orderCode:
            (data['orderCode'] ?? data['orderNumber'])?.toString().trim() ?? '',
        completedAt: completedAt,
        total: total,
        productTotal: productTotal,
        shippingFee: shipping,
      );
      orders.add(order);
      buckets[_bucketIndex(start, period, completedAt)].add(order);
    }

    orders.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    rejectedOrders.sort((a, b) => b.rejectedAt.compareTo(a.rejectedAt));
    return _IncomeReport(
      period: period,
      start: start,
      end: end,
      buckets: buckets,
      orders: orders,
      rejectedOrders: rejectedOrders,
    );
  }
}

class _IncomeBucket {
  _IncomeBucket({required this.label});

  final String label;
  double revenue = 0;
  int orderCount = 0;

  void add(_IncomeOrder order) {
    revenue += order.total;
    orderCount++;
  }
}

class _IncomeOrder {
  const _IncomeOrder({
    required this.orderId,
    required this.orderCode,
    required this.completedAt,
    required this.total,
    required this.productTotal,
    required this.shippingFee,
  });

  final String orderId;
  final String orderCode;
  final DateTime completedAt;
  final double total;
  final double productTotal;
  final double shippingFee;
}

class _RejectedOrder {
  const _RejectedOrder({
    required this.orderId,
    required this.orderCode,
    required this.rejectedAt,
    required this.penalty,
    required this.reason,
  });

  final String orderId;
  final String orderCode;
  final DateTime rejectedAt;
  final double penalty;
  final String reason;
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onChanged});

  final _IncomePeriod value;
  final ValueChanged<_IncomePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_IncomePeriod>(
      segments: const [
        ButtonSegment(value: _IncomePeriod.day, label: Text('รายวัน')),
        ButtonSegment(value: _IncomePeriod.week, label: Text('รายสัปดาห์')),
        ButtonSegment(value: _IncomePeriod.month, label: Text('รายเดือน')),
      ],
      selected: {value},
      onSelectionChanged: (selected) => onChanged(selected.first),
      showSelectedIcon: false,
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.report});

  final _IncomeReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'สรุปรายได้${report.periodLabel}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            report.rangeLabel,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Text(
            '฿${_money(report.totalRevenue)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.report});

  final _IncomeReport report;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData(
        'ค่าสินค้า',
        report.productRevenue,
        Icons.shopping_bag_outlined,
      ),
      _MetricData('ค่าปรับ', report.penaltyFee, Icons.gavel_outlined),
      _MetricData(
        'ออเดอร์',
        report.orderCount.toDouble(),
        Icons.receipt_long_outlined,
        isMoney: false,
      ),
      _MetricData(
        'ปฏิเสธ',
        report.rejectedOrderCount.toDouble(),
        Icons.cancel_outlined,
        isMoney: false,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.75,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _MetricTile(data: items[index]),
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon, {this.isMoney = true});

  final String label;
  final double value;
  final IconData icon;
  final bool isMoney;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(data.icon, color: AppColors.accent),
          Text(
            data.label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          Text(
            data.isMoney
                ? '฿${_money(data.value)}'
                : data.value.toInt().toString(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.report});

  final _IncomeReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'กราฟรายได้',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _IncomeChartPainter(report.buckets),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeChartPainter extends CustomPainter {
  const _IncomeChartPainter(this.buckets);

  final List<_IncomeBucket> buckets;

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    final barPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.fill;
    final labelPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    final chartRect = Rect.fromLTWH(28, 10, size.width - 36, size.height - 42);
    final maxRevenue = math.max(
      1,
      buckets.fold<double>(0, (max, bucket) => math.max(max, bucket.revenue)),
    );

    canvas.drawLine(chartRect.bottomLeft, chartRect.bottomRight, axisPaint);
    canvas.drawLine(chartRect.bottomLeft, chartRect.topLeft, axisPaint);

    final gap = buckets.length > 12 ? 2.0 : 6.0;
    final barWidth = math.max(
      3.0,
      (chartRect.width - (gap * (buckets.length - 1))) / buckets.length,
    );
    for (var i = 0; i < buckets.length; i++) {
      final bucket = buckets[i];
      final height = (bucket.revenue / maxRevenue) * chartRect.height;
      final left = chartRect.left + (i * (barWidth + gap));
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, chartRect.bottom - height, barWidth, height),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, barPaint);

      final shouldLabel =
          buckets.length <= 7 ||
          i == 0 ||
          i == buckets.length - 1 ||
          i % 5 == 0;
      if (shouldLabel) {
        labelPainter.text = TextSpan(
          text: bucket.label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        );
        labelPainter.layout();
        labelPainter.paint(
          canvas,
          Offset(
            left + (barWidth / 2) - (labelPainter.width / 2),
            chartRect.bottom + 8,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IncomeChartPainter oldDelegate) =>
      oldDelegate.buckets != buckets;
}

class _RecentOrdersCard extends StatelessWidget {
  const _RecentOrdersCard({required this.report});

  final _IncomeReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'ออเดอร์ล่าสุด',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          if (report.orders.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'ยังไม่มีออเดอร์ส่งสำเร็จในช่วงนี้',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            )
          else
            ...report.orders
                .take(10)
                .map(
                  (order) => ListTile(
                    dense: true,
                    title: Text(
                      order.orderCode.isEmpty
                          ? 'Order ${order.orderId.substring(0, math.min(8, order.orderId.length))}'
                          : order.orderCode,
                    ),
                    subtitle: Text(
                      DateFormat(
                        'd MMM yyyy HH:mm',
                        'th_TH',
                      ).format(order.completedAt),
                    ),
                    trailing: Text(
                      '฿${_money(order.total)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _RejectedOrdersCard extends StatelessWidget {
  const _RejectedOrdersCard({required this.report});

  final _IncomeReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'ออเดอร์ที่ปฏิเสธ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          if (report.rejectedOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'ยังไม่มีออเดอร์ที่ปฏิเสธในช่วงนี้',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            )
          else
            ...report.rejectedOrders
                .take(10)
                .map(
                  (order) => ListTile(
                    dense: true,
                    title: Text(
                      order.orderCode.isEmpty
                          ? 'Order ${order.orderId.substring(0, math.min(8, order.orderId.length))}'
                          : order.orderCode,
                    ),
                    subtitle: Text(
                      [
                        DateFormat(
                          'd MMM yyyy HH:mm',
                          'th_TH',
                        ).format(order.rejectedAt),
                        if (order.reason.isNotEmpty) order.reason,
                      ].join(' • '),
                    ),
                    trailing: order.penalty > 0
                        ? Text(
                            '฿${_money(order.penalty)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          )
                        : const Text(
                            'ปฏิเสธ',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
        ],
      ),
    );
  }
}

DateTime _periodStart(DateTime now, _IncomePeriod period) {
  switch (period) {
    case _IncomePeriod.day:
      return DateTime(now.year, now.month, now.day);
    case _IncomePeriod.week:
      final startOfDay = DateTime(now.year, now.month, now.day);
      return startOfDay.subtract(Duration(days: now.weekday - 1));
    case _IncomePeriod.month:
      return DateTime(now.year, now.month);
  }
}

DateTime _periodEnd(DateTime start, _IncomePeriod period) {
  switch (period) {
    case _IncomePeriod.day:
      return start.add(const Duration(days: 1));
    case _IncomePeriod.week:
      return start.add(const Duration(days: 7));
    case _IncomePeriod.month:
      return DateTime(start.year, start.month + 1);
  }
}

String _bucketLabel(DateTime start, _IncomePeriod period, int index) {
  switch (period) {
    case _IncomePeriod.day:
      return index.toString().padLeft(2, '0');
    case _IncomePeriod.week:
      return DateFormat('E', 'th_TH').format(start.add(Duration(days: index)));
    case _IncomePeriod.month:
      return '${index + 1}';
  }
}

int _bucketIndex(DateTime start, _IncomePeriod period, DateTime date) {
  switch (period) {
    case _IncomePeriod.day:
      return date.hour.clamp(0, 23);
    case _IncomePeriod.week:
      return date.difference(start).inDays.clamp(0, 6);
    case _IncomePeriod.month:
      return (date.day - 1).clamp(
        0,
        DateUtils.getDaysInMonth(start.year, start.month) - 1,
      );
  }
}

DateTime? _readDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

double? _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

bool _isRejectedOrder(Map<String, dynamic> data) {
  final shopDecisionStatus = (data['shopDecisionStatus'] as String?)
      ?.trim()
      .toLowerCase();
  final status = (data['status'] as String?)?.trim().toLowerCase();
  final cancelReason = (data['cancelReason'] as String?)?.trim().toLowerCase();

  return shopDecisionStatus == 'rejected' ||
      data['shopRejectedAt'] != null ||
      data['rejectedAt'] != null ||
      (status == 'cancelled' &&
          (cancelReason?.contains('shop_rejected') ?? false));
}

double _readPenalty(Map<String, dynamic> data) {
  return _readDouble(data['penalty']) ??
      _readDouble(data['penaltyFee']) ??
      _readDouble(data['fine']) ??
      _readDouble(data['latePenalty']) ??
      0;
}

double _readProductTotal(
  Map<String, dynamic> data, {
  required double total,
  required double shipping,
}) {
  final direct = _readDouble(data['subtotal']);
  if (direct != null) return direct;
  final items = data['items'] ?? data['products'];
  if (items is List) {
    final itemTotal = items.whereType<Map>().fold<double>(0, (
      runningTotal,
      item,
    ) {
      final price = _readDouble(item['price'] ?? item['unitPrice']) ?? 0;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      return runningTotal + (price * quantity);
    });
    if (itemTotal > 0) return itemTotal;
  }
  final fallback = total - shipping;
  return fallback > 0 ? fallback : total;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _money(double value) => NumberFormat('#,##0.00').format(value);
