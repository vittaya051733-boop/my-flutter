import 'package:cloud_functions/cloud_functions.dart';

class PhoneRegistrationOtpSendResult {
  const PhoneRegistrationOtpSendResult({
    required this.success,
    required this.expiresInSeconds,
  });

  final bool success;
  final int expiresInSeconds;
}

class PhoneRegistrationOtpVerifyResult {
  const PhoneRegistrationOtpVerifyResult({
    required this.success,
    required this.customToken,
    required this.uid,
  });

  final bool success;
  final String customToken;
  final String uid;
}

class PhoneRegistrationOtpService {
  PhoneRegistrationOtpService._();

  static final PhoneRegistrationOtpService instance =
      PhoneRegistrationOtpService._();
  static const String _region = 'asia-southeast1';

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: _region);

  Future<PhoneRegistrationOtpSendResult> sendOtp(String phoneNumber) async {
    final result = await _functions.httpsCallable('sendMerchantPhoneOtp').call(
      <String, dynamic>{'phoneNumber': phoneNumber},
    );
    final data = _asMap(result.data);
    return PhoneRegistrationOtpSendResult(
      success: data['success'] == true,
      expiresInSeconds: _toInt(data['expiresInSeconds']) ?? 600,
    );
  }

  Future<PhoneRegistrationOtpVerifyResult> verifyOtp({
    required String phoneNumber,
    required String otp,
    String? password,
  }) async {
    final payload = <String, dynamic>{
      'phoneNumber': phoneNumber,
      'otp': otp.trim(),
    };
    final normalizedPassword = password?.trim();
    if (normalizedPassword != null && normalizedPassword.isNotEmpty) {
      payload['password'] = normalizedPassword;
    }

    final result =
        await _functions.httpsCallable('verifyMerchantPhoneOtp').call(payload);
    final data = _asMap(result.data);
    final customToken = data['customToken'] as String? ?? '';
    final uid = data['uid'] as String? ?? '';
    if (customToken.isEmpty || uid.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'ยืนยัน OTP สำเร็จ แต่ไม่ได้รับโทเค็นเข้าสู่ระบบ',
      );
    }

    return PhoneRegistrationOtpVerifyResult(
      success: data['success'] == true,
      customToken: customToken,
      uid: uid,
    );
  }

  String mapError(
    Object error, {
    String fallback = 'เกิดข้อผิดพลาดในการยืนยันเบอร์โทร',
  }) {
    if (error is FirebaseFunctionsException) {
      final message = error.message?.trim();
      switch (error.code) {
        case 'invalid-argument':
          return message ?? 'ข้อมูลไม่ถูกต้อง';
        case 'deadline-exceeded':
          return message ?? 'รหัส OTP หมดอายุ กรุณาขอรหัสใหม่';
        case 'resource-exhausted':
          return message ?? 'กรุณารอสักครู่แล้วลองใหม่';
        case 'failed-precondition':
          return message ?? 'กรุณากดส่ง OTP ก่อนยืนยัน';
        case 'unavailable':
          return message ??
              'ระบบส่ง SMS ไม่พร้อม กรุณาลองใหม่ภายหลัง';
        default:
          return message ?? fallback;
      }
    }
    return fallback;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<Object?, Object?>) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    if (data is Map<String, dynamic>) {
      return data;
    }
    return const <String, dynamic>{};
  }

  int? _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }
}
