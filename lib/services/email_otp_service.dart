import 'package:cloud_functions/cloud_functions.dart';

class EmailOtpSendResult {
  const EmailOtpSendResult({
    required this.alreadyVerified,
    required this.email,
    required this.expiresInSeconds,
    required this.resendAvailableInSeconds,
  });

  final bool alreadyVerified;
  final String? email;
  final int? expiresInSeconds;
  final int? resendAvailableInSeconds;
}

class EmailOtpVerifyResult {
  const EmailOtpVerifyResult({
    required this.verified,
    required this.alreadyVerified,
  });

  final bool verified;
  final bool alreadyVerified;
}

class EmailOtpService {
  EmailOtpService._();

  static final EmailOtpService instance = EmailOtpService._();
  static const String _region = 'asia-southeast1';

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: _region);

  Future<EmailOtpSendResult> sendOtp() async {
    final result = await _functions.httpsCallable('sendEmailOtp').call();
    final data = _asMap(result.data);
    return EmailOtpSendResult(
      alreadyVerified: data['alreadyVerified'] == true,
      email: data['email'] as String?,
      expiresInSeconds: _toInt(data['expiresInSeconds']),
      resendAvailableInSeconds: _toInt(data['resendAvailableInSeconds']),
    );
  }

  Future<EmailOtpVerifyResult> verifyOtp(String code) async {
    final normalizedCode = code.trim();
    final result = await _functions.httpsCallable('verifyEmailOtp').call(
      <String, dynamic>{'otp': normalizedCode},
    );
    final data = _asMap(result.data);
    return EmailOtpVerifyResult(
      verified: data['verified'] == true || data['success'] == true,
      alreadyVerified: data['alreadyVerified'] == true,
    );
  }

  String mapError(
    Object error, {
    String fallback = 'เกิดข้อผิดพลาดในการยืนยันอีเมล',
  }) {
    if (error is FirebaseFunctionsException) {
      final message = error.message?.trim();
      switch (error.code) {
        case 'unauthenticated':
          return 'กรุณาเข้าสู่ระบบใหม่แล้วลองอีกครั้ง';
        case 'invalid-argument':
          return message ?? 'รหัส OTP ไม่ถูกต้อง';
        case 'deadline-exceeded':
          return message ?? 'รหัส OTP หมดอายุ กรุณาขอรหัสใหม่';
        case 'resource-exhausted':
          return message ?? 'คุณขอรหัสบ่อยเกินไป กรุณารอสักครู่';
        case 'failed-precondition':
          return message ?? 'ระบบยังไม่พร้อมส่ง OTP อีเมล';
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
