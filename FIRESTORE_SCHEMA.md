# Firestore Schema สำหรับระบบ Orders

## Collection: orders

```
orders/
  {orderId}/
    // ข้อมูลพื้นฐาน
    - orderId: string
    - customerId: string
    - shopId: string
    - createdAt: timestamp
    - updatedAt: timestamp
    
    // ข้อมูลสินค้า
    - items: array [
        {
          productId: string,
          productName: string,
          quantity: number,
          price: number,
          imageUrl: string?,
          toppings: string?,
        }
      ]
    - totalAmount: number
    - totalItems: number
    
    // สถานะและเวลา
    - status: string (pending | accepted | preparing | ready | delivering | delivered | cancelled)
    - acceptedAt: timestamp?
    - preparingStartTime: timestamp?
    - preparingDuration: number (10 minutes = 600000 ms)
    - readyAt: timestamp?
    - deliveryStartTime: timestamp?
    - deliveredAt: timestamp?
    
    // การแจ้งเตือน
    - notifications: map {
        firstWarning: { sent: boolean, sentAt: timestamp?, timeInMinutes: 5 }
        secondWarning: { sent: boolean, sentAt: timestamp?, timeInMinutes: 7.5 }
        finalWarning: { sent: boolean, sentAt: timestamp?, timeInMinutes: 10 }
      }
    - penalty: number (default: 0, เพิ่มถ้าเกิน 10 นาที)
    
    // ข้อมูลตำแหน่ง
    - customerLocation: geopoint
    - customerAddress: string
    - shopLocation: geopoint
    - shopAddress: string
    - distance: number (in meters)
    - estimatedDeliveryTime: number (in minutes)
    
    // QR Code
    - orderQRCode: string (สำหรับพนักงานสแกน)
    - locationQRCode: string (สำหรับยืนยันตำแหน่ง)
    - scannedByDriverId: string?
    - scannedAt: timestamp?
    
    // ข้อมูลผู้ใช้
    - customerName: string
    - customerPhone: string
    - driverId: string?
    - driverName: string?
    
    // FCM Tokens
    - shopFCMToken: string?
    - customerFCMToken: string?
    - driverFCMToken: string?
```

## Collection: orderTimeline (subcollection ของ orders)

```
orders/{orderId}/timeline/
  {timelineId}/
    - timestamp: timestamp
    - status: string
    - message: string
    - userId: string
    - userRole: string (shop | customer | driver)
```

## Indexes ที่ต้องสร้าง

```
1. orders: shopId (ascending), status (ascending), createdAt (descending)
2. orders: customerId (ascending), status (ascending), createdAt (descending)
3. orders: driverId (ascending), status (ascending), createdAt (descending)
4. orders: status (ascending), preparingStartTime (ascending)
```

## Security Rules (สำคัญ)

อัปเดต Firestore Rules ใน Firebase Console ให้เปิดสิทธิ์ตามการใช้งานจริง มิฉะนั้นแอปจะเจอ `permission-denied` ทันทีที่เปิดขึ้นมา

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ข้อมูลอัปเดตแอปฯ ต้องอ่านได้ก่อนล็อกอิน
    match /app_updates/{docId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.token.admin == true;
    }

    // ข้อมูลสัญญา/ลงทะเบียนร้านค้า - ให้เจ้าของอ่าน/เขียนได้เองเท่านั้น
    match /contracts/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    match /{collectionName}/{userId} where
        collectionName in ['market_registrations', 'shop_registrations', 'restaurant_registrations', 'pharmacy_registrations'] {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

> หมายเหตุ: ถ้าใช้งาน Cloud Function หรือ Admin SDK อื่นๆ ให้ปรับเงื่อนไข `allow write` ให้เหมาะสม เช่น เช็ค custom claims `admin` ตามตัวอย่างด้านบน
