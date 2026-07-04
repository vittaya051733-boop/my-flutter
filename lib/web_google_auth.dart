import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firebase Auth popup/redirect for web — avoids GoogleSignIn clientId origin errors.
Future<UserCredential> signInWithGoogleForWeb() async {
  final provider = GoogleAuthProvider();
  provider.setCustomParameters(<String, String>{'prompt': 'select_account'});

  try {
    return await FirebaseAuth.instance.signInWithPopup(provider);
  } on FirebaseAuthException catch (error) {
    final useRedirect = error.code == 'auth/popup-blocked' ||
        error.code == 'auth/popup-closed-by-user' ||
        error.code == 'auth/cancelled-popup-request' ||
        error.code == 'auth/operation-not-supported-in-this-environment';
    if (!useRedirect) {
      rethrow;
    }
    await FirebaseAuth.instance.signInWithRedirect(provider);
    throw FirebaseAuthException(
      code: 'auth/redirect-initiated',
      message: 'กำลังเปิดหน้าเข้าสู่ระบบ Google...',
    );
  }
}

Future<UserCredential?> handleWebGoogleRedirectResult() async {
  if (!kIsWeb) {
    return null;
  }

  final result = await FirebaseAuth.instance.getRedirectResult();
  final user = result.user;
  if (user == null || user.isAnonymous) {
    return null;
  }
  return result;
}
