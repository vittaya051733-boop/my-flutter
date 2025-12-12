// ...existing code...
const functions = require('firebase-functions/v1');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const DEFAULT_REGION = 'asia-southeast1';
const CALL_TTL_MS = 30 * 1000; // 30 seconds
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

  const userDoc = await admin.firestore().collection('users').doc(receiverId).get();
  const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;
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
    collectionName,
  });
}

async function _sendChatNotification({
  title,
  previewText,
  chatId,
  senderId,
  receiverId,
  fcmToken,
  collectionName,
}) {
  const payload = {
    notification: {
      title,
      body: previewText,
    },
    data: {
      chatId,
      senderId: senderId || '',
      senderName: title,
      message: previewText,
      type: 'chat',
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'order_channel',
        sound: 'default',
        defaultSound: true,
        defaultVibrateTimings: true,
      },
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

const SHOP_COLLECTIONS = [
  'market_registrations',
  'shop_registrations',
  'restaurant_registrations',
  'pharmacy_registrations',
  'other_registrations',
];

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

  const calleeUserDoc = await db.collection('users').doc(calleeId).get();
  const fcmToken = calleeUserDoc.exists ? calleeUserDoc.data().fcmToken : null;
  if (!fcmToken) {
    throw new functions.https.HttpsError('failed-precondition', 'Callee has no FCM token');
  }

  const channelId = `call_${calleeId}_${Date.now()}`;
  const token = await buildAgoraToken(channelId);

  const message = {
    data: {
      type: 'call',
      callerId: resolvedCallerId,
      callerName: resolvedCallerName,
      callerPhotoUrl: resolvedCallerPhoto,
      channelId,
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

  await admin.messaging().send(message);
  console.log('[initiateCall] sent call notification');

  return {
    channelId,
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

  const calleeDoc = await db.collection('users').doc(calleeId).get();
  const fcmToken = calleeDoc.exists ? calleeDoc.data().fcmToken : null;
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
  console.log('[cancelCallInvite] sent cancel signal', { channelId, calleeId });
  return { success: true };
});

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
  const appId = AGORA_APP_ID_SECRET.value() || process.env.AGORA_APP_ID;
  const appCertificate = AGORA_APP_CERT_SECRET.value() || process.env.AGORA_APP_CERTIFICATE;
  const ttlRaw = AGORA_TTL_SECRET.value() || process.env.AGORA_APP_TTL_SECONDS || '3600';
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

  for (const collection of SHOP_COLLECTIONS) {
    const doc = await db.collection(collection).doc(uid).get();
    if (!doc.exists) continue;
    const normalized = buildProfileFromShopData(doc.data(), collection);
    await userRef.set(
      {
        ...normalized,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
        sourceCollection: collection,
      },
      { merge: true }
    );
    console.log('[initiateCall] synced profile from shop collection', { uid, collection });
    return normalized;
  }

  console.warn('[initiateCall] no profile found in users or shop collections', { uid });
  return null;
}

function buildProfileFromShopData(data = {}, fallbackCollection) {
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
