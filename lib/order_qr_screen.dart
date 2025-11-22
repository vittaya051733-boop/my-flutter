import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'utils/app_colors.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

/// หน้าแสดง QR Code สำหรับไรเดอร์
/// - Order QR: ให้ไรเดอร์สแกนตอนรับสินค้า
/// - Location QR: ให้ลูกค้าสแกนตอนรับสินค้า
import 'models/order_model.dart';

class OrderQRScreen extends StatelessWidget {
  Future<void> _printQR(BuildContext context, String qrData, List items) async {
    final printer = BlueThermalPrinter.instance;
    try {
      // สแกนหาอุปกรณ์ที่จับคู่แล้ว
      List<BluetoothDevice> devices = await printer.getBondedDevices();
      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบเครื่องปริ้นเตอร์ที่เชื่อมต่อ')),
        );
        return;
      }
      // เชื่อมต่อเครื่องแรก
      await printer.connect(devices.first);
      // สั่งพิมพ์ QR (พิมพ์ข้อความ QR data)
      await printer.write('QR: $qrData');
      await printer.write('--------------------------');
      await printer.write('รายละเอียดสินค้า');
      for (var item in items) {
        await printer.write('${item.productName} x${item.quantity} ฿${item.price.toStringAsFixed(2)}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('พิมพ์ QR และรายละเอียดสินค้าแล้ว')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }
  final DetailedOrder order;
  const OrderQRScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code สำหรับไรเดอร์'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            
            
            // Location QR
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'QR พิกัดลูกค้า',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300, width: 2),
                      ),
                      child: QrImageView(
                        data: 'LOCATION:${order.orderId}',
                        version: QrVersions.auto,
                        size: 250.0,
                        backgroundColor: Colors.white,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.blue.shade700,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'LOCATION:${order.orderId.substring(0, order.orderId.length > 8 ? 8 : order.orderId.length)}...',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // แสดงรายละเอียดสินค้าใต้ QR Code
            if (order.items.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.yellow.shade50,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('รายละเอียดสินค้า', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(item.productName, style: const TextStyle(fontSize: 14))),
                            Text('x${item.quantity}', style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 12),
                            Text('฿${item.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, color: Colors.black54)),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ],
            // ปุ่มแชร์/พิมพ์ (อาจเพิ่มในอนาคต)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Implement share QR
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ฟีเจอร์แชร์ยังไม่พร้อมใช้งาน')),
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('แชร์ QR'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppColors.accent),
                      foregroundColor: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _printQR(context, 'LOCATION:${order.orderId}', order.items);
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('พิมพ์ QR'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppColors.accent),
                      foregroundColor: AppColors.accent,
                    ),
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
