import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'models/order_model.dart';
import 'utils/app_colors.dart';

String orderQrCodeText(DetailedOrder order) {
  final code = order.orderCode?.trim();
  final orderCode = code != null && code.isNotEmpty ? code : '';
  return 'VAN_ORDER:${order.orderId}|$orderCode|${order.totalAmount.toStringAsFixed(2)}';
}

double orderQrProductSubtotal(DetailedOrder order) {
  final itemTotal = order.items.fold<double>(
    0,
    (runningTotal, item) => runningTotal + (item.price * item.quantity),
  );
  if (itemTotal > 0) return itemTotal;
  final fromGrandTotal = order.totalAmount - order.shippingFee;
  return fromGrandTotal > 0 ? fromGrandTotal : order.totalAmount;
}

String orderQrOrderCode(DetailedOrder order) {
  final code = order.orderCode?.trim();
  return code != null && code.isNotEmpty ? code : '';
}

Future<void> printOrderQr(BuildContext context, DetailedOrder order) async {
  final printer = BlueThermalPrinter.instance;
  final universalQr = orderQrCodeText(order);
  final resolvedOrderCode = orderQrOrderCode(order);
  try {
    final devices = await printer.getBondedDevices();
    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบเครื่องปริ้นเตอร์ที่เชื่อมต่อ')),
      );
      return;
    }

    await printer.connect(devices.first);

    await printer.printCustom('VAN ORDER QR', 2, 1);
    await printer.write('Order ID: ${order.orderId}');
    await printer.write(
      'Order Code: ${resolvedOrderCode.isEmpty ? '-' : resolvedOrderCode}',
    );
    await printer.write('--------------------------');
    await printer.printCustom('ORDER QR', 1, 1);
    await printer.printQRcode(universalQr, 300, 300, 1);
    await printer.write(universalQr);
    await printer.write('--------------------------');
    await printer.printCustom('QR VERIFY DATA', 1, 0);
    await printer.write('Order ID: ${order.orderId}');
    await printer.write(
      'Order Code: ${resolvedOrderCode.isEmpty ? '-' : resolvedOrderCode}',
    );
    await printer.write(
      'Product subtotal: ${orderQrProductSubtotal(order).toStringAsFixed(2)} THB',
    );
    await printer.write(
      'Shipping fee: ${order.shippingFee.toStringAsFixed(2)} THB',
    );
    await printer.write(
      'Grand total: ${order.totalAmount.toStringAsFixed(2)} THB',
    );
    await printer.write('--------------------------');
    await printer.printCustom('ITEMS', 1, 0);
    for (final item in order.items) {
      await printer.write(
        '${item.productName} x${item.quantity} ${item.price.toStringAsFixed(2)} THB',
      );
    }
    await printer.write('--------------------------');
    await printer.paperCut();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('พิมพ์ QR Code และข้อมูลตรวจสอบแล้ว')),
    );
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
  }
}

class OrderQRScreen extends StatelessWidget {
  const OrderQRScreen({super.key, required this.order});

  final DetailedOrder order;

  String get _orderCode {
    return orderQrOrderCode(order);
  }

  String _qrPayload(String type) {
    if (type == 'VAN_ORDER') return orderQrCodeText(order);
    return '$type:${order.orderId}|$_orderCode|${order.totalAmount.toStringAsFixed(2)}';
  }

  Future<void> _printAllQrCodes(
    BuildContext context, {
    required String universalQr,
  }) async {
    await printOrderQr(context, order);
  }

  @override
  Widget build(BuildContext context) {
    final universalQr = _qrPayload('VAN_ORDER');

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code สำหรับไรเดอร์'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () =>
                  _printAllQrCodes(context, universalQr: universalQr),
              icon: const Icon(Icons.print_outlined),
              label: const Text('พิมพ์ QR เดียวพร้อมข้อมูลตรวจสอบ'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
            _QrPayloadCard(
              title: 'QR เดียวสำหรับออเดอร์นี้',
              subtitle: 'สแกน QR เดียวตามสถานะออเดอร์',
              icon: Icons.qr_code_2_rounded,
              color: AppColors.accent,
              payload: universalQr,
            ),
            const SizedBox(height: 16),
            _OrderQrDetails(order: order, orderCode: _orderCode),
          ],
        ),
      ),
    );
  }
}

class _QrPayloadCard extends StatelessWidget {
  const _QrPayloadCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.payload,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String payload;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
              ),
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 300,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: color),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              payload,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderQrDetails extends StatelessWidget {
  const _OrderQrDetails({required this.order, required this.orderCode});

  final DetailedOrder order;
  final String orderCode;

  double get _productSubtotal {
    final itemTotal = order.items.fold<double>(
      0,
      (runningTotal, item) => runningTotal + (item.price * item.quantity),
    );
    if (itemTotal > 0) return itemTotal;
    final fromGrandTotal = order.totalAmount - order.shippingFee;
    return fromGrandTotal > 0 ? fromGrandTotal : order.totalAmount;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFFBEB),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ข้อมูลที่ใช้ตรวจ QR',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text('Order ID: ${order.orderId}'),
            Text('เลขออเดอร์: ${orderCode.isEmpty ? '-' : orderCode}'),
            Text('ค่าสินค้า: ฿${_productSubtotal.toStringAsFixed(2)}'),
            Text('ค่าส่ง: ฿${order.shippingFee.toStringAsFixed(2)}'),
            Text('ยอดรวม: ฿${order.totalAmount.toStringAsFixed(2)}'),
            if (order.items.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'รายการสินค้า',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...order.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(item.productName)),
                      Text('x${item.quantity}'),
                      const SizedBox(width: 12),
                      Text('฿${item.price.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
