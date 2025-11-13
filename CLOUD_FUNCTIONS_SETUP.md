# คำแนะนำการติดตั้ง Cloud Functions

## ปัญหาที่พบ
- Windows มีข้อจำกัดเรื่อง file path ที่ยาว
- npm มีปัญหา EPERM (permission) กับบาง packages

## วิธีแก้ไข

### วิธีที่ 1: ใช้ Firebase Console (แนะนำ)
1. เปิด [Firebase Console](https://console.firebase.google.com)
2. เลือก Project ของคุณ
3. ไปที่ Functions → Get Started
4. คัดลอกโค้ดจาก `functions/index.js` ไปวางใน Firebase Console
5. Deploy จาก Console

### วิธีที่ 2: Deploy ผ่าน Firebase CLI
```powershell
# ติดตั้ง Firebase Tools (ถ้ายังไม่ได้ติดตั้ง)
npm install -g firebase-tools

# Login
firebase login

# Deploy (อาจต้องรันเป็น Administrator)
cd C:\Users\TAM\Desktop\t3\my-flutter
firebase deploy --only functions
```

### วิธีที่ 3: ใช้ Cloud Functions Emulator (สำหรับ Development)
```powershell
# Run Emulator
firebase emulators:start --only functions
```

## Cloud Functions ที่ต้องติดตั้ง

### 1. checkPreparingOrders (Scheduled Function)
- ทำงานทุก 1 นาที
- ตรวจสอบออเดอร์ที่กำลังเตรียม
- ส่งการแจ้งเตือนที่ 5, 7.5, 10 นาที
- คำนวณค่าปรับ

### 2. onOrderStatusUpdate (Firestore Trigger)
- ทำงานอัตโนมัติเมื่อสถานะออเดอร์เปลี่ยน
- แจ้งเตือนพนักงานขนส่งเมื่อสินค้าพร้อม
- แจ้งเตือนลูกค้าเมื่อกำลังจัดส่ง

### 3. calculateDeliveryTime (Callable Function)
- คำนวณระยะทางและเวลาจัดส่ง
- เรียกใช้จากแอพได้

## ทางเลือก: ใช้ Flutter เพียงอย่างเดียว

หากไม่สามารถติดตั้ง Cloud Functions ได้ สามารถใช้ Flutter Timer ใน app แทนได้:

```dart
// ใน order_management_screen_new.dart
// เพิ่ม local notification scheduler
Timer.periodic(Duration(minutes: 1), (timer) {
  // ตรวจสอบเวลาและส่งการแจ้งเตือน local
});
```

**ข้อจำกัด:** แอพต้องเปิดอยู่ตลอดเวลา ไม่สามารถส่งการแจ้งเตือนเมื่อแอพปิดได้
