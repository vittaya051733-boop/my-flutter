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

import 'models/order_model.dart';
import 'utils/app_colors.dart';
import 'widgets/cached_app_image.dart';

enum _IncomePeriod { day, week, month }

class ShippingScreen extends StatefulWidget {
  const ShippingScreen({super.key});

  @override
  State<ShippingScreen> createState() => _ShippingScreenState();
}

class _ShippingScreenState extends State<ShippingScreen> {
  static const int _summaryRetentionMonths = 6;
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

  DateTime _summaryRetentionStart([DateTime? now]) {
    final reference = now ?? DateTime.now();
    return DateTime(reference.year, reference.month - _summaryRetentionMonths, reference.day);
  }

  Future<void> _showCompletedOrdersSummary(_IncomeReport report) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _OrderSummarySheet(
        title: 'สรุปออเดอร์สำเร็จแบบย่อ',
        subtitle:
            'แสดงเฉพาะข้อมูลสรุปที่ยังอยู่ในช่วงเก็บรักษา ${_summaryRetentionMonths} เดือนล่าสุด',
        emptyText: 'ยังไม่มีออเดอร์ส่งสำเร็จในช่วงนี้',
        summaryRows: <_SummaryRowData>[
          _SummaryRowData('จำนวนออเดอร์สำเร็จ', '${report.orderCount}'),
          _SummaryRowData('ยอดรวม', '฿${_money(report.totalRevenue)}'),
          _SummaryRowData('ค่าสินค้า', '฿${_money(report.productRevenue)}'),
        ],
        children: report.orders
            .map(
              (order) => ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                title: Text(_orderDisplayCode(order.orderId, order.orderCode)),
                subtitle: Text(
                  '${DateFormat('d MMM yyyy HH:mm', 'th_TH').format(order.completedAt)} • ${order.customerName} • ฿${_money(order.total)}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showOrderHistoryDetail(
                  title: 'รายละเอียดออเดอร์สำเร็จ',
                  eventLabel: 'ส่งสำเร็จเมื่อ',
                  eventAt: order.completedAt,
                  order: order.order,
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> _showRejectedOrdersSummary(_IncomeReport report) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _OrderSummarySheet(
        title: 'สรุปออเดอร์ที่ปฏิเสธแบบย่อ',
        subtitle:
            'แสดงเฉพาะข้อมูลสรุปที่ยังอยู่ในช่วงเก็บรักษา ${_summaryRetentionMonths} เดือนล่าสุด',
        emptyText: 'ยังไม่มีออเดอร์ที่ปฏิเสธในช่วงนี้',
        summaryRows: <_SummaryRowData>[
          _SummaryRowData('จำนวนออเดอร์ที่ปฏิเสธ', '${report.rejectedOrderCount}'),
          _SummaryRowData('ค่าปรับรวม', '฿${_money(report.penaltyFee)}'),
        ],
        children: report.rejectedOrders
            .map(
              (order) => ListTile(
                dense: true,
                leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                title: Text(_orderDisplayCode(order.orderId, order.orderCode)),
                subtitle: Text(
                  [
                    DateFormat('d MMM yyyy HH:mm', 'th_TH').format(order.rejectedAt),
                    if (order.reason.isNotEmpty) order.reason,
                  ].join(' • '),
                ),
                trailing: Text(
                  order.penalty > 0 ? '฿${_money(order.penalty)}' : 'ปฏิเสธ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => _showOrderHistoryDetail(
                  title: 'รายละเอียดออเดอร์ที่ปฏิเสธ',
                  eventLabel: 'ปฏิเสธเมื่อ',
                  eventAt: order.rejectedAt,
                  order: order.order,
                  rejectionReason: order.reason,
                  penalty: order.penalty,
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> _showOrderHistoryDetail({
    required String title,
    required String eventLabel,
    required DateTime eventAt,
    required DetailedOrder order,
    String? rejectionReason,
    double? penalty,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _OrderHistoryDetailSheet(
        title: title,
        eventLabel: eventLabel,
        eventAt: eventAt,
        order: order,
        rejectionReason: rejectionReason,
        penalty: penalty,
        onImageTap: _showHistoryImagePreview,
      ),
    );
  }

  Future<void> _showHistoryImagePreview(String imageUrl, String title) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Center(
                child: CachedAppImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: const SizedBox(
                    height: 120,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 16,
              right: 56,
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
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
                retentionStart: _summaryRetentionStart(),
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
                  _MetricGrid(
                    report: report,
                    onCompletedTap: () => _showCompletedOrdersSummary(report),
                    onRejectedTap: () => _showRejectedOrdersSummary(report),
                  ),
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
    required this.retentionStart,
    required this.buckets,
    required this.orders,
    required this.rejectedOrders,
  });

  final _IncomePeriod period;
  final DateTime start;
  final DateTime end;
  final DateTime retentionStart;
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
    required DateTime retentionStart,
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
          !rejectedAt.isBefore(retentionStart) &&
            !rejectedAt.isBefore(start) &&
            rejectedAt.isBefore(end)) {
          rejectedOrders.add(
            _RejectedOrder(
              order: _buildDetailedOrder(doc.id, data),
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
          completedAt.isBefore(retentionStart) ||
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
        order: _buildDetailedOrder(doc.id, data),
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
      retentionStart: retentionStart,
      buckets: buckets,
      orders: orders,
      rejectedOrders: rejectedOrders,
    );
  }

  static DetailedOrder _buildDetailedOrder(
    String orderId,
    Map<String, dynamic> data,
  ) {
    final normalized = Map<String, dynamic>.from(data);
    final createdAt =
        _readDateTime(normalized['createdAt']) ??
        _readDateTime(normalized['updatedAt']) ??
        _readDateTime(normalized['deliveredAt']) ??
        _readDateTime(normalized['shopRejectedAt']) ??
        DateTime.now();
    final updatedAt =
        _readDateTime(normalized['updatedAt']) ??
        _readDateTime(normalized['deliveredAt']) ??
        _readDateTime(normalized['shopRejectedAt']) ??
        createdAt;
    normalized['orderId'] = orderId;
    normalized['createdAt'] = Timestamp.fromDate(createdAt);
    normalized['updatedAt'] = Timestamp.fromDate(updatedAt);
    return DetailedOrder.fromMap(normalized);
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
    required this.order,
    required this.completedAt,
    required this.total,
    required this.productTotal,
    required this.shippingFee,
  });

  final DetailedOrder order;
  final DateTime completedAt;
  final double total;
  final double productTotal;
  final double shippingFee;

  String get orderId => order.orderId;
  String get orderCode => order.orderCode?.trim() ?? '';
  String get customerName {
    final value = order.customerName.trim();
    return value.isEmpty ? '-' : value;
  }
}

class _RejectedOrder {
  const _RejectedOrder({
    required this.order,
    required this.rejectedAt,
    required this.penalty,
    required this.reason,
  });

  final DetailedOrder order;
  final DateTime rejectedAt;
  final double penalty;
  final String reason;

  String get orderId => order.orderId;
  String get orderCode => order.orderCode?.trim() ?? '';
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
  const _MetricGrid({
    required this.report,
    required this.onCompletedTap,
    required this.onRejectedTap,
  });

  final _IncomeReport report;
  final VoidCallback onCompletedTap;
  final VoidCallback onRejectedTap;

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
        onTap: onCompletedTap,
      ),
      _MetricData(
        'ปฏิเสธ',
        report.rejectedOrderCount.toDouble(),
        Icons.cancel_outlined,
        isMoney: false,
        onTap: onRejectedTap,
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
  const _MetricData(this.label, this.value, this.icon, {
    this.isMoney = true,
    this.onTap,
  });

  final String label;
  final double value;
  final IconData icon;
  final bool isMoney;
  final VoidCallback? onTap;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(data.icon, color: AppColors.accent),
                  if (data.onTap != null) ...<Widget>[
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ],
              ),
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
        ),
      ),
    );
  }
}

class _OrderSummarySheet extends StatelessWidget {
  const _OrderSummarySheet({
    required this.title,
    required this.subtitle,
    required this.emptyText,
    required this.summaryRows,
    required this.children,
  });

  final String title;
  final String subtitle;
  final String emptyText;
  final List<_SummaryRowData> summaryRows;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: summaryRows
                      .map(
                        (row) => ListTile(
                          dense: true,
                          title: Text(row.label),
                          trailing: Text(
                            row.value,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 14),
              if (children.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    emptyText,
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              else
                ...children,
            ],
          );
        },
      ),
    );
  }
}

class _SummaryRowData {
  const _SummaryRowData(this.label, this.value);

  final String label;
  final String value;
}

class _OrderHistoryDetailSheet extends StatelessWidget {
  const _OrderHistoryDetailSheet({
    required this.title,
    required this.eventLabel,
    required this.eventAt,
    required this.order,
    required this.onImageTap,
    this.rejectionReason,
    this.penalty,
  });

  final String title;
  final String eventLabel;
  final DateTime eventAt;
  final DetailedOrder order;
  final Future<void> Function(String imageUrl, String title) onImageTap;
  final String? rejectionReason;
  final double? penalty;

  @override
  Widget build(BuildContext context) {
    final rejectionText = rejectionReason?.trim() ?? '';
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _DetailInfoCard(
                children: [
                  _DetailRow(
                    label: 'เลขออเดอร์',
                    value: _orderDisplayCode(order.orderId, order.orderCode?.trim() ?? ''),
                  ),
                  _DetailRow(
                    label: eventLabel,
                    value: DateFormat('d MMM yyyy HH:mm', 'th_TH').format(eventAt),
                  ),
                  _DetailRow(
                    label: 'สถานะ',
                    value: _historyStatusLabel(order.status),
                  ),
                  _DetailRow(
                    label: 'ลูกค้า',
                    value: order.customerName.trim().isEmpty ? '-' : order.customerName.trim(),
                  ),
                  _DetailRow(
                    label: 'เบอร์โทร',
                    value: order.customerPhone.trim().isEmpty ? '-' : order.customerPhone.trim(),
                  ),
                  _DetailRow(
                    label: 'ที่อยู่ลูกค้า',
                    value: order.customerAddress.trim().isEmpty ? '-' : order.customerAddress.trim(),
                  ),
                  _DetailRow(
                    label: 'ที่อยู่ร้าน',
                    value: order.shopAddress.trim().isEmpty ? '-' : order.shopAddress.trim(),
                  ),
                  if (rejectionText.isNotEmpty)
                    _DetailRow(label: 'เหตุผลที่ปฏิเสธ', value: rejectionText),
                  if ((penalty ?? 0) > 0)
                    _DetailRow(label: 'ค่าปรับ', value: '฿${_money(penalty ?? 0)}'),
                ],
              ),
              const SizedBox(height: 14),
              _DetailInfoCard(
                title: 'สรุปยอด',
                children: [
                  _DetailRow(
                    label: 'ค่าสินค้า',
                    value: '฿${_money(_detailProductSubtotal(order))}',
                  ),
                  _DetailRow(label: 'ค่าส่ง', value: '฿${_money(order.shippingFee)}'),
                  _DetailRow(
                    label: 'ยอดรวม',
                    value: '฿${_money(order.totalAmount)}',
                    emphasize: true,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DetailInfoCard(
                title: 'รายการสินค้า',
                children: order.items.isEmpty
                    ? const <Widget>[
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'ไม่มีข้อมูลรายการสินค้า',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ),
                      ]
                    : order.items
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _HistoryOrderItemTile(
                              item: item,
                              onImageTap: item.imageUrl?.trim().isNotEmpty == true
                                  ? () => onImageTap(
                                        item.imageUrl!.trim(),
                                        item.productName.trim().isEmpty ? 'รูปสินค้า' : item.productName.trim(),
                                      )
                                  : null,
                            ),
                          ),
                        )
                        .toList(growable: false),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailInfoCard extends StatelessWidget {
  const _DetailInfoCard({this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                color: emphasize ? AppColors.accent : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryOrderItemTile extends StatelessWidget {
  const _HistoryOrderItemTile({required this.item, this.onImageTap});

  final OrderItem item;
  final VoidCallback? onImageTap;

  @override
  Widget build(BuildContext context) {
    final total = item.price * item.quantity;
    final imageUrl = item.imageUrl?.trim();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onImageTap,
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                CachedAppImage(
                  imageUrl: imageUrl,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(10),
                  errorWidget: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fastfood_outlined, color: Color(0xFF94A3B8)),
                  ),
                ),
                if (onImageTap != null)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(Icons.open_in_full, size: 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName.trim().isEmpty ? '-' : item.productName.trim(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (item.toppings?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    'ท็อปปิ้ง: ${item.toppings!.trim()}',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'จำนวน ${item.quantity} x ฿${_money(item.price)}',
                  style: const TextStyle(color: Color(0xFF334155), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'รวม ฿${_money(total)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
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

String _orderDisplayCode(String orderId, String orderCode) {
  if (orderCode.isNotEmpty) return orderCode;
  return 'Order ${orderId.substring(0, math.min(8, orderId.length))}';
}

String _historyStatusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'delivered':
      return 'ส่งสำเร็จ';
    case 'ready':
      return 'พร้อมส่ง';
    case 'delivering':
      return 'กำลังจัดส่ง';
    case 'preparing':
      return 'กำลังเตรียม';
    case 'accepted':
      return 'รับออเดอร์แล้ว';
    case 'pending':
      return 'รออนุมัติ';
    case 'cancelled':
      return 'ยกเลิก';
    default:
      return status.isEmpty ? '-' : status;
  }
}

double _detailProductSubtotal(DetailedOrder order) {
  final itemTotal = order.items.fold<double>(
    0,
    (runningTotal, item) => runningTotal + (item.price * item.quantity),
  );
  if (itemTotal > 0) return itemTotal;
  final fallback = order.totalAmount - order.shippingFee;
  return fallback > 0 ? fallback : order.totalAmount;
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
