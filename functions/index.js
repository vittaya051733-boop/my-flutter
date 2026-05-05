// ...existing code...
const functions = require('firebase-functions/v1');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const { HttpsError, onCall } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const crypto = require('crypto');
const nodemailer = require('nodemailer');
const Redis = require('ioredis');
const DEFAULT_REGION = 'asia-southeast1';
const CALL_TTL_MS = 30 * 1000; // 30 seconds
const ACTIVE_CALL_INVITES_COLLECTION = 'active_call_invites';
// แจ้งเตือนข้อความแชตใหม่ (Firestore Trigger)
exports.notifyNewChatMessage = functions.region(DEFAULT_REGION).firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate((snap, context) => _handleChatMessageTrigger('chats', snap, context));

exports.notifyLegacyChatMessage = functions.region(DEFAULT_REGION).firestore
  .document('chatRooms/{chatId}/messages/{messageId}')
  .onCreate((snap, context) => _handleChatMessageTrigger('chatRooms', snap, context));

async function _handleChatMessageTrigger(collectionName, snap, context) {
  const message = snap.data();
  if (!message) {
    console.warn(`[notifyNewChatMessage:${collectionName}] Empty snapshot`);
    return;
  }

  const chatId = context.params.chatId;
  const senderId = message.senderId;
  let receiverId = message.receiverId;

  if (!receiverId) {
    receiverId = await _resolveReceiverId(chatId, senderId);
  }

  if (!receiverId) {
    console.warn(`[notifyNewChatMessage:${collectionName}] Unable to resolve receiver for chat ${chatId}`);
    return;
  }

  const fcmToken = await resolveAnyRecipientFcmToken(receiverId);
  if (!fcmToken) {
    console.warn(`[notifyNewChatMessage:${collectionName}] No FCM token for user ${receiverId}`);
    return;
  }

  await _sendChatNotification({
    title: message.senderName || 'ข้อความใหม่',
    previewText: _resolveMessagePreview(message),
    chatId,
    senderId,
    receiverId,
    fcmToken,
    orderId: await _resolveChatOrderId(chatId, message),
    collectionName,
  });
}

async function resolveAnyRecipientFcmToken(recipientUid) {
  if (!recipientUid) return null;

  for (const collection of CUSTOMER_COLLECTIONS) {
    try {
      const doc = await db.collection(collection).doc(recipientUid).get();
      const token = String(doc.data()?.fcmToken || '').trim();
      if (token) return token;
    } catch (_) {}
  }

  for (const collection of RIDER_COLLECTIONS) {
    try {
      const doc = await db.collection(collection).doc(recipientUid).get();
      const token = String(doc.data()?.fcmToken || '').trim();
      if (token) return token;
    } catch (_) {}
  }

  for (const collection of SHOP_COLLECTIONS) {
    try {
      const doc = await db.collection(collection).doc(recipientUid).get();
      const token = String(doc.data()?.shopFCMToken || '').trim();
      if (token) return token;
    } catch (_) {}
  }

  return null;
}

async function resolveCallRecipientFcmToken(recipientUid) {
  if (!recipientUid) return null;

  for (const collection of SHOP_COLLECTIONS) {
    try {
      const doc = await db.collection(collection).doc(recipientUid).get();
      const token = String(doc.data()?.shopFCMToken || '').trim();
      if (token) return token;
    } catch (_) {}
  }

  for (const collection of RIDER_COLLECTIONS) {
    try {
      const doc = await db.collection(collection).doc(recipientUid).get();
      const token = String(doc.data()?.fcmToken || '').trim();
      if (token) return token;
    } catch (_) {}
  }

  for (const collection of CUSTOMER_COLLECTIONS) {
    try {
      const doc = await db.collection(collection).doc(recipientUid).get();
      const token = String(doc.data()?.fcmToken || '').trim();
      if (token) return token;
    } catch (_) {}
  }

  return null;
}

async function _sendChatNotification({
  title,
  previewText,
  chatId,
  senderId,
  receiverId,
  fcmToken,
  orderId,
  collectionName,
}) {
  const payload = {
    data: {
      chatId,
      senderId: senderId || '',
      senderName: title,
      message: previewText,
      orderId: orderId || '',
      type: 'chat',
      title,
      body: previewText,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    android: {
      priority: 'high',
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          alert: {
            title,
            body: previewText,
          },
        },
      },
    },
    token: fcmToken,
  };

  try {
    await admin.messaging().send(payload);
    console.log(`[notifyNewChatMessage:${collectionName}] Sent to ${receiverId}`);
  } catch (error) {
    console.error(`[notifyNewChatMessage:${collectionName}] Error:`, error);
  }
}

async function _resolveChatOrderId(chatId, message) {
  const messageOrderId = String(message?.orderId || '').trim();
  if (messageOrderId) {
    return messageOrderId;
  }

  try {
    const chatDoc = await admin.firestore().collection('chats').doc(chatId).get();
    if (!chatDoc.exists) {
      return null;
    }

    const chatOrderId = String(chatDoc.data()?.orderId || '').trim();
    return chatOrderId || null;
  } catch (error) {
    console.error(`[notifyNewChatMessage] Failed to resolve order for chat ${chatId}`, error);
    return null;
  }
}

async function _resolveReceiverId(chatId, senderId) {
  try {
    const chatDoc = await admin.firestore().collection('chats').doc(chatId).get();
    if (!chatDoc.exists) {
      return null;
    }
    const participants = chatDoc.data().participants || [];
    return participants.find((participantId) => participantId !== senderId) || null;
  } catch (error) {
    console.error(`[notifyNewChatMessage] Failed to resolve receiver for chat ${chatId}`, error);
    return null;
  }
}

function _resolveMessagePreview(message) {
  if (message.text) {
    return message.text;
  }
  switch (message.type) {
    case 'image':
      return 'ส่งรูปภาพ';
    case 'video':
      return 'ส่งวิดีโอ';
    case 'file':
      return 'ส่งไฟล์แนบ';
    case 'call':
      return message.callType === 'video' ? 'วิดีโอคอล' : 'สายเสียง';
    default:
      return 'คุณได้รับข้อความใหม่';
  }
}
// ...existing code...
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');
admin.initializeApp();

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const AGORA_APP_ID_SECRET = defineSecret('AGORA_APP_ID');
const AGORA_APP_CERT_SECRET = defineSecret('AGORA_APP_CERTIFICATE');
const AGORA_TTL_SECRET = defineSecret('AGORA_APP_TTL_SECONDS');
const GOOGLE_ROUTES_API_KEY = defineSecret('GOOGLE_ROUTES_API_KEY');
const REDIS_URL = defineSecret('REDIS_URL');
const REDIS_TOKEN = defineSecret('REDIS_TOKEN');
const SMTP_HOST = defineSecret('SMTP_HOST');
const SMTP_PORT = defineSecret('SMTP_PORT');
const SMTP_USER = defineSecret('SMTP_USER');
const SMTP_PASS = defineSecret('SMTP_PASS');
const SMTP_FROM = defineSecret('SMTP_FROM');

const OTP_TTL_MS = 10 * 60 * 1000;
const OTP_RESEND_INTERVAL_MS = 60 * 1000;
const MAX_VERIFY_ATTEMPTS = 5;
const ROUTE_CACHE_TTL_SEC = 24 * 60 * 60;

let redisClient = null;
let redisClientReady = false;

const SHOP_COLLECTIONS = [
  'market_registrations',
  'shop_registrations',
  'restaurant_registrations',
  'pharmacy_registrations',
  'other_registrations',
];
const CUSTOMER_COLLECTIONS = ['users', 'customer_users'];
const RIDER_COLLECTIONS = ['riders'];
const PROFILE_COLLECTIONS = [...CUSTOMER_COLLECTIONS, ...RIDER_COLLECTIONS, ...SHOP_COLLECTIONS];

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function otpDocId(email) {
  return Buffer.from(normalizeEmail(email)).toString('base64url');
}

function generateOtp() {
  return `${crypto.randomInt(0, 1000000)}`.padStart(6, '0');
}

function hashOtp(email, otp) {
  return crypto
    .createHash('sha256')
    .update(`${normalizeEmail(email)}:${otp}`)
    .digest('hex');
}

function readRequiredSecret(secret, label) {
  const value = String(secret.value() || '').trim();
  if (!value) {
    throw new HttpsError(
      'failed-precondition',
      `ยังไม่ได้ตั้งค่า ${label} สำหรับระบบ Email OTP`,
    );
  }
  return value;
}

function buildTransport() {
  const host = readRequiredSecret(SMTP_HOST, 'SMTP_HOST');
  const port = Number(readRequiredSecret(SMTP_PORT, 'SMTP_PORT'));
  const user = readRequiredSecret(SMTP_USER, 'SMTP_USER');
  const pass = readRequiredSecret(SMTP_PASS, 'SMTP_PASS');

  if (Number.isNaN(port)) {
    throw new HttpsError(
      'failed-precondition',
      'ค่า SMTP_PORT ไม่ถูกต้องสำหรับระบบ Email OTP',
    );
  }

  return nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: {
      user,
      pass,
    },
  });
}

exports.sendEmailOtp = onCall(
  {
    region: DEFAULT_REGION,
    secrets: [SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM],
  },
  async (request) => {
    const email = normalizeEmail(request.data?.email || request.auth?.token?.email);
    if (!email || !email.includes('@')) {
      throw new HttpsError('invalid-argument', 'รูปแบบอีเมลไม่ถูกต้อง');
    }

    if (request.auth?.uid) {
      const authUser = await admin.auth().getUser(request.auth.uid);
      if (normalizeEmail(authUser.email) !== email) {
        throw new HttpsError('permission-denied', 'อีเมลไม่ตรงกับบัญชีผู้ใช้');
      }
    }

    const docRef = db.collection('email_otps').doc(otpDocId(email));
    const existingDoc = await docRef.get();
    const now = Date.now();

    if (existingDoc.exists) {
      const data = existingDoc.data() || {};
      const lastSentAt = data.lastSentAt?.toMillis?.() || 0;
      if (now - lastSentAt < OTP_RESEND_INTERVAL_MS) {
        throw new HttpsError('resource-exhausted', 'กรุณารอก่อนขอรหัสใหม่');
      }
    }

    const otp = generateOtp();
    await docRef.set(
      {
        email,
        otpHash: hashOtp(email, otp),
        attempts: 0,
        lastSentAt: admin.firestore.Timestamp.fromMillis(now),
        expiresAt: admin.firestore.Timestamp.fromMillis(now + OTP_TTL_MS),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    try {
      const transport = buildTransport();
      const from = readRequiredSecret(SMTP_FROM, 'SMTP_FROM');
      await transport.sendMail({
        from,
        to: email,
        subject: 'รหัส OTP สำหรับยืนยันอีเมล Van Market',
        text: `รหัส OTP ของคุณคือ ${otp} รหัสนี้จะหมดอายุใน 10 นาที`,
        html: `
          <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #1f2937;">
            <h2 style="color: #ea580c;">ยืนยันอีเมล Van Market</h2>
            <p>รหัส OTP สำหรับยืนยันอีเมลของคุณคือ</p>
            <div style="font-size: 32px; font-weight: 700; letter-spacing: 8px; color: #9a3412; margin: 16px 0;">${otp}</div>
            <p>รหัสนี้จะหมดอายุใน 10 นาที</p>
          </div>
        `,
      });
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      logger.error('sendEmailOtp failed', {
        uid: request.auth.uid,
        email,
        message: error instanceof Error ? error.message : String(error),
      });

      throw new HttpsError(
        'unavailable',
        'ระบบ Email OTP ยังส่งอีเมลไม่ได้ กรุณาตรวจสอบ SMTP และ deploy functions ใหม่',
      );
    }

    return { success: true, expiresInSeconds: OTP_TTL_MS / 1000 };
  },
);

exports.verifyEmailOtp = onCall(
  {
    region: DEFAULT_REGION,
  },
  async (request) => {
    const email = normalizeEmail(request.data?.email || request.auth?.token?.email);
    const otp = String(request.data?.otp || '').trim();
    const password = String(request.data?.password || '').trim();
    const mode = String(request.data?.mode || 'sign_in').trim().toLowerCase();
    const isResetPassword = mode === 'reset_password';

    if (!email || !email.includes('@')) {
      throw new HttpsError('invalid-argument', 'รูปแบบอีเมลไม่ถูกต้อง');
    }

    if (!/^\d{6}$/.test(otp)) {
      throw new HttpsError('invalid-argument', 'OTP ต้องเป็นตัวเลข 6 หลัก');
    }

    if (password && password.length < 6) {
      throw new HttpsError('invalid-argument', 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร');
    }

    if (isResetPassword && !password) {
      throw new HttpsError('invalid-argument', 'กรุณากรอกรหัสผ่านใหม่');
    }

    const docRef = db.collection('email_otps').doc(otpDocId(email));
    const snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw new HttpsError('not-found', 'ไม่พบรหัส OTP สำหรับอีเมลนี้');
    }

    const data = snapshot.data() || {};
    const expiresAt = data.expiresAt?.toMillis?.() || 0;
    const attempts = Number(data.attempts || 0);

    if (Date.now() > expiresAt) {
      await docRef.delete();
      throw new HttpsError('deadline-exceeded', 'OTP หมดอายุแล้ว');
    }

    if (attempts >= MAX_VERIFY_ATTEMPTS) {
      await docRef.delete();
      throw new HttpsError('permission-denied', 'กรอกรหัสผิดเกินจำนวนที่กำหนด');
    }

    if (data.otpHash !== hashOtp(email, otp)) {
      await docRef.set(
        {
          attempts: attempts + 1,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      throw new HttpsError('permission-denied', 'รหัส OTP ไม่ถูกต้อง');
    }

    let userRecord;
    try {
      userRecord = await admin.auth().getUserByEmail(email);
    } catch (error) {
      if (error?.code !== 'auth/user-not-found') {
        throw error;
      }
    }

    if (userRecord) {
      const updatePayload = {};
      if (!userRecord.emailVerified) {
        updatePayload.emailVerified = true;
      }
      if (password && (isResetPassword || !userRecord.emailVerified)) {
        updatePayload.password = password;
      }
      if (Object.keys(updatePayload).length > 0) {
        await admin.auth().updateUser(userRecord.uid, updatePayload);
        userRecord = await admin.auth().getUser(userRecord.uid);
      }
    } else {
      if (isResetPassword) {
        throw new HttpsError('not-found', 'ไม่พบบัญชีผู้ใช้สำหรับอีเมลนี้');
      }
      if (!password) {
        throw new HttpsError('failed-precondition', 'กรุณากำหนดรหัสผ่านก่อนยืนยันอีเมล');
      }
      userRecord = await admin.auth().createUser({
        email,
        password,
        emailVerified: true,
      });
    }

    const customToken = await admin.auth().createCustomToken(userRecord.uid);
    await docRef.delete();
    return { success: true, customToken };
  },
);

/**
 * Cloud Function สำหรับตรวจสอบเวลาเตรียมออเดอร์และส่งการแจ้งเตือน
 * ทำงานทุก 1 นาที
 */
exports.checkPreparingOrders = functions.region(DEFAULT_REGION).pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    
    try {
      // ดึงออเดอร์ที่อยู่ในสถานะ preparing
      const ordersSnapshot = await db.collection('orders')
        .where('status', '==', 'preparing')
        .get();

      const promises = [];

      for (const doc of ordersSnapshot.docs) {
        const order = doc.data();
        const orderId = doc.id;

        if (!order.preparingStartTime) continue;

        const preparingStart = order.preparingStartTime.toDate();
        const elapsed = now.toDate() - preparingStart;
        const elapsedMinutes = elapsed / 1000 / 60;

        // ตรวจสอบแจ้งเตือนที่ 5 นาที
        if (elapsedMinutes >= 5 && !order.notifications?.firstWarning?.sent) {
          promises.push(
            sendNotification(
              order.shopFCMToken,
              'แจ้งเตือนเวลาเตรียมออเดอร์',
              `ออเดอร์ #${orderId.substring(0, 8)} ใช้เวลาไป 5 นาทีแล้ว เหลืออีก 5 นาที`,
              orderId
            ),
            doc.ref.update({
              'notifications.firstWarning.sent': true,
              'notifications.firstWarning.sentAt': now,
            })
          );
        }

        // ตรวจสอบแจ้งเตือนที่ 7.5 นาที
        if (elapsedMinutes >= 7.5 && !order.notifications?.secondWarning?.sent) {
          promises.push(
            sendNotification(
              order.shopFCMToken,
              'แจ้งเตือนเวลาเตรียมออเดอร์ (เร่งด่วน)',
              `ออเดอร์ #${orderId.substring(0, 8)} ใช้เวลาไป 7.5 นาทีแล้ว เหลืออีก 2.5 นาที`,
              orderId
            ),
            doc.ref.update({
              'notifications.secondWarning.sent': true,
              'notifications.secondWarning.sentAt': now,
            })
          );
        }

        // ตรวจสอบแจ้งเตือนที่ 10 นาที (หมดเวลา)
        if (elapsedMinutes >= 10 && !order.notifications?.finalWarning?.sent) {
          const overtimeMinutes = elapsedMinutes - 10;
          const penalty = calculatePenalty(overtimeMinutes);

          promises.push(
            sendNotification(
              order.shopFCMToken,
              'เกินเวลาเตรียมออเดอร์!',
              `ออเดอร์ #${orderId.substring(0, 8)} เกินเวลา ${overtimeMinutes.toFixed(1)} นาที มีค่าปรับ ${penalty} บาท`,
              orderId
            ),
            doc.ref.update({
              'notifications.finalWarning.sent': true,
              'notifications.finalWarning.sentAt': now,
              'penalty': penalty,
            })
          );
        }

        // อัพเดทค่าปรับถ้าเกิน 10 นาทีและยังไม่เสร็จ
        if (elapsedMinutes > 10) {
          const overtimeMinutes = elapsedMinutes - 10;
          const penalty = calculatePenalty(overtimeMinutes);
          
          promises.push(
            doc.ref.update({ 'penalty': penalty })
          );
        }
      }

      await Promise.all(promises);
      console.log(`Processed ${ordersSnapshot.docs.length} preparing orders`);
      
    } catch (error) {
      console.error('Error checking preparing orders:', error);
    }
  });

/**
 * คำนวณค่าปรับ
 * - เกิน 10-15 นาที: 20 บาท
 * - เกิน 15-20 นาที: 50 บาท
 * - เกิน 20 นาทีขึ้นไป: 100 บาท
 */
function calculatePenalty(overtimeMinutes) {
  if (overtimeMinutes <= 5) {
    return 20;
  } else if (overtimeMinutes <= 10) {
    return 50;
  } else {
    return 100;
  }
}

/**
 * ส่ง notification ผ่าน FCM
 */
async function sendNotification(fcmToken, title, body, orderId) {
  if (!fcmToken) {
    console.log('No FCM token provided');
    return;
  }

  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: {
      orderId: orderId,
      type: 'order_warning',
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    token: fcmToken,
  };

  try {
    await admin.messaging().send(message);
    console.log(`Notification sent for order ${orderId}`);
  } catch (error) {
    console.error('Error sending notification:', error);
  }
}

/**
 * Trigger เมื่อมีการอัพเดทสถานะออเดอร์
 */
exports.onOrderStatusUpdate = functions.region(DEFAULT_REGION).firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const orderId = context.params.orderId;

    // ถ้าสถานะเปลี่ยนเป็น 'ready' ให้แจ้งเตือนพนักงานขนส่ง
    if (before.status !== 'ready' && after.status === 'ready') {
      if (after.driverFCMToken) {
        await sendNotification(
          after.driverFCMToken,
          'มีออเดอร์พร้อมส่ง',
          `ร้าน ${after.shopAddress} เตรียมสินค้าเสร็จแล้ว รอให้ไปรับ`,
          orderId
        );
      }
    }

    // ถ้าสถานะเปลี่ยนเป็น 'delivering' ให้แจ้งเตือนลูกค้า
    if (before.status !== 'delivering' && after.status === 'delivering') {
      if (after.customerFCMToken) {
        await sendNotification(
          after.customerFCMToken,
          'ออเดอร์ของคุณกำลังจัดส่ง',
          `พนักงานขนส่งกำลังนำสินค้ามาส่ง ประมาณ ${after.estimatedDeliveryTime} นาที`,
          orderId
        );
      }
    }

    // ถ้าสถานะเปลี่ยนเป็น 'delivered' ให้แจ้งเตือนร้านและลูกค้า
    if (before.status !== 'delivered' && after.status === 'delivered') {
      const promises = [];

      if (after.shopFCMToken) {
        promises.push(
          sendNotification(
            after.shopFCMToken,
            'ส่งสินค้าสำเร็จ',
            `ออเดอร์ #${orderId.substring(0, 8)} ส่งถึงลูกค้าเรียบร้อยแล้ว`,
            orderId
          )
        );
      }

      if (after.customerFCMToken) {
        promises.push(
          sendNotification(
            after.customerFCMToken,
            'ได้รับสินค้าแล้ว',
            'ขอบคุณที่ใช้บริการ กรุณาให้คะแนนและรีวิว',
            orderId
          )
        );
      }

      await Promise.all(promises);
    }
  });

/**
 * คำนวณระยะทางและเวลาที่ใช้จัดส่ง (ตัวอย่าง)
 * ในการใช้งานจริงควรใช้ Google Maps Distance Matrix API
 */
exports.calculateDeliveryTime = functions.region(DEFAULT_REGION).https.onCall(async (data, context) => {
  const { shopLocation, customerLocation } = data;

  try {
    // สูตรคำนวณระยะทาง Haversine
    const distance = calculateDistance(
      shopLocation.latitude,
      shopLocation.longitude,
      customerLocation.latitude,
      customerLocation.longitude
    );

    // ประมาณการเวลา: ความเร็วเฉลี่ย 30 km/h
    const estimatedMinutes = Math.ceil((distance / 1000) * 2); // 2 นาที/กิโลเมตร

    return {
      distance: distance,
      estimatedDeliveryTime: estimatedMinutes,
    };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Callable Function: callUser
 * ใช้สำหรับโทรจริง (voice/video call)
 * รับข้อมูล caller/callee/callType, สร้าง Agora token/channel, ส่ง FCM payload type 'call'
 */
exports.callUser = functions
  .region(DEFAULT_REGION)
  .runWith({ secrets: [AGORA_APP_ID_SECRET, AGORA_APP_CERT_SECRET, AGORA_TTL_SECRET] })
  .https.onCall(async (data, context) => {
  // ข้อมูลที่รับมา
  const callerId = data.callerId;
  const callerName = data.callerName;
  const callerPhotoUrl = data.callerPhotoUrl || '';
  const calleeId = data.calleeId;
  const calleeFCMToken = data.calleeFCMToken;
  const callType = data.callType || 'voice'; // 'voice' หรือ 'video'

  // สร้าง channelId (เช่น ใช้ callerId+timestamp)
  const channelId = `call_${callerId}_${Date.now()}`;

  const agoraToken = await buildAgoraToken(channelId);

  // ส่ง FCM payload type 'call' ไปยัง callee
  const message = {
    data: {
      type: 'call',
      callerId: callerId || '',
      callerName: callerName || 'ผู้โทร',
      callerPhotoUrl: callerPhotoUrl || '',
      channelId,
      callType,
      token: agoraToken,
      isVideo: callType === 'video' ? 'true' : 'false',
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    android: {
      priority: 'high',
      ttl: CALL_TTL_MS,
    },
    apns: {
      headers: {
        'apns-priority': '10',
      },
      payload: {
        aps: {
          sound: 'default',
          'content-available': 1,
          category: 'INCOMING_CALL',
        },
      },
    },
    token: calleeFCMToken,
  };

  try {
    await admin.messaging().send(message);
    return { success: true, channelId, token: agoraToken };
  } catch (error) {
    console.error('Error sending call notification:', error);
    return { success: false, error: error.message };
  }
});
/**
 * คำนวณระยะทางด้วย Haversine formula (meters)
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371e3; // Earth radius in meters
  const φ1 = lat1 * Math.PI / 180;
  const φ2 = lat2 * Math.PI / 180;
  const Δφ = (lat2 - lat1) * Math.PI / 180;
  const Δλ = (lon2 - lon1) * Math.PI / 180;

  const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
            Math.cos(φ1) * Math.cos(φ2) *
            Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}

// เพิ่มฟังก์ชัน initiateCall สำหรับฟีเจอร์โทร
exports.initiateCall = functions
  .region(DEFAULT_REGION)
  .runWith({ secrets: [AGORA_APP_ID_SECRET, AGORA_APP_CERT_SECRET, AGORA_TTL_SECRET] })
  .https.onCall(async (data, context) => {
  const { calleeId, callerId, callerName, callerPhotoUrl, isVideo, callType, callerData } = data;
  if (!calleeId) {
    throw new functions.https.HttpsError('invalid-argument', 'calleeId is required');
  }
  if (!callerId && !callerData?.uid) {
    throw new functions.https.HttpsError('invalid-argument', 'callerId is required');
  }

  const resolvedCallerId = callerId || callerData?.uid;
  const resolvedCallType = callType || (isVideo ? 'video' : 'voice');
  const resolvedCallerName = callerName || callerData?.displayName || 'ผู้โทร';
  const resolvedCallerPhoto = callerPhotoUrl || callerData?.photoUrl || '';

  console.log('[initiateCall] incoming request', {
    calleeId,
    callerId: resolvedCallerId,
    callType: resolvedCallType,
  });

  let calleeProfile = await getOrCreateUserProfile(calleeId);
  if (!calleeProfile && resolvedCallerId) {
    console.log('[initiateCall] users doc missing, trying friends cache');
    calleeProfile = await getProfileFromFriendDoc(resolvedCallerId, calleeId);
  }
  if (!calleeProfile) {
    console.error('[initiateCall] callee not found', { calleeId, callerId: resolvedCallerId });
    throw new functions.https.HttpsError('not-found', 'Callee not found');
  }

  const fcmToken = await resolveCallRecipientFcmToken(calleeId);
  if (!fcmToken) {
    throw new functions.https.HttpsError('failed-precondition', 'Callee has no FCM token');
  }

  const { invite, created } = await resolveOrCreateActiveCallInvite({
    callerId: resolvedCallerId,
    calleeId,
    isVideo,
    callType: resolvedCallType,
    calleeProfile,
  });

  console.log('[initiateCall] agora config summary', {
    callerId: resolvedCallerId,
    calleeId,
    ...summarizeAgoraConfig(),
  });

  const { channelId, token, appId } = invite;

  const message = {
    data: {
      type: 'call',
      callerId: resolvedCallerId,
      callerName: resolvedCallerName,
      callerPhotoUrl: resolvedCallerPhoto,
      channelId,
      appId,
      callType: resolvedCallType,
      isVideo: isVideo ? 'true' : 'false',
      token,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    android: {
      priority: 'high',
      ttl: CALL_TTL_MS,
    },
    apns: {
      headers: {
        'apns-priority': '10',
      },
      payload: {
        aps: {
          sound: 'default',
          'content-available': 1,
          category: 'INCOMING_CALL',
        },
      },
    },
    token: fcmToken,
  };

  if (created) {
    try {
      await admin.messaging().send(message);
      console.log('[initiateCall] sent call notification');
    } catch (error) {
      await clearActiveCallInvite(resolvedCallerId, calleeId);
      console.error('[initiateCall] failed to send call notification', {
        calleeId,
        callerId: resolvedCallerId,
        code: error?.code,
        message: error?.message,
      });
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Call notification could not be sent: ${error?.message || 'unknown messaging error'}`
      );
    }
  } else {
    console.log('[initiateCall] reused active call invite', { channelId, callerId: resolvedCallerId, calleeId });
  }

  return {
    channelId,
    appId,
    token,
    calleeProfile: {
      displayName: calleeProfile.displayName || 'ผู้ใช้',
      photoUrl: calleeProfile.photoUrl || null,
      phoneNumber: calleeProfile.phoneNumber || null,
    },
  };
});

exports.cancelCallInvite = functions.region(DEFAULT_REGION).https.onCall(async (data, context) => {
  const channelId = data.channelId;
  const calleeId = data.calleeId;
  const callerId = data.callerId || '';

  if (!channelId || !calleeId) {
    throw new functions.https.HttpsError('invalid-argument', 'channelId and calleeId are required');
  }

  const fcmToken = await resolveCallRecipientFcmToken(calleeId);
  if (!fcmToken) {
    throw new functions.https.HttpsError('failed-precondition', 'Callee token unavailable');
  }

  const message = {
    data: {
      type: 'call_cancel',
      channelId,
      callerId,
    },
    android: {
      priority: 'high',
      ttl: CALL_TTL_MS,
    },
    apns: {
      headers: {
        'apns-priority': '10',
      },
      payload: {
        aps: {
          sound: 'default',
          'content-available': 1,
          category: 'INCOMING_CALL',
        },
      },
    },
    token: fcmToken,
  };

  await admin.messaging().send(message);
  await clearActiveCallInvite(callerId, calleeId);
  console.log('[cancelCallInvite] sent cancel signal', { channelId, calleeId });
  return { success: true };
});

function activeCallInviteRef(callerId, calleeId) {
  return db.collection(ACTIVE_CALL_INVITES_COLLECTION).doc(`${callerId}__${calleeId}`);
}

function maskSecret(secret, visible = 4) {
  if (!secret) return null;
  if (secret.length <= visible * 2) {
    return '*'.repeat(secret.length);
  }
  return `${secret.slice(0, visible)}***${secret.slice(-visible)}`;
}

function summarizeAgoraConfig() {
  const { appId, appCertificate, tokenTtl } = resolveAgoraConfig();
  return {
    appIdMasked: maskSecret(appId, 6),
    appIdLength: appId ? appId.length : 0,
    certificateLength: appCertificate ? appCertificate.length : 0,
    certificatePrefix: appCertificate ? appCertificate.slice(0, 6) : null,
    certificateSuffix: appCertificate ? appCertificate.slice(-6) : null,
    tokenTtl,
  };
}

function timestampToMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === 'function') {
    return value.toMillis();
  }
  if (typeof value._seconds === 'number') {
    return value._seconds * 1000;
  }
  return null;
}

async function resolveOrCreateActiveCallInvite({
  callerId,
  calleeId,
  isVideo,
  callType,
  calleeProfile,
}) {
  const inviteRef = activeCallInviteRef(callerId, calleeId);
  const sessionCollection = db.collection('call_sessions');
  const inviteExpiry = admin.firestore.Timestamp.fromMillis(Date.now() + CALL_TTL_MS);
  const { appId } = resolveAgoraConfig();
  let invite = null;
  let created = false;

  await db.runTransaction(async (transaction) => {
    const currentTime = Date.now();
    const inviteSnap = await transaction.get(inviteRef);

    if (inviteSnap.exists) {
      const existingInvite = inviteSnap.data() || {};
      const expiresAtMillis = timestampToMillis(existingInvite.expiresAt);
      const existingChannelId = existingInvite.channelId;

      if (existingChannelId && expiresAtMillis != null && expiresAtMillis > currentTime) {
        const sessionSnap = await transaction.get(sessionCollection.doc(existingChannelId));
        const sessionStatus = sessionSnap.exists ? sessionSnap.data()?.status : null;
        if (sessionStatus !== 'ended') {
          invite = existingInvite;
          return;
        }
      }

      transaction.delete(inviteRef);
    }

    const channelId = `call_${calleeId}_${Date.now()}`;
    const token = await buildAgoraToken(channelId);
    console.log('[callInvite] created fresh invite', {
      callerId,
      calleeId,
      channelId,
      isVideo,
      callType,
    });
    invite = {
      channelId,
      token,
      appId,
      callerId,
      calleeId,
      isVideo,
      callType,
      calleeProfile: {
        displayName: calleeProfile.displayName || 'ผู้ใช้',
        photoUrl: calleeProfile.photoUrl || null,
        phoneNumber: calleeProfile.phoneNumber || null,
      },
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: inviteExpiry,
    };
    transaction.set(inviteRef, invite);
    created = true;
  });

  return { invite, created };
}

async function clearActiveCallInvite(callerId, calleeId) {
  if (!callerId || !calleeId) {
    return;
  }
  try {
    await activeCallInviteRef(callerId, calleeId).delete();
  } catch (error) {
    console.warn('[callInvite] failed to clear active invite', { callerId, calleeId, error });
  }
}

async function buildAgoraToken(channelId, uid = 0) {
  const { appId, appCertificate, tokenTtl } = resolveAgoraConfig();
  if (!appId || !appCertificate) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Agora credentials are not configured. Set secrets AGORA_APP_ID and AGORA_APP_CERTIFICATE.'
    );
  }

  const privilegeExpiredTs = Math.floor(Date.now() / 1000) + tokenTtl;
  try {
    console.log('[agora] building token', {
      channelId,
      uid,
      privilegeExpiredTs,
      ...summarizeAgoraConfig(),
    });
    return RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelId,
      uid,
      RtcRole.PUBLISHER,
      privilegeExpiredTs
    );
  } catch (error) {
    console.error('[agora] Failed to build token', { channelId, error });
    throw new functions.https.HttpsError('internal', 'Unable to create Agora token');
  }
}

function resolveAgoraConfig() {
  const appId = (AGORA_APP_ID_SECRET.value() || process.env.AGORA_APP_ID || '').trim();
  const appCertificate = (AGORA_APP_CERT_SECRET.value() || process.env.AGORA_APP_CERTIFICATE || '').trim();
  const ttlRaw = (AGORA_TTL_SECRET.value() || process.env.AGORA_APP_TTL_SECONDS || '3600').trim();
  let tokenTtl = parseInt(ttlRaw, 10);
  if (!Number.isFinite(tokenTtl) || tokenTtl <= 0) {
    tokenTtl = 3600;
  }
  return { appId, appCertificate, tokenTtl };
}

async function getOrCreateUserProfile(uid) {
  const userRef = db.collection('users').doc(uid);
  const existing = await userRef.get();
  if (existing.exists) {
    const data = existing.data();
    console.log('[initiateCall] found user doc', { uid, source: data?.sourceCollection || 'users' });
    return data;
  }

  for (const collection of PROFILE_COLLECTIONS) {
    const doc = await db.collection(collection).doc(uid).get();
    if (!doc.exists) continue;
    const normalized = buildProfileFromSource(doc.data(), collection);
    await userRef.set(
      {
        ...normalized,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
        sourceCollection: collection,
      },
      { merge: true }
    );
    console.log('[initiateCall] synced profile from source collection', { uid, collection });
    return normalized;
  }

  console.warn('[initiateCall] no profile found in known collections', { uid });
  return null;
}

function buildProfileFromSource(data = {}, fallbackCollection) {
  return {
    displayName: readDisplayName(data, 'ผู้ใช้ใหม่'),
    photoUrl: readPhotoUrl(data),
    serviceType: data.serviceType || fallbackCollection,
    isOfficial: !!data.isOfficialAccount,
    profileCompleted: !!data.isProfileCompleted,
    phoneNumber: normalizePhone(data.phone || data.phoneNumber || ''),
  };
}

function readDisplayName(data, fallback) {
  const candidates = [data.displayName, data.shopName, data.name];
  for (const candidate of candidates) {
    if (candidate && typeof candidate === 'string' && candidate.trim().length) {
      return candidate.trim();
    }
  }
  return fallback;
}

function readPhotoUrl(data) {
  const candidates = [
    data.shopImageUrl,
    data.imageUrl,
    data.logoUrl,
    data.profileImageUrl,
  ];
  for (const candidate of candidates) {
    if (candidate && typeof candidate === 'string' && candidate.trim().length) {
      return candidate.trim();
    }
  }
  return null;
}

function normalizePhone(raw = '') {
  let clean = raw.replace(/[^0-9+]/g, '');
  if (!clean) return '';
  if (clean.startsWith('00')) {
    clean = `+${clean.substring(2)}`;
  }
  if (clean.startsWith('0') && clean.length === 10) {
    return `+66${clean.substring(1)}`;
  }
  if (!clean.startsWith('+') && clean.length >= 9) {
    return `+${clean}`;
  }
  return clean;
}

async function getProfileFromFriendDoc(ownerId, friendId) {
  try {
    const doc = await db
      .collection('users')
      .doc(ownerId)
      .collection('friends')
      .doc(friendId)
      .get();
    if (!doc.exists) return null;
    const data = doc.data() || {};
    await db.collection('users').doc(friendId).set(
      {
        ...data,
        uid: friendId,
        updatedAt: FieldValue.serverTimestamp(),
        source: 'friends-cache',
      },
      { merge: true }
    );
    return data;
  } catch (error) {
    console.error('Error getting friend doc profile', error);
    return null;
  }
}

exports.computeRouteMetrics = onCall(
  {
    region: DEFAULT_REGION,
    secrets: [
      GOOGLE_ROUTES_API_KEY,
      REDIS_URL,
      REDIS_TOKEN,
    ],
  },
  async (request) => {
    const originLatitude = Number(request.data?.originLatitude);
    const originLongitude = Number(request.data?.originLongitude);
    const destinationLatitude = Number(request.data?.destinationLatitude);
    const destinationLongitude = Number(request.data?.destinationLongitude);

    if (
      !Number.isFinite(originLatitude) ||
      !Number.isFinite(originLongitude) ||
      !Number.isFinite(destinationLatitude) ||
      !Number.isFinite(destinationLongitude)
    ) {
      throw new HttpsError('invalid-argument', 'พิกัดต้นทาง/ปลายทางไม่ถูกต้อง');
    }

    const cacheKey = buildRouteCacheKey({
      originLatitude,
      originLongitude,
      destinationLatitude,
      destinationLongitude,
    });

    const cached = await readRouteCache(cacheKey);
    if (cached) {
      return { ...cached, source: 'cache' };
    }

    const apiKey = String(GOOGLE_ROUTES_API_KEY.value() || process.env.GOOGLE_ROUTES_API_KEY || '').trim();
    if (!apiKey) {
      throw new HttpsError('failed-precondition', 'ยังไม่ได้ตั้งค่า GOOGLE_ROUTES_API_KEY');
    }

    const body = {
      origin: {
        location: {
          latLng: {
            latitude: originLatitude,
            longitude: originLongitude,
          },
        },
      },
      destination: {
        location: {
          latLng: {
            latitude: destinationLatitude,
            longitude: destinationLongitude,
          },
        },
      },
      travelMode: 'DRIVE',
      routingPreference: 'TRAFFIC_AWARE',
      languageCode: 'th-TH',
      units: 'METRIC',
    };

    let response;
    try {
      response = await fetch('https://routes.googleapis.com/directions/v2:computeRoutes', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'routes.distanceMeters,routes.duration',
        },
        body: JSON.stringify(body),
      });
    } catch (error) {
      logger.error('computeRouteMetrics network error', {
        message: error instanceof Error ? error.message : String(error),
      });
      throw new HttpsError('unavailable', 'เชื่อมต่อ Routes API ไม่สำเร็จ');
    }

    if (!response.ok) {
      let details = 'routes api request failed';
      try {
        details = await response.text();
      } catch (_) {}
      logger.error('computeRouteMetrics api error', {
        status: response.status,
        details,
      });
      throw new HttpsError('failed-precondition', `Routes API error: ${response.status}`);
    }

    let decoded;
    try {
      decoded = await response.json();
    } catch (_) {
      throw new HttpsError('internal', 'อ่านผลลัพธ์ Routes API ไม่สำเร็จ');
    }

    const firstRoute = decoded?.routes?.[0];
    const distanceMeters = Number(firstRoute?.distanceMeters);
    const durationSeconds = parseDurationSeconds(firstRoute?.duration);
    if (!Number.isFinite(distanceMeters) || !Number.isFinite(durationSeconds)) {
      throw new HttpsError('internal', 'ข้อมูลระยะทาง/เวลาไม่ครบจาก Routes API');
    }

    const payload = {
      distanceMeters,
      durationSeconds,
    };

    await writeRouteCache(cacheKey, payload);
    return { ...payload, source: 'routes-api' };
  },
);

function buildRouteCacheKey({
  originLatitude,
  originLongitude,
  destinationLatitude,
  destinationLongitude,
}) {
  const to5 = (v) => Number(v).toFixed(5);
  return `route:${to5(originLatitude)},${to5(originLongitude)}->${to5(destinationLatitude)},${to5(destinationLongitude)}`;
}

function parseDurationSeconds(durationText) {
  if (typeof durationText !== 'string' || !durationText.endsWith('s')) {
    return NaN;
  }
  return Number(durationText.slice(0, -1));
}

function redisTcpConfig() {
  const url = String(REDIS_URL.value() || process.env.REDIS_URL || '').trim();
  const token = String(REDIS_TOKEN.value() || process.env.REDIS_TOKEN || '').trim();
  if (!url) {
    return null;
  }
  return { url, token };
}

async function getRedisClient() {
  const cfg = redisTcpConfig();
  if (!cfg) {
    return null;
  }

  if (redisClient && redisClientReady) {
    return redisClient;
  }

  if (!redisClient) {
    const options = {
      lazyConnect: true,
      maxRetriesPerRequest: 1,
      enableReadyCheck: true,
    };
    if (cfg.token) {
      options.password = cfg.token;
    }

    redisClient = new Redis(cfg.url, options);
    redisClient.on('ready', () => {
      redisClientReady = true;
    });
    redisClient.on('error', (error) => {
      redisClientReady = false;
      logger.warn('redis tcp client error', {
        message: error instanceof Error ? error.message : String(error),
      });
    });
  }

  try {
    if (redisClient.status !== 'ready') {
      await redisClient.connect();
    }
    redisClientReady = true;
    return redisClient;
  } catch (error) {
    redisClientReady = false;
    logger.warn('redis tcp connect failed', {
      message: error instanceof Error ? error.message : String(error),
    });
    return null;
  }
}

function redisConfig() {
  const url = String(process.env.REDIS_REST_URL || '').trim();
  const token = String(process.env.REDIS_REST_TOKEN || '').trim();
  if (!url || !token) {
    return null;
  }
  return { url: url.replace(/\/$/, ''), token };
}

async function redisGet(key) {
  const tcpClient = await getRedisClient();
  if (tcpClient) {
    return tcpClient.get(key);
  }

  const cfg = redisConfig();
  if (!cfg) return null;
  const endpoint = `${cfg.url}/get/${encodeURIComponent(key)}`;
  const res = await fetch(endpoint, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${cfg.token}`,
    },
  });
  if (!res.ok) return null;
  const json = await res.json();
  return json?.result || null;
}

async function redisSetEx(key, ttlSec, value) {
  const tcpClient = await getRedisClient();
  if (tcpClient) {
    const result = await tcpClient.set(key, value, 'EX', ttlSec);
    return result === 'OK';
  }

  const cfg = redisConfig();
  if (!cfg) return false;
  const endpoint = `${cfg.url}/setex/${encodeURIComponent(key)}/${ttlSec}/${encodeURIComponent(value)}`;
  const res = await fetch(endpoint, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${cfg.token}`,
    },
  });
  return res.ok;
}

async function readRouteCache(key) {
  try {
    const redisValue = await redisGet(key);
    if (redisValue) {
      const parsed = JSON.parse(redisValue);
      if (Number.isFinite(parsed?.distanceMeters) && Number.isFinite(parsed?.durationSeconds)) {
        return {
          distanceMeters: Number(parsed.distanceMeters),
          durationSeconds: Number(parsed.durationSeconds),
        };
      }
    }
  } catch (error) {
    logger.warn('readRouteCache redis failed', {
      message: error instanceof Error ? error.message : String(error),
    });
  }

  try {
    const doc = await db.collection('routes_cache').doc(key).get();
    if (!doc.exists) return null;
    const data = doc.data() || {};
    const expiresAt = data.expiresAt?.toMillis?.() || 0;
    if (Date.now() > expiresAt) {
      await doc.ref.delete();
      return null;
    }
    if (!Number.isFinite(data.distanceMeters) || !Number.isFinite(data.durationSeconds)) {
      return null;
    }
    return {
      distanceMeters: Number(data.distanceMeters),
      durationSeconds: Number(data.durationSeconds),
    };
  } catch (error) {
    logger.warn('readRouteCache firestore failed', {
      message: error instanceof Error ? error.message : String(error),
    });
    return null;
  }
}

async function writeRouteCache(key, payload) {
  const serialized = JSON.stringify(payload);
  try {
    await redisSetEx(key, ROUTE_CACHE_TTL_SEC, serialized);
  } catch (error) {
    logger.warn('writeRouteCache redis failed', {
      message: error instanceof Error ? error.message : String(error),
    });
  }

  try {
    await db.collection('routes_cache').doc(key).set({
      ...payload,
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + ROUTE_CACHE_TTL_SEC * 1000),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    logger.warn('writeRouteCache firestore failed', {
      message: error instanceof Error ? error.message : String(error),
    });
  }
}

function normalizePhoneNumber(raw = '') {
  let clean = String(raw).trim().replace(/[^0-9+]/g, '');
  if (!clean) return '';
  if (clean.startsWith('00')) {
    clean = `+${clean.substring(2)}`;
  }
  if (clean.startsWith('0') && clean.length === 10) {
    return `+66${clean.substring(1)}`;
  }
  if (!clean.startsWith('+') && clean.length >= 9) {
    return `+${clean}`;
  }
  return clean;
}

function hashPhonePassword(phoneNumber, password) {
  return crypto
    .createHash('sha256')
    .update(`${normalizePhoneNumber(phoneNumber)}:${String(password || '')}`)
    .digest('hex');
}

exports.upsertPhonePasswordProfile = onCall(
  {
    region: DEFAULT_REGION,
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'กรุณาเข้าสู่ระบบก่อน');
    }

    const phoneNumber = normalizePhoneNumber(request.data?.phoneNumber);
    const password = String(request.data?.password || '').trim();
    const authPhone = normalizePhoneNumber(request.auth.token?.phone_number || '');

    if (!phoneNumber || !phoneNumber.startsWith('+')) {
      throw new HttpsError('invalid-argument', 'เบอร์โทรศัพท์ไม่ถูกต้อง');
    }

    if (password.length < 4) {
      throw new HttpsError('invalid-argument', 'รหัสผ่านสั้นเกินไป');
    }

    if (!authPhone || authPhone !== phoneNumber) {
      throw new HttpsError('permission-denied', 'เบอร์โทรไม่ตรงกับบัญชีที่เข้าสู่ระบบ');
    }

    await db.collection('phone_login_profiles').doc(phoneNumber).set(
      {
        uid: request.auth.uid,
        phoneNumber,
        passwordHash: hashPhonePassword(phoneNumber, password),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { success: true };
  },
);

exports.signInWithPhonePassword = onCall(
  {
    region: DEFAULT_REGION,
  },
  async (request) => {
    const phoneNumber = normalizePhoneNumber(request.data?.phoneNumber);
    const password = String(request.data?.password || '').trim();

    if (!phoneNumber || !phoneNumber.startsWith('+') || !password) {
      throw new HttpsError('invalid-argument', 'ข้อมูลเข้าสู่ระบบไม่ถูกต้อง');
    }

    const doc = await db.collection('phone_login_profiles').doc(phoneNumber).get();
    if (!doc.exists) {
      throw new HttpsError('permission-denied', 'ต้องยืนยัน OTP ครั้งแรกก่อน');
    }

    const data = doc.data() || {};
    if (!data.uid || !data.passwordHash) {
      throw new HttpsError('permission-denied', 'ไม่พบข้อมูลเข้าสู่ระบบ');
    }

    const expectedHash = hashPhonePassword(phoneNumber, password);
    if (expectedHash !== data.passwordHash) {
      throw new HttpsError('permission-denied', 'เบอร์โทรหรือรหัสผ่านไม่ถูกต้อง');
    }

    const customToken = await admin.auth().createCustomToken(String(data.uid));
    return { customToken };
  },
);
