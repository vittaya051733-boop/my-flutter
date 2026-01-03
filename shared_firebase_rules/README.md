# Shared Firebase Rules (Unrestricted)

ไฟล์ในโฟลเดอร์นี้เป็น "ชุด rules กลาง" สำหรับคัดลอกไปใช้ได้ทุก Firebase project

- `firestore.rules` เปิด Firestore อ่าน/เขียนทั้งหมด
- `storage.rules` เปิด Storage อ่าน/เขียนทั้งหมด

> ข้อควรระวัง: rules แบบ `if true` คือเปิดสาธารณะ 100% เหมาะเฉพาะ dev/testing เท่านั้น

## วิธีใช้ในแต่ละโปรเจ็กต์

1. คัดลอกไฟล์สองไฟล์นี้ไปไว้ที่ root ของโปรเจ็กต์ (หรือจะเก็บไว้ในโฟลเดอร์ก็ได้)
2. แก้ `firebase.json` ให้ชี้ไปที่ rules:

```json
{
  "firestore": { "rules": "firestore.rules" },
  "storage": { "rules": "storage.rules" }
}
```

> ถ้าคุณเก็บไว้ในโฟลเดอร์ ให้ใส่ path ตามจริง เช่น `shared_firebase_rules/firestore.rules`

3. Deploy:

- เลือกโปรเจ็กต์: `firebase use <projectId>`
- Deploy rules: `firebase deploy --only firestore:rules,storage`

## ถ้ายังเจอ unauthorized / permission-denied

ถ้า Firebase Console เปิด App Check Enforcement ไว้ (Firestore/Storage) จะโดนบล็อกก่อนถึง rules
ให้ไปที่ Firebase Console → Build → App Check → Enforcement แล้วตั้งเป็น Off/Monitoring ชั่วคราว
