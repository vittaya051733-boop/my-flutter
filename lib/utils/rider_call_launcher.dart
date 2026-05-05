import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../call_screen.dart';
import '../models/user_profile.dart';
import '../services/friend_service.dart';
import '../services/notification_service.dart';

class RiderCallLauncher {
  const RiderCallLauncher._();

  static Future<void> startVoiceCall({
    required BuildContext context,
    required UserProfile? riderProfile,
    String? fallbackPhone,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final riderUid = riderProfile?.uid.trim() ?? '';

    if (riderUid.isEmpty) {
      await _callPhone(fallbackPhone, messenger);
      return;
    }

    try {
      final caller = await _buildCurrentShopProfile();
      if (!context.mounted) return;

      if (caller.uid == riderUid) {
        throw Exception('ไม่สามารถโทรหาบัญชีตัวเองได้');
      }

      final callee = riderProfile!.copyWith(
        phoneNumber: riderProfile.phoneNumber ?? fallbackPhone,
      );

      final callData = await NotificationService().initiateCall(
        caller: caller,
        callee: callee,
        isVideo: false,
      );

      if (!context.mounted) return;

      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => CallScreen(
            channelName:
                (callData['channelId'] as String?) ??
                'call_${caller.uid}_$riderUid',
            isVideo: false,
            targetProfile: callee,
            appIdOverride: callData['appId'] as String?,
            tokenOverride: callData['token'] as String?,
            isIncoming: false,
          ),
        ),
      );
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text('เริ่มการโทรไม่สำเร็จ: $error')),
      );
    }
  }

  static Future<UserProfile> _buildCurrentShopProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      throw Exception('กรุณาเข้าสู่ระบบก่อนโทรหาไรเดอร์');
    }

    final syncedProfile = await FriendService().ensureCurrentUserProfile(user);
    if (syncedProfile != null) {
      return syncedProfile;
    }

    return UserProfile(
      uid: user.uid,
      displayName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.email?.trim().isNotEmpty == true
                ? user.email!.trim()
                : 'ร้านค้า'),
      phoneNumber: user.phoneNumber,
      photoUrl: user.photoURL,
    );
  }

  static Future<void> _callPhone(
    String? phone,
    ScaffoldMessengerState? messenger,
  ) async {
    final trimmedPhone = phone?.trim();
    if (trimmedPhone == null || trimmedPhone.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('ไม่พบข้อมูลไรเดอร์สำหรับโทรออก')),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: trimmedPhone);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('ไม่สามารถโทรออกได้')),
      );
    }
  }
}
