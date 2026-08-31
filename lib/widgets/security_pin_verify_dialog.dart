import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/security_pin_service.dart';
import 'security_pin_keypad.dart';

/// Returns true when the user entered the correct security PIN.
Future<bool> showSecurityPinVerifyDialog(
  BuildContext context, {
  required String title,
  String subtitle = 'กรุณาใส่รหัส PIN 6 หลักที่ตั้งไว้ตอนลงทะเบียน',
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return false;
  }

  final keypadKey = GlobalKey<SecurityPinKeypadState>();
  var verifying = false;
  String? errorText;

  final verified = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> submit(String pin) async {
            if (verifying) {
              return;
            }
            if (!SecurityPinService.instance.isValidPinFormat(pin)) {
              setState(() => errorText = 'กรุณากรอกรหัส PIN 6 หลัก');
              return;
            }
            setState(() {
              verifying = true;
              errorText = null;
            });
            final ok = await SecurityPinService.instance.verifyPin(uid, pin);
            if (!context.mounted) {
              return;
            }
            if (ok) {
              Navigator.of(context).pop(true);
              return;
            }
            keypadKey.currentState?.clear();
            setState(() {
              verifying = false;
              errorText = 'รหัส PIN ไม่ถูกต้อง';
            });
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(subtitle),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 8),
                if (verifying)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  SecurityPinKeypad(
                    key: keypadKey,
                    enabled: !verifying,
                    onCompleted: submit,
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: verifying
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('ยกเลิก'),
              ),
            ],
          );
        },
      );
    },
  );

  return verified == true;
}

/// Guard for wallet / admin support flows.
Future<bool> verifySecurityPinForSensitiveAction(
  BuildContext context, {
  required String title,
  String? subtitle,
}) {
  return showSecurityPinVerifyDialog(
    context,
    title: title,
    subtitle: subtitle ??
        'กรุณาใส่รหัส PIN 6 หลักที่ตั้งไว้ตอนลงทะเบียน',
  );
}
