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
