# Firebase App Check Troubleshooting

เมื่อเปิดแอปแล้วเจอ log ลักษณะนี้

```
[firebase_app_check/unknown] com.google.firebase.FirebaseException: Error returned from API. code: 403 body: App attestation failed.
```

แปลว่า backend ของ Firebase ปฏิเสธ token เพราะอุปกรณ์ยังไม่ได้รับสิทธิ์ App Check ตามประเภท provider ที่เลือก (Play Integrity/Debug ฯลฯ)

## ขั้นตอนสำหรับเครื่องทดสอบ/Debug

1. **รันด้วย Debug Provider** – เพิ่ม `--dart-define=APP_CHECK_DEBUG=true` ตอน `flutter run` หรือ `flutter build`. ตัวแอปจะใช้ `AndroidProvider.debug` ตามโค้ดใน `lib/main.dart`.
2. **คัดลอก Debug Token** – เมื่อแอปรัน จะเห็น log `App Check Debug Token: <token>`. (หากไม่ขึ้นให้แตะปุ่มในแอปเพื่อกระตุ้น `FirebaseAppCheck.instance.getToken(true)`.)
3. **เพิ่ม Token ใน Firebase Console** – เข้า Firebase Console → Build → App Check → เลือกแอป Android → Debug tokens → Add token → วางค่าที่ได้จากข้อ 2.
4. **รอ 1-2 นาที** แล้วปิด/เปิดแอปใหม่เพื่อให้ token ใหม่ถูกอนุมัติ (ดูว่า log `Could not get App Check token...` หายไป และ Firebase API ไม่ตอบ 403 แล้ว).

> หากต้องการปิด App Check ชั่วคราว ให้ไปที่ App Check → Enforcement แล้วสลับเป็น “Off” สำหรับแอปนั้น ๆ (ไม่แนะนำใน production).

## ขั้นตอนสำหรับ Release (Play Integrity)

1. ใน Firebase Console → App Check → เลือกแอป Android → เปิดใช้งาน **Play Integrity**.
2. ตรวจสอบว่า **SHA-256** fingerprint ของ keystore ที่ใช้ build release ถูกเพิ่มใน **Firebase console + Google Cloud console** (Project Settings → App → SHA certificate fingerprints).
3. สร้าง build release ด้วย keystore เดียวกัน แล้วติดตั้งลงเครื่องจริงที่มี Play Store (อุปกรณ์ต้อง sign-in Play Services).
4. หากยังเจอ 403 อีก ให้เปิด Logs ใน Google Cloud → Logging → `firebaseappcheck.googleapis.com` เพื่อตรวจสอบรายละเอียด attestation.

## Phone Auth (OTP) — `app-not-authorized`

ถ้า logcat มีข้อความเหล่านี้:

```
Invalid app info in play_integrity_token
No Recaptcha Enterprise siteKey configured
App attestation failed (403)
```

**SHA ถูกต้องแล้ว** แต่ OTP ยังล้มเพราะ:

1. **Play Integrity** — APK sideload / emulator ไม่ผ่าน (ปกติ)
2. **reCAPTCHA Enterprise** — ยังไม่เปิด API / ยังไม่ provision ใน Firebase Auth
3. **App Check debug token** — ยังไม่ลง allow list

### แก้ใน Firebase / Google Cloud (ทำครั้งเดียว)

1. **เปิด reCAPTCHA Enterprise API**  
   Google Cloud Console → APIs → ค้นหา `reCAPTCHA Enterprise API` → Enable  
   (project: `van-merchant`)

2. **Firebase Console → Authentication → Settings**  
   เปิดหน้านี้เพื่อให้ Firebase สร้าง reCAPTCHA key อัตโนมัติ (รอ 1–2 นาที)

3. **App Check debug token** (สำหรับ emulator/debug build)  
   Firebase Console → Build → App Check → แอป `van.merchant` (Android) → Debug tokens → Add  
   ดู token จาก logcat:
   ```
   Enter this debug secret into the allow list ...: <token>
   ```
   ตัวอย่างล่าสุดจาก emulator: `ba6abe3e-c498-457c-99c7-2c6186536316`

### ทด OTP บน emulator (debug build)

1. Firebase Console → Authentication → Sign-in method → Phone → **Phone numbers for testing**  
   เพิ่มเบอร์ + OTP ที่ต้องการทด (เช่น `+817091345342` / `123456`)
2. รัน **debug build** (`appVerificationDisabledForTesting` เปิดอัตโนมัติใน `kDebugMode`)
3. ใช้เฉพาะเบอร์ที่ลงใน "Phone numbers for testing" — เบอร์จริงจะยังไม่ส่ง SMS

### Production (เบอร์จริง / sideload release)

- ต้องมี reCAPTCHA Enterprise (ข้อ 1–2 ด้านบน) **หรือ** แจก APK ผ่าน Google Play (Internal testing) เพื่อให้ Play Integrity รู้จักแอป

## สรุป

- Dev/QA → ใช้ Debug provider + ลง token
- Production → ใช้ Play Integrity และเพิ่ม SHA ทุกตัว (debug, release, CI)
- อย่าลืมอัปเดต token เมื่อเปลี่ยนอุปกรณ์ หรือ rotate keystore
