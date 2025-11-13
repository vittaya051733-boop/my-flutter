import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Helper สำหรับสร้างออเดอร์ทดสอบ
/// วิธีใช้: เรียก createTestOrder() ใน home_screen.dart หรือที่ใดก็ได้
Future<String> createTestOrder() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('User not logged in');

  final now = Timestamp.now();
  
  // สร้าง order document
  final orderRef = FirebaseFirestore.instance.collection('orders').doc();
  final orderId = orderRef.id;

  await orderRef.set({
    // ข้อมูลพื้นฐาน
    'orderId': orderId,
    'status': 'pending', // pending → accepted → preparing → ready → delivering → delivered
    'createdAt': now,
    'updatedAt': now,
    
    // ข้อมูลร้าน
    'shopId': user.uid,
    'shopName': 'ร้านทดสอบ',
    'shopAddress': '123 ถนนทดสอบ',
    'shopLat': 13.7563,
    'shopLng': 100.5018,
    'shopPhone': '081-234-5678',
    'shopFCMToken': '', // จะถูก update จาก NotificationService
    
    // ข้อมูลลูกค้า
    'customerId': 'test_customer_001',
    'customerName': 'ลูกค้าทดสอบ',
    'customerAddress': '456 ถนนลูกค้า',
    'customerLat': 13.7650,
    'customerLng': 100.5380,
    'customerPhone': '089-876-5432',
    'customerFCMToken': '', // ลูกค้าจริงต้องมี
    
    // ข้อมูลสินค้า
    'items': [
      {
        'productId': 'prod_001',
        'name': 'สินค้าทดสอบ 1',
        'quantity': 2,
        'price': 50.0,
        'imageUrl': '',
      },
      {
        'productId': 'prod_002',
        'name': 'สินค้าทดสอบ 2',
        'quantity': 1,
        'price': 100.0,
        'imageUrl': '',
      },
    ],
    
    // ราคา
    'subtotal': 200.0,
    'deliveryFee': 30.0,
    'total': 230.0,
    'penalty': 0,
    
    // QR Codes
    'orderQRCode': 'ORDER:$orderId',
    'locationQRCode': 'LOCATION:$orderId',
    
    // การแจ้งเตือน
    'notificationStatus': {
      'at5min': false,
      'at7_5min': false,
      'at10min': false,
    },
    
    // เวลา (จะถูก update ตามสถานะ)
    'acceptedAt': null,
    'preparingStartTime': null,
    'readyAt': null,
    'deliveryStartTime': null,
    'deliveredAt': null,
    
    // ไรเดอร์
    'driverId': null,
    'driverName': null,
    'driverPhone': null,
    'driverFCMToken': null,
    'scannedByDriverId': null,
    'scannedAt': null,
    
    // อื่นๆ
    'isLate': false,
    'estimatedDeliveryTime': 30,
    'notes': 'ออเดอร์ทดสอบระบบ',
  });

  print('✅ สร้างออเดอร์ทดสอบสำเร็จ: $orderId');
  return orderId;
}

/// ลบออเดอร์ทดสอบ
Future<void> deleteTestOrder(String orderId) async {
  await FirebaseFirestore.instance.collection('orders').doc(orderId).delete();
  print('🗑️ ลบออเดอร์ $orderId แล้ว');
}

/// สร้างออเดอร์หลายๆ สถานะเพื่อทดสอบ
Future<void> createMultipleTestOrders() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('User not logged in');

  final now = Timestamp.now();
  
  // สร้างออเดอร์แต่ละสถานะ
  final statuses = ['pending', 'accepted', 'preparing', 'ready', 'delivering'];
  
  for (final status in statuses) {
    final orderRef = FirebaseFirestore.instance.collection('orders').doc();
    final orderId = orderRef.id;
    
    final data = {
      'orderId': orderId,
      'status': status,
      'createdAt': now,
      'updatedAt': now,
      'shopId': user.uid,
      'shopName': 'ร้านทดสอบ $status',
      'shopAddress': '123 ถนนทดสอบ',
      'shopLat': 13.7563,
      'shopLng': 100.5018,
      'shopPhone': '081-234-5678',
      'shopFCMToken': '',
      'customerId': 'test_customer_$status',
      'customerName': 'ลูกค้า $status',
      'customerAddress': '456 ถนนลูกค้า',
      'customerLat': 13.7650,
      'customerLng': 100.5380,
      'customerPhone': '089-876-5432',
      'customerFCMToken': '',
      'items': [
        {
          'productId': 'prod_001',
          'name': 'สินค้า $status',
          'quantity': 1,
          'price': 100.0,
          'imageUrl': '',
        },
      ],
      'subtotal': 100.0,
      'deliveryFee': 30.0,
      'total': 130.0,
      'penalty': 0,
      'orderQRCode': 'ORDER:$orderId',
      'locationQRCode': 'LOCATION:$orderId',
      'notificationStatus': {
        'at5min': false,
        'at7_5min': false,
        'at10min': false,
      },
      'acceptedAt': status != 'pending' ? now : null,
      'preparingStartTime': status == 'preparing' || status == 'ready' ? now : null,
      'readyAt': status == 'ready' || status == 'delivering' ? now : null,
      'deliveryStartTime': status == 'delivering' ? now : null,
      'deliveredAt': null,
      'driverId': null,
      'driverName': null,
      'driverPhone': null,
      'driverFCMToken': null,
      'scannedByDriverId': null,
      'scannedAt': null,
      'isLate': false,
      'estimatedDeliveryTime': 30,
      'notes': 'ออเดอร์ทดสอบสถานะ $status',
    };
    
    await orderRef.set(data);
    print('✅ สร้างออเดอร์ $status: $orderId');
  }
}
