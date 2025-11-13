# วิธี Deploy Cloud Functions ผ่าน Firebase Console

เนื่องจาก npm มีปัญหาใน Windows ให้ใช้วิธีนี้แทน:

## ขั้นตอน Deploy

### 1. เปิด Firebase Console
ไปที่: https://console.firebase.google.com/project/vanmarket-50d9d/functions

### 2. สร้าง Function ทั้ง 3 ตัว

#### Function 1: checkPreparingOrders (Scheduled - ทำงานทุก 1 นาที)
1. คลิก **Create function**
2. ตั้งค่า:
   - Function name: `checkPreparingOrders`
   - Region: `asia-southeast1`
   - Trigger: Cloud Pub/Sub (Scheduled)
   - Schedule: `every 1 minutes`
   - Runtime: Node.js 22
3. คัดลอกโค้ดจากไฟล์ `functions/index.js` (บรรทัด 5-88)
4. คลิก Deploy

#### Function 2: onOrderStatusUpdate (Firestore Trigger)
1. คลิก **Create function**
2. ตั้งค่า:
   - Function name: `onOrderStatusUpdate`
   - Region: `asia-southeast1`
   - Trigger: Cloud Firestore
   - Event type: Document Written
   - Document path: `orders/{orderId}`
   - Runtime: Node.js 22
3. คัดลอกโค้ดจากไฟล์ `functions/index.js` (บรรทัด 90-147)
4. คลิก Deploy

#### Function 3: calculateDeliveryTime (Callable Function)
1. คลิก **Create function**
2. ตั้งค่า:
   - Function name: `calculateDeliveryTime`
   - Region: `asia-southeast1`
   - Trigger: HTTPS (Callable)
   - Runtime: Node.js 22
3. คัดลอกโค้ดจากไฟล์ `functions/index.js` (บรรทัด 149-184)
4. คลิก Deploy

### 3. ตรวจสอบผลลัพธ์
- ไปที่ Firebase Console → Functions
- ควรเห็น 3 functions:
  - ✅ checkPreparingOrders (Scheduled)
  - ✅ onOrderStatusUpdate (Firestore Trigger)
  - ✅ calculateDeliveryTime (Callable)

### 4. ดู Logs
- คลิกที่ function แต่ละตัว → แท็บ Logs
- ตรวจสอบว่าทำงานถูกต้องหรือไม่

## หรือใช้วิธีอื่น

### ตัวเลือก A: Deploy ผ่าน Google Cloud Console
1. ไปที่: https://console.cloud.google.com/functions/list?project=vanmarket-50d9d
2. คลิก "CREATE FUNCTION"
3. กรอกข้อมูลและอัพโหลดโค้ด

### ตัวเลือก B: Deploy จาก Linux/Mac/WSL
หาก Windows มีปัญหา ให้ใช้ WSL (Windows Subsystem for Linux):
```bash
# ติดตั้ง WSL และ Node.js
wsl --install
# ใน WSL:
cd /mnt/c/Users/TAM/Desktop/t3/my-flutter/functions
npm install
cd ..
firebase deploy --only functions
```

### ตัวเลือก C: ใช้ Emulator แทน (Development Only)
```powershell
# รันใน Local
firebase emulators:start --only functions,firestore
```
จากนั้นแก้ `lib/main.dart` ให้เชื่อมกับ emulator:
```dart
if (kDebugMode) {
  FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
}
```

## หมายเหตุ
- npm ใน Windows มีปัญหากับ path ยาวเกินไป
- แนะนำใช้ Firebase Console เป็นวิธีที่ง่ายที่สุด
- ถ้าจะใช้ CLI ต้องรันเป็น Administrator หรือใช้ WSL
