import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:van1/utils/feature_flags.dart';

/// Ensures App Check token is available before financial callables.
class AppCheckGuard {
  const AppCheckGuard._();

  static Future<void> ensureFinancialReady() async {
    await _ensureToken(
      releaseMessage:
          'ไม่สามารถยืนยันความปลอดภัยของอุปกรณ์ได้ กรุณาอัปเดตแอปจาก Play Store แล้วลองใหม่',
      requiredInDebug: true,
    );
  }

  static Future<void> _ensureToken({
    required String releaseMessage,
    bool requiredInDebug = false,
  }) async {
    Object? lastError;
    for (final forceRefresh in [false, true]) {
      try {
        await FirebaseAppCheck.instance
            .getToken(forceRefresh)
            .timeout(const Duration(seconds: 8));
        return;
      } catch (error) {
        lastError = error;
      }
    }

    if (kReleaseMode || requiredInDebug) {
      if (kDebugMode && requiredInDebug) {
        throw Exception(
          'App Check ยังไม่พร้อม — ลงทะเบียน debug token ใน Firebase Console → App Check → van.merchant: $kVan1AppCheckDebugToken',
        );
      }
      throw Exception(releaseMessage);
    }
    if (kDebugMode && lastError != null) {
      debugPrint('App Check token unavailable (debug): $lastError');
    }
  }
}
