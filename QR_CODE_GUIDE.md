# คู่มือสร้าง QR Code สำหรับออเดอร์และพิกัดลูกค้า

## ภาพรวม
ระบบ QR Code ใช้สำหรับตรวจสอบสถานะการจัดส่งสินค้า โดยมี QR 2 ประเภท:

1. **Order QR** - QR สำหรับสินค้า (เมื่อไรเดอร์สแกน → สถานะเปลี่ยนเป็น `delivering`)
2. **Location QR** - QR สำหรับพิกัดลูกค้า (เมื่อไรเดอร์สแกน → สถานะเปลี่ยนเป็น `delivered`)

## รูปแบบ QR Code

### 1. Order QR Code
```
ORDER:{orderId}
```
**ตัวอย่าง:** `ORDER:abc123xyz456`

### 2. Location QR Code
```
LOCATION:{orderId}
```
**ตัวอย่าง:** `LOCATION:abc123xyz456`

## วิธีสร้าง QR Code

### ใช้ Flutter Package `qr_flutter`

1. เพิ่ม dependency ใน `pubspec.yaml`:
```yaml
dependencies:
  qr_flutter: ^4.1.0
```

2. สร้าง Widget สำหรับแสดง QR:
```dart
import 'package:qr_flutter/qr_flutter.dart';

// Order QR
QrImageView(
  data: 'ORDER:$orderId',
  version: QrVersions.auto,
  size: 200.0,
)

// Location QR
QrImageView(
  data: 'LOCATION:$orderId',
  version: QrVersions.auto,
  size: 200.0,
)
```

## การใช้งานในระบบ

### 1. สร้าง QR เมื่อร้านยืนยันออเดอร์
```dart
// ในหน้า OrderManagementScreen หลังกด Accept
void _acceptOrder(String orderId) async {
  await FirebaseFirestore.instance
    .collection('orders')
    .doc(orderId)
    .update({
      'status': 'accepted',
      'acceptedAt': Timestamp.now(),
      // บันทึกข้อมูล QR
      'orderQRCode': 'ORDER:$orderId',
      'locationQRCode': 'LOCATION:$orderId',
    });
}
```

### 2. แสดง QR ให้ไรเดอร์สแกน
สร้างหน้าใหม่ `lib/order_qr_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'utils/app_colors.dart';

class OrderQRScreen extends StatelessWidget {
  final String orderId;
  const OrderQRScreen({super.key, required this.orderId});

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
            // Order QR
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'QR สินค้า',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ให้ไรเดอร์สแกนตอนรับสินค้า',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    QrImageView(
                      data: 'ORDER:$orderId',
                      version: QrVersions.auto,
                      size: 250.0,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ORDER:${orderId.substring(0, 8)}...',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Location QR
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'QR พิกัดลูกค้า',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ให้ลูกค้าสแกนตอนรับสินค้า',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    QrImageView(
                      data: 'LOCATION:$orderId',
                      version: QrVersions.auto,
                      size: 250.0,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'LOCATION:${orderId.substring(0, 8)}...',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 3. เพิ่มปุ่มแสดง QR ในหน้า OrderManagementScreen
```dart
// เพิ่มในส่วนของ Card แต่ละออเดอร์
if (order.status == 'ready')
  ElevatedButton.icon(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderQRScreen(orderId: order.id),
        ),
      );
    },
    icon: const Icon(Icons.qr_code),
    label: const Text('แสดง QR'),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
    ),
  ),
```

### 4. สร้างพิกัด QR สำหรับลูกค้า (อัตโนมัติเมื่อสร้างออเดอร์)
```dart
// ใน Cloud Functions หรือตอนลูกค้าสั่งสินค้า
await FirebaseFirestore.instance.collection('orders').add({
  // ... ข้อมูลออเดอร์อื่นๆ
  'orderQRCode': 'ORDER:${orderId}',
  'locationQRCode': 'LOCATION:${orderId}',
  'createdAt': Timestamp.now(),
});
```

## Flow การทำงาน

```
1. ลูกค้าสั่งสินค้า → สร้างออเดอร์ + QR 2 อัน
2. ร้านค้ายืนยัน (Accept) → แสดงปุ่ม "แสดง QR"
3. ร้านค้ากดแสดง QR → แสดง Order QR + Location QR
4. ไรเดอร์มารับสินค้า → สแกน Order QR → สถานะเป็น "delivering"
5. ไรเดอร์ส่งถึงลูกค้า → สแกน Location QR → สถานะเป็น "delivered"
```

## ข้อควรระวัง

1. **QR Code ต้องไม่ซ้ำกัน** - ใช้ orderId ที่ unique
2. **Location QR ส่งให้ลูกค้า** - ส่งผ่าน notification หรือ SMS
3. **ตรวจสอบสิทธิ์** - ตรวจสอบว่าไรเดอร์คนเดียวกันที่รับออเดอร์
4. **Format QR ต้องตรงกัน** - ใช้ `ORDER:` และ `LOCATION:` เป็น prefix

## Dependencies ที่ต้องเพิ่ม

```yaml
dependencies:
  qr_flutter: ^4.1.0        # สำหรับสร้าง QR
  mobile_scanner: ^3.5.5    # สำหรับสแกน QR (ใช้แล้ว)
```

## เอกสารอ้างอิง
- [qr_flutter package](https://pub.dev/packages/qr_flutter)
- [mobile_scanner package](https://pub.dev/packages/mobile_scanner)
