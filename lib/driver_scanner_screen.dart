import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'utils/app_colors.dart';

/// หน้าสำหรับพนักงานขนส่งสแกน QR Code
/// 1. สแกน QR สินค้า (Order QR) → เปลี่ยนสถานะเป็น delivering
/// 2. สแกน QR พิกัดลูกค้า (Location QR) → เปลี่ยนสถานะเป็น delivered
class DriverScannerScreen extends StatefulWidget {
  const DriverScannerScreen({super.key});

  @override
  State<DriverScannerScreen> createState() => _DriverScannerScreenState();
}

class _DriverScannerScreenState extends State<DriverScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  String? _lastScannedCode;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สแกน QR สินค้า/พิกัด'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _scannerController.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
          IconButton(
            onPressed: () => _scannerController.switchCamera(),
            icon: const Icon(Icons.flip_camera_ios),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcode,
          ),
          // Overlay with scanning area
          CustomPaint(
            painter: ScannerOverlayPainter(),
            child: Container(),
          ),
          // Instructions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_scanner, color: Colors.white, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'วางกล้องตรงกับ QR Code',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'สแกน QR สินค้า: เริ่มจัดส่ง\nสแกน QR พิกัด: ส่งสำเร็จ',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('กำลังประมวลผล...'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // ป้องกันสแกนซ้ำภายใน 2 วินาที
    if (code == _lastScannedCode) return;
    _lastScannedCode = code;

    setState(() => _isProcessing = true);
    _processQRCode(code);
  }

  Future<void> _processQRCode(String qrCode) async {
    try {
      // ตรวจสอบว่า QR เป็นประเภทไหน
      // Format: ORDER:{orderId} หรือ LOCATION:{orderId}
      
      if (qrCode.startsWith('ORDER:')) {
        final orderId = qrCode.substring(6);
        await _handleOrderQR(orderId);
      } else if (qrCode.startsWith('LOCATION:')) {
        final orderId = qrCode.substring(9);
        await _handleLocationQR(orderId);
      } else {
        _showError('QR Code ไม่ถูกต้อง');
      }
    } catch (e) {
      _showError('เกิดข้อผิดพลาด: $e');
    } finally {
      setState(() => _isProcessing = false);
      // รอ 2 วิก่อนให้สแกนใหม่ได้
      Future.delayed(const Duration(seconds: 2), () {
        _lastScannedCode = null;
      });
    }
  }

  /// สแกน QR สินค้า → เปลี่ยนสถานะเป็น delivering
  Future<void> _handleOrderQR(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('กรุณาเข้าสู่ระบบ');
      return;
    }

    final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
    final orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
      _showError('ไม่พบออเดอร์นี้');
      return;
    }

    final data = orderDoc.data()!;
    final currentStatus = data['status'] as String;

    // ตรวจสอบสถานะ ต้องเป็น ready
    if (currentStatus != 'ready') {
      _showError('ออเดอร์นี้ไม่พร้อมส่ง (สถานะ: $currentStatus)');
      return;
    }

    // อัพเดทสถานะเป็น delivering
    await orderRef.update({
      'status': 'delivering',
      'deliveryStartTime': Timestamp.now(),
      'driverId': user.uid,
      'scannedByDriverId': user.uid,
      'scannedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    if (mounted) {
      _scannerController.stop();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 12),
              Text('เริ่มจัดส่งแล้ว'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ออเดอร์: #${orderId.substring(0, 8)}'),
              const SizedBox(height: 8),
              Text('ปลายทาง: ${data['customerAddress']}'),
              const SizedBox(height: 8),
              const Text(
                'เมื่อถึงจุดหมายแล้ว ให้สแกน QR พิกัดของลูกค้า',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _scannerController.start();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('ตกลง'),
            ),
          ],
        ),
      );
    }
  }

  /// สแกน QR พิกัด → เปลี่ยนสถานะเป็น delivered
  Future<void> _handleLocationQR(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('กรุณาเข้าสู่ระบบ');
      return;
    }

    final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
    final orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
      _showError('ไม่พบออเดอร์นี้');
      return;
    }

    final data = orderDoc.data()!;
    final currentStatus = data['status'] as String;
    final driverId = data['driverId'] as String?;

    // ตรวจสอบสถานะ ต้องเป็น delivering
    if (currentStatus != 'delivering') {
      _showError('ออเดอร์นี้ยังไม่ได้จัดส่ง (สถานะ: $currentStatus)');
      return;
    }

    // ตรวจสอบว่าเป็นคนเดียวกับที่รับออเดอร์
    if (driverId != user.uid) {
      _showError('ออเดอร์นี้ไม่ได้รับโดยคุณ');
      return;
    }

    // อัพเดทสถานะเป็น delivered
    await orderRef.update({
      'status': 'delivered',
      'deliveredAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    if (mounted) {
      _scannerController.stop();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.celebration, color: Colors.green, size: 32),
              SizedBox(width: 12),
              Text('ส่งสำเร็จ!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ออเดอร์: #${orderId.substring(0, 8)}'),
              const SizedBox(height: 8),
              const Text('ส่งสินค้าเรียบร้อยแล้ว', style: TextStyle(color: Colors.green)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // กลับไปหน้าก่อนหน้า
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('เสร็จสิ้น'),
            ),
          ],
        ),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// วาด Overlay สำหรับ Scanner
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final scanAreaSize = size.width * 0.7;
    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2;
    final scanArea = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);

    // วาดพื้นหลังมืดรอบๆ scan area
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(scanArea, const Radius.circular(16))),
      ),
      paint,
    );

    // วาดกรอบสีขาว
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanArea, const Radius.circular(16)),
      borderPaint,
    );

    // วาดมุม
    final cornerPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final cornerLength = 30.0;

    // มุมบนซ้าย
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), cornerPaint);

    // มุมบนขวา
    canvas.drawLine(Offset(left + scanAreaSize - cornerLength, top), Offset(left + scanAreaSize, top), cornerPaint);
    canvas.drawLine(Offset(left + scanAreaSize, top), Offset(left + scanAreaSize, top + cornerLength), cornerPaint);

    // มุมล่างซ้าย
    canvas.drawLine(Offset(left, top + scanAreaSize - cornerLength), Offset(left, top + scanAreaSize), cornerPaint);
    canvas.drawLine(Offset(left, top + scanAreaSize), Offset(left + cornerLength, top + scanAreaSize), cornerPaint);

    // มุมล่างขวา
    canvas.drawLine(Offset(left + scanAreaSize - cornerLength, top + scanAreaSize), Offset(left + scanAreaSize, top + scanAreaSize), cornerPaint);
    canvas.drawLine(Offset(left + scanAreaSize, top + scanAreaSize - cornerLength), Offset(left + scanAreaSize, top + scanAreaSize), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
