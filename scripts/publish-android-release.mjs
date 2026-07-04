/**
 * Upload van1 release APK to Storage and publish OTA metadata.
 * Usage: node scripts/publish-android-release.mjs [path-to-apk]
 */
import { createHash } from 'node:crypto';
import { createReadStream, statSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const appRoot = resolve(__dirname, '..');
const defaultApk = resolve(
  appRoot,
  'build/app/outputs/flutter-apk/app-release.apk',
);
const apkPath = resolve(process.argv[2] ?? defaultApk);

const versionName = '1.0.13';
const versionCode = 9;
const storagePath = `releases/vanmerchant-${versionName}.apk`;
const bucketName = 'van-merchant-van1-storage-802503541368';

const require = createRequire(
  new URL('../../../van2/functions/package.json', import.meta.url),
);
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'van-merchant',
    storageBucket: bucketName,
  });
}

function sha256File(path) {
  return new Promise((resolvePromise, reject) => {
    const hash = createHash('sha256');
    createReadStream(path)
      .on('data', (chunk) => hash.update(chunk))
      .on('error', reject)
      .on('end', () => resolvePromise(hash.digest('hex')));
  });
}

const sizeBytes = statSync(apkPath).size;
const sha256 = await sha256File(apkPath);
const downloadToken = randomUUID();
const bucket = admin.storage().bucket(bucketName);

console.log(`Uploading ${apkPath} -> gs://${bucketName}/${storagePath}`);
await bucket.upload(apkPath, {
  destination: storagePath,
  metadata: {
    contentType: 'application/vnd.android.package-archive',
    metadata: {
      firebaseStorageDownloadTokens: downloadToken,
    },
  },
});

const encodedPath = encodeURIComponent(storagePath);
const apkUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodedPath}?alt=media&token=${downloadToken}`;

const payload = {
  latestVersionCode: versionCode,
  latestVersionName: versionName,
  minSupportedVersionCode: 2,
  apkUrl,
  releaseNotes:
    '- แก้ไขสินค้า/สต็อกบันทึกทันที ไม่ส่งแอดมินอนุมัติใหม่\n' +
    '- โหมดแก้ไขล็อกรูป/วิดีโอ แต่แก้น้ำหนักได้\n' +
    '- เว็บ: เลือกรูป/วิดีโอสินค้าจากเครื่องได้ (FilePicker)',
  sizeBytes,
  sha256,
  forceUpdate: false,
  updatedAt: Date.now(),
};

await admin.firestore().collection('app_updates').doc('android').set(payload, {
  merge: true,
});

console.log('Published app_updates/android');
console.log(JSON.stringify(payload, null, 2));
