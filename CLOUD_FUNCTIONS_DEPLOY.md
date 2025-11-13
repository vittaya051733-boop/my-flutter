# Cloud Functions Deployment Guide - คู่มือ Deploy แบบละเอียด

## 📋 สิ่งที่ต้องเตรียมก่อน Deploy

### 1. ตรวจสอบ Requirements
```powershell
# ตรวจสอบ Node.js version (ต้องเป็น 22.x)
node --version

# ตรวจสอบ npm version
npm --version

# ถ้ายังไม่มี Node.js ให้ติดตั้งจาก: https://nodejs.org/
```

### 2. ติดตั้ง Firebase CLI
```powershell
# ติดตั้ง Firebase Tools
npm install -g firebase-tools

# ตรวจสอบว่าติดตั้งสำเร็จ
firebase --version
```

### 3. Login เข้า Firebase
```powershell
firebase login
# จะเปิด browser ให้ login ด้วย Google Account ที่มี Firebase Project
```

### 4. ตรวจสอบ Firebase Project
```powershell
cd C:\Users\TAM\Desktop\t3\my-flutter
firebase projects:list
# ดูรายการ projects ทั้งหมด

firebase use --add
# เลือก project ที่ต้องการใช้
```

---

## 🚀 วิธีที่ 1: Deploy ผ่าน Firebase Console (แนะนำสำหรับ Windows)

### ขั้นตอนที่ 1: เปิด Firebase Console
1. ไปที่ [Firebase Console](https://console.firebase.google.com)
2. เลือก Project ของคุณ
3. ไปที่เมนู **Build** → **Functions** ที่แถบซ้าย

### ขั้นตอนที่ 2: สร้าง Function แรก (checkPreparingOrders)
1. คลิกปุ่ม **Create function**
2. ตั้งค่าดังนี้:
   - **Function name:** `checkPreparingOrders`
   - **Region:** `asia-southeast1` (Singapore)
   - **Trigger type:** Cloud Pub/Sub (Scheduled)
   - **Schedule:** `every 1 minutes`
   - **Runtime:** Node.js 22

3. คัดลอกโค้ดจาก `functions/index.js` ส่วน `checkPreparingOrders`:
```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

exports.checkPreparingOrders = functions
  .region('asia-southeast1')
  .pubsub.schedule('every 1 minutes')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    
    const snapshot = await db.collection('orders')
      .where('status', 'in', ['accepted', 'preparing'])
      .get();
    
    if (snapshot.empty) {
      console.log('No preparing orders found');
      return null;
    }

    const batch = db.batch();
    const notifications = [];

    for (const doc of snapshot.docs) {
      const order = doc.data();
      const orderRef = db.collection('orders').doc(doc.id);
      
      const acceptedTime = order.acceptedAt?.toMillis() || order.createdAt?.toMillis();
      if (!acceptedTime) continue;

      const elapsedMinutes = (now.toMillis() - acceptedTime) / 60000;
      const notificationStatus = order.notificationStatus || {};

      // 5 นาที - แจ้งเตือนครั้งแรก
      if (elapsedMinutes >= 5 && !notificationStatus.at5min) {
        batch.update(orderRef, {
          'notificationStatus.at5min': true,
          'notificationStatus.at5minTime': now,
        });
        notifications.push({
          shopFCMToken: order.shopFCMToken,
          title: '⏰ เหลือเวลา 5 นาที',
          body: `ออเดอร์ #${doc.id.substring(0, 8)} กรุณารีบเตรียมสินค้า`,
        });
      }

      // 7.5 นาที - แจ้งเตือนครั้งที่สอง
      if (elapsedMinutes >= 7.5 && !notificationStatus.at7_5min) {
        batch.update(orderRef, {
          'notificationStatus.at7_5min': true,
          'notificationStatus.at7_5minTime': now,
        });
        notifications.push({
          shopFCMToken: order.shopFCMToken,
          title: '⚠️ เหลือเวลา 2.5 นาที',
          body: `ออเดอร์ #${doc.id.substring(0, 8)} กรุณารีบเตรียมสินค้า!`,
        });
      }

      // 10 นาที - เกินเวลา + คำนวณค่าปรับ
      if (elapsedMinutes >= 10 && !notificationStatus.at10min) {
        const penalty = calculatePenalty(elapsedMinutes);
        batch.update(orderRef, {
          'notificationStatus.at10min': true,
          'notificationStatus.at10minTime': now,
          'penalty': penalty,
          'isLate': true,
        });
        notifications.push({
          shopFCMToken: order.shopFCMToken,
          title: '🚨 เกินเวลากำหนด',
          body: `ออเดอร์ #${doc.id.substring(0, 8)} ค่าปรับ ${penalty} บาท`,
        });
      }
    }

    await batch.commit();

    // ส่ง notifications
    for (const notif of notifications) {
      if (notif.shopFCMToken) {
        try {
          await admin.messaging().send({
            token: notif.shopFCMToken,
            notification: {
              title: notif.title,
              body: notif.body,
            },
            android: { priority: 'high' },
            apns: { payload: { aps: { sound: 'default' } } },
          });
        } catch (error) {
          console.error('Error sending notification:', error);
        }
      }
    }

    console.log(`Processed ${snapshot.size} orders, sent ${notifications.length} notifications`);
    return null;
  });

function calculatePenalty(elapsedMinutes) {
  if (elapsedMinutes <= 10) return 0;
  const overtimeMinutes = elapsedMinutes - 10;
  return Math.floor(overtimeMinutes / 5) * 10;
}
```

4. คลิก **Deploy**

### ขั้นตอนที่ 3: สร้าง Function ที่สอง (onOrderStatusUpdate)
1. คลิกปุ่ม **Create function** อีกครั้ง
2. ตั้งค่า:
   - **Function name:** `onOrderStatusUpdate`
   - **Region:** `asia-southeast1`
   - **Trigger type:** Cloud Firestore
   - **Event type:** Document Written (Create, Update, Delete)
   - **Document path:** `orders/{orderId}`
   - **Runtime:** Node.js 22

3. คัดลอกโค้ด:
```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.onOrderStatusUpdate = functions
  .region('asia-southeast1')
  .firestore.document('orders/{orderId}')
  .onWrite(async (change, context) => {
    if (!change.after.exists) return null;

    const newOrder = change.after.data();
    const oldOrder = change.before.exists ? change.before.data() : null;

    if (!oldOrder || oldOrder.status === newOrder.status) {
      return null;
    }

    const orderId = context.params.orderId;
    const notifications = [];

    // สินค้าพร้อม → แจ้งไรเดอร์
    if (newOrder.status === 'ready' && newOrder.driverFCMToken) {
      notifications.push({
        token: newOrder.driverFCMToken,
        title: '📦 สินค้าพร้อมรับ',
        body: `ออเดอร์ #${orderId.substring(0, 8)} ที่ ${newOrder.shopName}`,
      });
    }

    // เริ่มจัดส่ง → แจ้งลูกค้า
    if (newOrder.status === 'delivering' && newOrder.customerFCMToken) {
      notifications.push({
        token: newOrder.customerFCMToken,
        title: '🚚 กำลังจัดส่ง',
        body: `ออเดอร์ของคุณกำลังเดินทาง จะถึงภายใน ${newOrder.estimatedDeliveryTime || 30} นาที`,
      });
    }

    // ส่งสำเร็จ → แจ้งลูกค้า
    if (newOrder.status === 'delivered' && newOrder.customerFCMToken) {
      notifications.push({
        token: newOrder.customerFCMToken,
        title: '✅ ส่งสำเร็จ',
        body: 'ขอบคุณที่ใช้บริการ กรุณาให้คะแนน',
      });
    }

    // ส่ง notifications
    for (const notif of notifications) {
      try {
        await admin.messaging().send({
          token: notif.token,
          notification: {
            title: notif.title,
            body: notif.body,
          },
          android: { priority: 'high' },
          apns: { payload: { aps: { sound: 'default' } } },
        });
      } catch (error) {
        console.error('Error sending notification:', error);
      }
    }

    return null;
  });
```

4. คลิก **Deploy**

### ขั้นตอนที่ 4: สร้าง Function ที่สาม (calculateDeliveryTime)
1. คลิกปุ่ม **Create function** อีกครั้ง
2. ตั้งค่า:
   - **Function name:** `calculateDeliveryTime`
   - **Region:** `asia-southeast1`
   - **Trigger type:** HTTPS (Callable)
   - **Runtime:** Node.js 22

3. คัดลอกโค้ด:
```javascript
const functions = require('firebase-functions');

exports.calculateDeliveryTime = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    const { shopLat, shopLng, customerLat, customerLng } = data;

    if (!shopLat || !shopLng || !customerLat || !customerLng) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required coordinates'
      );
    }

    const distance = calculateDistance(shopLat, shopLng, customerLat, customerLng);
    const estimatedMinutes = Math.ceil(distance / 0.5) + 5;

    return {
      distanceKm: distance.toFixed(2),
      estimatedMinutes: estimatedMinutes,
      estimatedArrival: new Date(Date.now() + estimatedMinutes * 60000).toISOString(),
    };
  });

function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}
```

4. คลิก **Deploy**

### ขั้นตอนที่ 5: ตรวจสอบ Functions
1. ดูใน Firebase Console → Functions
2. ตรวจสอบว่ามี 3 functions:
   - ✅ `checkPreparingOrders` (Scheduled)
   - ✅ `onOrderStatusUpdate` (Firestore Trigger)
   - ✅ `calculateDeliveryTime` (Callable)
3. ดู Logs ได้ที่แท็บ **Logs**

---

## 🚀 วิธีที่ 2: Deploy ผ่าน Firebase CLI (ถ้า npm ใช้งานได้)

### ขั้นตอนที่ 1: ตรวจสอบไฟล์
```powershell
cd C:\Users\TAM\Desktop\t3\my-flutter\functions

# ตรวจสอบว่ามีไฟล์ครบ
dir
# ต้องมี: index.js, package.json
```

### ขั้นตอนที่ 2: ติดตั้ง Dependencies (อาจมีปัญหาบน Windows)
```powershell
# ลองวิธีนี้ก่อน
npm install

# ถ้าไม่ได้ ลองเป็น Administrator
# คลิกขวา PowerShell → Run as Administrator
npm install --force

# หรือลองใช้ yarn แทน
npm install -g yarn
yarn install
```

### ขั้นตอนที่ 3: Deploy
```powershell
# กลับไปที่ root ของ project
cd ..

# Deploy เฉพาะ functions
firebase deploy --only functions

# หรือ deploy ทีละ function
firebase deploy --only functions:checkPreparingOrders
firebase deploy --only functions:onOrderStatusUpdate
firebase deploy --only functions:calculateDeliveryTime
```

### ขั้นตอนที่ 4: ตรวจสอบผลลัพธ์
```
✔  functions[checkPreparingOrders(asia-southeast1)] Successful update operation.
✔  functions[onOrderStatusUpdate(asia-southeast1)] Successful update operation.
✔  functions[calculateDeliveryTime(asia-southeast1)] Successful update operation.
```

---

## 🧪 วิธีที่ 3: ทดสอบด้วย Local Emulator (สำหรับ Development)

### ขั้นตอนที่ 1: เริ่ม Emulator
```powershell
cd C:\Users\TAM\Desktop\t3\my-flutter

# เริ่ม Emulator
firebase emulators:start --only functions,firestore

# หรือเริ่มพร้อม UI
firebase emulators:start --only functions,firestore --project=your-project-id
```

### ขั้นตอนที่ 2: ดู Emulator UI
- เปิดเบราว์เซอร์ไปที่: `http://localhost:4000`
- จะเห็น Functions, Firestore, และ Logs

### ขั้นตอนที่ 3: ใช้ Emulator ใน Flutter App
แก้ `lib/main.dart`:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // เชื่อมต่อ Emulator (เฉพาะ Development)
  if (kDebugMode) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  }

  runApp(const MyApp());
}
```

---

## ❓ แก้ปัญหาที่พบบ่อย

### ปัญหา: npm install ไม่ได้ (EPERM)
**วิธีแก้:**
1. ใช้วิธีที่ 1 (Deploy ผ่าน Firebase Console) แทน
2. หรือย้ายโฟลเดอร์ไปที่ path สั้นๆ เช่น `C:\temp\functions`

### ปัญหา: Firebase CLI ไม่ทำงาน
**วิธีแก้:**
```powershell
# ถอนการติดตั้งและติดตั้งใหม่
npm uninstall -g firebase-tools
npm install -g firebase-tools

# ตรวจสอบ PATH
firebase --version
```

### ปัญหา: Function deploy ไม่สำเร็จ
**วิธีแก้:**
```powershell
# ดู logs
firebase functions:log

# ลอง deploy ทีละ function
firebase deploy --only functions:checkPreparingOrders
```

### ปัญหา: Notification ไม่ส่ง
**ตรวจสอบ:**
1. FCM Token บันทึกใน Firestore ถูกต้องหรือไม่
2. Firebase Cloud Messaging เปิดใช้งานใน Firebase Console หรือไม่
3. ดู Logs ใน Firebase Console → Functions → Logs

---

## ✅ Checklist หลัง Deploy

- [ ] Functions ทั้ง 3 ตัว deploy สำเร็จ
- [ ] ตรวจสอบ Logs ใน Firebase Console ไม่มี error
- [ ] ทดสอบสร้างออเดอร์ใหม่ และกด Accept
- [ ] ตรวจสอบว่า notification ส่งที่ 5, 7.5, 10 นาที
- [ ] ทดสอบสถานะเปลี่ยนเป็น ready → แจ้งไรเดอร์
- [ ] ทดสอบสถานะเปลี่ยนเป็น delivering → แจ้งลูกค้า
- [ ] ทดสอบสถานะเปลี่ยนเป็น delivered → แจ้งลูกค้า

---

## 📚 เอกสารอ้างอิง
- [Firebase Functions Documentation](https://firebase.google.com/docs/functions)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)
- [Cloud Functions Emulator](https://firebase.google.com/docs/emulator-suite)
- [Troubleshooting Guide](https://firebase.google.com/docs/functions/troubleshooting)
