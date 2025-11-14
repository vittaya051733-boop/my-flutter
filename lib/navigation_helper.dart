import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper class สำหรับตรวจสอบสถานะการลงทะเบียนและนำทางไปหน้าที่เหมาะสม
class NavigationHelper {
  /// ตรวจสอบสถานะและนำทางไปหน้าที่เหมาะสม
  static Future<void> navigateBasedOnUserStatus(
    BuildContext context,
    User user, {
    bool replace = true,
  }) async {
  try {
      // ไม่บังคับตรวจยืนยันอีเมลที่นี่ ตามนโยบายล่าสุดของโปรเจกต์

      // 1. ตรวจสอบว่าเคยเซ็นสัญญาหรือยัง
      final contractDoc = await FirebaseFirestore.instance
          .collection('contracts')
          .doc(user.uid)
          .get();

      if ((!contractDoc.exists || contractDoc.data()?['status'] != 'accepted') && context.mounted) {
        // ยังไม่เซ็นสัญญา -> ไปหน้าเซ็นสัญญา
        _navigate(
          context, 
          '/contract', 
          replace: replace, 
          arguments: contractDoc.data()?['serviceType'] as String?); // ส่ง serviceType ไปด้วย
        return;
      }

      // 2. เซ็นสัญญาแล้ว -> ตรวจสอบว่าลงทะเบียนร้านค้าหรือยัง
      // ตรวจสอบในทุก collection ที่เป็นไปได้
      final possibleCollections = [
        'market_registrations', 
        'shop_registrations', 
        'restaurant_registrations', 
        'pharmacy_registrations'
      ];
      DocumentSnapshot? shopDoc;

      for (final collectionName in possibleCollections) {
        final doc = await FirebaseFirestore.instance.collection(collectionName).doc(user.uid).get();
        if (doc.exists) {
          shopDoc = doc;
          break;
        }
      }
      if (!context.mounted) return;

      if (shopDoc == null || !shopDoc.exists) {
        // ยังไม่ได้ลงทะเบียนร้านค้า -> ไปหน้าลงทะเบียนร้านค้า
        _navigate(
          context,
          '/shop-registration',
          replace: replace,
          arguments: contractDoc.data()?['serviceType'] as String? ?? '',
        );
        return;
      }

      // 3. ลงทะเบียนครบถ้วนแล้ว -> ไปหน้า Home
      if (context.mounted) {
        _navigate(context, '/home', replace: replace);
      }
    } catch (e, stackTrace) {
      debugPrint('Error in navigateBasedOnUserStatus: $e\n$stackTrace');
      // หากเกิดข้อผิดพลาด ให้แสดง SnackBar และอาจมีปุ่มให้ลองใหม่
      // แทนที่จะนำทางไปหน้าอื่นทันที ซึ่งอาจทำให้ผู้ใช้สับสน
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการตรวจสอบสถานะ: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'ลองใหม่',
              onPressed: () => navigateBasedOnUserStatus(context, user, replace: replace),
            ),
          ),
        );
      }
    }
  }

  static void _navigate(
    BuildContext context,
    String routeName, {
    bool replace = true,
    Object? arguments,
  }) {
    if (!context.mounted) return;

    if (replace) {
      Navigator.of(context).pushReplacementNamed(
        routeName,
        arguments: arguments,
      );
    } else {
      Navigator.of(context).pushNamed(
        routeName,
        arguments: arguments,
      );
    }
  }

  /// ตรวจสอบว่า user ลงทะเบียนครบถ้วนหรือยัง
  static Future<bool> isRegistrationComplete(String userId) async {
    try {
      final contractDoc = await FirebaseFirestore.instance
          .collection('contracts')
          .doc(userId)
          .get();

      if (!contractDoc.exists || contractDoc.data()?['status'] != 'accepted') {
        return false;
      }

      final serviceType = contractDoc.data()?['serviceType'] as String?;
      if (serviceType == null) return false; // ถ้าไม่มี serviceType ก็ยังไม่สมบูรณ์
      final shopDoc = await FirebaseFirestore.instance
          .collection('${serviceType.toLowerCase()}_registrations') // แก้ไขการอ้างอิงชื่อ collection
          .doc(userId)
          .get();

      return shopDoc.exists;
    } catch (e) {
      debugPrint('Error checking registration status: $e');
      return false;
    }
  }

  /// ตรวจสอบการลงทะเบียนร้านค้าโดยใช้อีเมล (ไม่พึ่งข้อมูลสัญญา)
  static Future<bool> isShopRegisteredByEmail(String email) async {
    try {
      final collections = [
        'market_registrations',
        'shop_registrations',
        'restaurant_registrations',
        'pharmacy_registrations',
      ];
      for (final col in collections) {
        final snap = await FirebaseFirestore.instance
            .collection(col)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking shop by email: $e');
      return false;
    }
  }

  /// ดึงข้อมูลร้านค้า (ต้องระบุ serviceType)
  static Future<Map<String, dynamic>?> getShopData(String userId, String serviceType) async {
    try {
      final shopDoc = await FirebaseFirestore.instance
          .collection(serviceType)
          .doc(userId)
          .get();

      return shopDoc.data();
    } catch (e) {
      debugPrint('Error getting shop data: $e');
      return null;
    }
  }

  /// ดึงข้อมูลสัญญา
  static Future<Map<String, dynamic>?> getContractData(String userId) async {
    try {
      final contractDoc = await FirebaseFirestore.instance
          .collection('contracts')
          .doc(userId)
          .get();

      return contractDoc.data();
    } catch (e) {
      debugPrint('Error getting contract data: $e');
      return null;
    }
  }
}
