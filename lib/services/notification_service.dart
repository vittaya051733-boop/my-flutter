import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_profile.dart';
import '../call_screen.dart';
import '../main.dart';
import '../widgets/chat_message_popup.dart';


class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const List<String> _registrationCollections = <String>[
    'market_registrations',
    'shop_registrations',
    'restaurant_registrations',
    'pharmacy_registrations',
    'other_registrations',
  ];

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _currentFcmToken;

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
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _saveFCMToken(token);
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
      if (_currentFcmToken == token) {
        debugPrint('FCM Token unchanged, skip update');
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final batch = FirebaseFirestore.instance.batch();
      final String? registrationCollection = await _resolveRegistrationCollection(user.uid);

      if (registrationCollection != null) {
        final docRef =
            FirebaseFirestore.instance.collection(registrationCollection).doc(user.uid);
        batch.set(docRef, {'shopFCMToken': token}, SetOptions(merge: true));
      } else {
        debugPrint('⚠️ ไม่พบคอลเลกชันร้านค้าของ ${user.uid} ข้ามการอัปเดต shopFCMToken');
      }

      // อัพเดทใน users collection (สร้างหรืออัปเดตได้เสมอ)
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.set(userDocRef, {'fcmToken': token}, SetOptions(merge: true));

      await batch.commit();
      _currentFcmToken = token;
      debugPrint('FCM Token saved successfully');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Future<String?> _resolveRegistrationCollection(String userId) async {
    String? collection;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      collection = _collectionFromServiceType(
        (userDoc.data()?['serviceType'] as String?)?.trim(),
      );
      if (collection != null) return collection;
    } catch (_) {}

    try {
      final contractDoc =
          await FirebaseFirestore.instance.collection('contracts').doc(userId).get();
      collection = _collectionFromServiceType(
        (contractDoc.data()?['serviceType'] as String?)?.trim(),
      );
      if (collection != null) return collection;
    } catch (_) {}

    for (final candidate in _registrationCollections) {
      final snapshot =
          await FirebaseFirestore.instance.collection(candidate).doc(userId).get();
      if (snapshot.exists) {
        return candidate;
      }
    }
    return null;
  }

  String? _collectionFromServiceType(String? serviceType) {
    if (serviceType == null || serviceType.isEmpty) return null;
    switch (serviceType) {
      case 'ตลาด':
      case 'market':
      case 'market_registrations':
        return 'market_registrations';
      case 'ร้านค้า':
      case 'shop':
      case 'shop_registrations':
        return 'shop_registrations';
      case 'ร้านอาหาร':
      case 'restaurant':
      case 'restaurant_registrations':
        return 'restaurant_registrations';
      case 'ร้านขายยา':
      case 'pharmacy':
      case 'pharmacy_registrations':
        return 'pharmacy_registrations';
      case 'อื่นๆ':
      case 'other':
      case 'other_registrations':
        return 'other_registrations';
      default:
        return null;
    }
  }

  /// บันทึก FCM token ของผู้ใช้ลง Firestore
  Future<void> saveUserFcmToken(String userId) async {
    final token = await _firebaseMessaging.getToken();
    if (token == null) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == userId) {
        await _saveFCMToken(token);
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        {'fcmToken': token},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error saving user FCM token directly: $e');
    }
  }

  /// จัดการ notification เมื่อแอพอยู่ foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message: ${message.messageId}');

    final notification = message.notification;
    final data = message.data;

    // แจ้งเตือนข้อความแชตเข้า
    if (data['type'] == 'chat') {
      final context = MyApp.navigatorKey.currentState?.context;
      final senderName = data['senderName'] ?? 'ข้อความใหม่';
      final messageText = data['message'] ?? '';
      if (context != null) {
        ChatMessagePopup.show(
          context,
          senderName: senderName,
          message: messageText,
          onTap: () {
            // TODO: Navigate to chat screen with chatId if needed
          },
        );
      } else {
        await _showLocalNotification(
          title: senderName,
          body: messageText,
          payload: data['chatId'],
        );
      }
      return;
    }

    // แจ้งเตือนสายเข้า/วิดีโอคอลจริง
    if (data['type'] == 'call') {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final callerId = data['callerId'] ?? data['caller_id'];
      if (currentUid != null && callerId != null && currentUid == callerId) {
        debugPrint('Skip showing incoming UI for own outgoing call');
        return;
      }
      // สร้าง UserProfile จาก payload (ใช้ fromMap ให้ตรงกับ model)
      final profile = UserProfile.fromMap(
        data['callerId'] ?? '',
        {
          'displayName': data['callerName'] ?? 'ผู้โทร',
          'photoUrl': data['callerPhotoUrl'],
        },
      );
      final navigatorState = MyApp.navigatorKey.currentState;
      if (navigatorState?.context != null) {
        navigatorState!.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => CallScreen(
              channelName: data['channelId'] ?? '',
              isVideo: data['callType'] == 'video',
              targetProfile: profile,
              isIncoming: true,
              tokenOverride: data['token'],
            ),
          ),
        );
        return;
      }
      // ถ้า context ยังไม่พร้อม ให้แสดง local notification ปกติ
      await _showCallNotification(
        title: 'สายเข้า',
        body: '${data['callerName'] ?? 'มีสายเข้า'} (${data['callType'] == 'video' ? 'วิดีโอคอล' : 'เสียง'})',
        callData: data,
      );
      return;
    }

    if (notification != null) {
      await _showLocalNotification(
        title: notification.title ?? 'แจ้งเตือน',
        body: notification.body ?? '',
        payload: data['orderId'],
      );
    }

    // เปิดหน้ารับสายอัตโนมัติถ้าเป็น notification ประเภท call
    // ลบโค้ดซ้ำซ้อนที่เปิด CallScreen อัตโนมัติ (จัดการใน showDialog ด้านบนแล้ว)
  }

  /// ดึง navigatorKey จาก MyApp (ต้องตั้ง navigatorKey ใน MaterialApp)
  // หมายเหตุ: วิธีนี้อาจไม่เสถียร ควรใช้ DI หรือ Service Locator ในแอปขนาดใหญ่
  // ลบฟังก์ชัน _getNavigatorKey ที่ไม่ได้ใช้งาน

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

  /// แสดง local notification สำหรับสายเข้าโดยเฉพาะ
  Future<void> _showCallNotification({
    required String title,
    required String body,
    required Map<String, dynamic> callData,
  }) async {
    final payload = jsonEncode({
      'type': 'call',
      'channelId': callData['channelId'] ?? '',
      'token': callData['token'],
      'callerId': callData['callerId'] ?? callData['caller_id'] ?? '',
      'callerName': callData['callerName'] ?? 'ผู้โทร',
      'callerPhotoUrl': callData['callerPhotoUrl'],
      'isVideo': _resolveIsVideoFlag(callData),
    });

    const androidDetails = AndroidNotificationDetails(
      'call_channel', // ID ใหม่สำหรับสายเข้า
      'การแจ้งเตือนสายเรียกเข้า',
      channelDescription: 'แจ้งเตือนเมื่อมีสายเรียกเข้า',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('ringtone'), // ต้องมีไฟล์ ringtone.mp3 ใน res/raw
      fullScreenIntent: true, // ทำให้แสดงผลเต็มจอ
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'ringtone.aiff', // ต้องมีไฟล์ ringtone.aiff ใน project
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(0, title, body, notificationDetails, payload: payload);
  }

  /// จัดการเมื่อกด notification
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic> && decoded['type'] == 'call') {
        _navigateToIncomingCall(
          channelId: decoded['channelId'] as String? ?? '',
          token: decoded['token'] as String?,
          callerId: decoded['callerId'] as String? ?? '',
          callerName: decoded['callerName'] as String? ?? 'ผู้โทร',
          callerPhotoUrl: decoded['callerPhotoUrl'] as String?,
          isVideo: decoded['isVideo'] == true,
        );
        return;
      }
      debugPrint('Notification tapped with payload: $payload');
    } catch (error) {
      debugPrint('Failed to parse notification payload: $error');
    }
  }

  /// จัดการเมื่อกด notification จาก background
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped from background: ${message.messageId}');
    final orderId = message.data['orderId'];
    if (orderId != null) {
      // TODO: Navigate to order details
    }

    // เปิดหน้ารับสายอัตโนมัติเมื่อแตะ notification ประเภท call
    if (message.data['type'] == 'call') {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final callerId = message.data['callerId'] ?? message.data['caller_id'];
      if (currentUid != null && callerId != null && currentUid == callerId) {
        debugPrint('Skip navigating to CallScreen for self-originated notification');
        return;
      }
      _navigateToIncomingCall(
        channelId: message.data['channelId'] ?? '',
        token: message.data['token'],
        callerId: message.data['callerId'] ?? message.data['caller_id'] ?? '',
        callerName: message.data['callerName'] ?? 'ผู้โทร',
        callerPhotoUrl: message.data['callerPhotoUrl'],
        isVideo: _resolveIsVideoFlag(message.data),
      );
    }
  }

  void _navigateToIncomingCall({
    required String channelId,
    required String? token,
    required String callerId,
    required String callerName,
    String? callerPhotoUrl,
    required bool isVideo,
  }) {
    final navigatorState = MyApp.navigatorKey.currentState;
    final context = navigatorState?.context;
    if (context == null) {
      debugPrint('Navigator context unavailable, cannot open CallScreen');
      return;
    }

    navigatorState!.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CallScreen(
          channelName: channelId,
          targetProfile: UserProfile.fromMap(
            callerId,
            {
              'displayName': callerName,
              'photoUrl': callerPhotoUrl,
            },
          ),
          isVideo: isVideo,
          isIncoming: true,
          tokenOverride: token,
        ),
      ),
    );
  }

  bool _resolveIsVideoFlag(Map<String, dynamic> data) {
    final raw = data['callType'] ?? data['isVideo'];
    if (raw is bool) return raw;
    if (raw is String) {
      final lower = raw.toLowerCase();
      return lower == 'video' || lower == 'true';
    }
    return false;
  }

  /// ส่ง notification แบบ manual (สำหรับทดสอบ)
  Future<void> sendTestNotification() async {
    await _showLocalNotification(
      title: 'ทดสอบการแจ้งเตือน',
      body: 'นี่คือการแจ้งเตือนทดสอบจากระบบ',
    );
  }

  // ฟังก์ชันสำหรับโทรจริง (voice/video call)
  // เรียก Cloud Function callUser
  Future<void> callUser({
    required String callerId,
    required String callerName,
    required String callerPhotoUrl,
    required String calleeId,
    required String calleeFCMToken,
    required String callType, // 'voice' หรือ 'video'
  }) async {
    final callable = FirebaseFunctions.instanceFor().httpsCallable('callUser');
    final result = await callable.call({
      'callerId': callerId,
      'callerName': callerName,
      'callerPhotoUrl': callerPhotoUrl,
      'calleeId': calleeId,
      'calleeFCMToken': calleeFCMToken,
      'callType': callType,
    });
    print('Call result: ${result.data}');
  }

  /// เริ่มการโทรโดยเรียก Cloud Function เพื่อสร้าง token และส่ง notification
  Future<Map<String, dynamic>> initiateCall({
    required UserProfile caller,
    required UserProfile callee,
    required bool isVideo,
  }) async {
    const List<String> preferredRegions = <String>['asia-southeast1', 'us-central1'];
    FirebaseFunctionsException? lastError;

    for (final region in preferredRegions) {
      try {
        final callable = FirebaseFunctions.instanceFor(region: region).httpsCallable('initiateCall');
        final result = await callable.call(<String, dynamic>{
          'calleeId': callee.uid,
          'callerId': caller.uid,
          'callerName': caller.displayName,
          'callerPhotoUrl': caller.photoUrl,
          'isVideo': isVideo,
          'callType': isVideo ? 'video' : 'voice',
          'callerData': caller.toFirestore()..['uid'] = caller.uid,
        });
        return Map<String, dynamic>.from(result.data);
      } on FirebaseFunctionsException catch (e) {
        lastError = e;
        debugPrint('Error initiating call via $region: ${e.code} - ${e.message}');
        if (e.code != 'not-found') {
          rethrow;
        }
      }
    }

    if (lastError != null) {
      throw lastError;
    }
    throw FirebaseFunctionsException(code: 'unknown', message: 'Unknown error initiating call');
  }
}

/// Background message handler (ต้องเป็น top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.messageId}');
  // ไม่ต้องทำอะไร เพราะ Cloud Functions จะจัดการให้
}
