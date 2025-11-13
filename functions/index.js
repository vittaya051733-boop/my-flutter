const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

/**
 * Cloud Function สำหรับตรวจสอบเวลาเตรียมออเดอร์และส่งการแจ้งเตือน
 * ทำงานทุก 1 นาที
 */
exports.checkPreparingOrders = functions.pubsub
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
exports.onOrderStatusUpdate = functions.firestore
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
exports.calculateDeliveryTime = functions.https.onCall(async (data, context) => {
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
