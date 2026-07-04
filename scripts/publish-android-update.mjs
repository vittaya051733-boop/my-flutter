/**
 * Publish van1 Android OTA metadata to Firestore app_updates/android.
 * Usage: node scripts/publish-android-update.mjs
 */
import { createRequire } from 'node:module';

const require = createRequire(
  new URL('../../../van2/functions/package.json', import.meta.url),
);
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'van-merchant' });
}

const db = admin.firestore();

const payload = {
  latestVersionCode: 3,
  latestVersionName: '1.0.7',
  minSupportedVersionCode: 2,
  apkUrl:
    'https://firebasestorage.googleapis.com/v0/b/van-merchant-van1-storage-802503541368/o/releases%2Fvanmerchant-1.0.7.apk?alt=media&token=f57e97f3-d0d9-40b6-a3e8-9313b42064b3',
  releaseNotes:
    '- รองรับ Android 13+ อ่านรูป/วิดีโอ (READ_MEDIA)\n- ปรับ OTA ติดตั้ง APK ให้เสถียรขึ้น\n- ปรับปรุงหน้าจัดการสินค้าและร้านค้า',
  sizeBytes: 340659678,
  sha256:
    'e0fe5cd26d514a22558430db75e5d7f2bbc2acf406d77613e769cee6388d3982',
  forceUpdate: false,
  updatedAt: Date.now(),
};

await db.collection('app_updates').doc('android').set(payload, { merge: true });
console.log('Updated app_updates/android:', payload);
