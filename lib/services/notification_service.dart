import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// เริ่มต้นระบบ Notification
  Future<void> initialize() async {
    if (_initialized) return;

    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission');
    }

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Get FCM token
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _saveFCMToken(token);
      debugPrint('FCM Token: $token');
    }

    // Listen to token refresh
    _firebaseMessaging.onTokenRefresh.listen(_saveFCMToken);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    _initialized = true;
  }

  /// บันทึก FCM Token ลง Firestore
  Future<void> _saveFCMToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // อัพเดท token ในทุกคอลเลกชันที่เกี่ยวข้อง
      final batch = FirebaseFirestore.instance.batch();

      // อัพเดทใน shop registrations
      final shopCollections = [
        'market_registrations',
        'shop_registrations',
        'restaurant_registrations',
        'pharmacy_registrations',
        'other_registrations',
      ];

      for (final collection in shopCollections) {
        final docRef = FirebaseFirestore.instance.collection(collection).doc(user.uid);
        final doc = await docRef.get();
        if (doc.exists) {
          batch.update(docRef, {'shopFCMToken': token});
        }
      }

      // อัพเดทใน users collection (ถ้ามี)
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();
      if (userDoc.exists) {
        batch.update(userDocRef, {'fcmToken': token});
      }

      await batch.commit();
      debugPrint('FCM Token saved successfully');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// จัดการ notification เมื่อแอพอยู่ foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message: ${message.messageId}');

    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      await _showLocalNotification(
        title: notification.title ?? 'แจ้งเตือน',
        body: notification.body ?? '',
        payload: data['orderId'],
      );
    }
  }

  /// แสดง local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'order_channel',
      'การแจ้งเตือนออเดอร์',
      channelDescription: 'แจ้งเตือนเกี่ยวกับสถานะออเดอร์',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// จัดการเมื่อกด notification
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      debugPrint('Notification tapped with payload: $payload');
      // TODO: Navigate to order details screen
      // Navigator.push(context, MaterialPageRoute(
      //   builder: (context) => OrderDetailsScreen(orderId: payload),
      // ));
    }
  }

  /// จัดการเมื่อกด notification จาก background
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped from background: ${message.messageId}');
    final orderId = message.data['orderId'];
    if (orderId != null) {
      // TODO: Navigate to order details
    }
  }

  /// ส่ง notification แบบ manual (สำหรับทดสอบ)
  Future<void> sendTestNotification() async {
    await _showLocalNotification(
      title: 'ทดสอบการแจ้งเตือน',
      body: 'นี่คือการแจ้งเตือนทดสอบจากระบบ',
    );
  }
}

/// Background message handler (ต้องเป็น top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.messageId}');
  // ไม่ต้องทำอะไร เพราะ Cloud Functions จะจัดการให้
}
