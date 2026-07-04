import 'package:flutter/foundation.dart';

/// เปิดด้วย `--dart-define=PHONE_AUTH_TEST_MODE=true` สำหรับ release/QA
/// ที่ใช้เบอร์ทดสอบใน Firebase Console → Auth → Phone numbers for testing
const bool kPhoneAuthTestMode =
    bool.fromEnvironment('PHONE_AUTH_TEST_MODE', defaultValue: false);

/// ข้าม Play Integrity / reCAPTCHA — ใช้ได้เฉพาะ debug หรือ QA test mode
bool get shouldDisablePhoneAppVerification =>
    !kIsWeb && (kDebugMode || kPhoneAuthTestMode);
