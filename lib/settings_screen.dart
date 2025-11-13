import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'register_shop_screen.dart';
import 'edit_profile_screen.dart';
import 'welcome_screen.dart';
import 'utils/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _showChangePasswordDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเปลี่ยนรหัสผ่านได้สำหรับบัญชีนี้ (อาจเป็น Social Login)')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ส่งลิงก์เปลี่ยนรหัสผ่านไปที่ ${user.email} แล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าและบัญชี'),
        // This removes the back button since it's a main tab screen.
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Scrollable area for settings
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (user != null) ...[
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: AppColors.accent,
                              backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                              child: user.photoURL == null
                                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              user.displayName ?? 'ผู้ใช้งาน',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email ?? user.phoneNumber ?? 'ไม่ได้ระบุข้อมูล',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('แก้ไขโปรไฟล์'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
                      },
                    ),
                    const SizedBox(height: 24),
                    // Show "Change Password" only for email/password provider
                    if (user.providerData.any((p) => p.providerId == 'password'))
                      Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.security_outlined),
                            title: const Text('เปลี่ยนรหัสผ่าน'),
                            subtitle: const Text('แนะนำให้เปลี่ยนรหัสผ่านเป็นประจำ'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _showChangePasswordDialog,
                          ),
                          const Divider(),
                        ],
                      ),
                  ],
                  // เพิ่มปุ่มแก้ไขการลงทะเบียนร้าน (ถ้ามีร้านค้าอยู่แล้ว)
                  if (user != null)
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('shops').doc(user.uid).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.0),
                            child: LinearProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                          return const SizedBox.shrink();
                        }
                        // ถ้ามีร้านค้าแล้ว ให้แสดงปุ่มแก้ไข
                        return Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.storefront_outlined),
                              title: const Text('แก้ไขการลงทะเบียนร้าน'),
                              subtitle: const Text('แก้ไขข้อมูลร้านค้าของคุณ'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RegisterShopScreen(shopData: snapshot.data),
                                ),
                              ),
                            ),
                            const Divider(),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // Sign out area
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('ออกจากระบบ', style: TextStyle(fontSize: 16, color: Colors.white)),
                onPressed: () async {
                  if (!mounted) return;

                  // NEW: Confirm, provider-aware sign out, with error handling
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('ยืนยันการออกจากระบบ'),
                      content: const Text('คุณต้องการออกจากระบบหรือไม่?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
                        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('ยืนยัน')),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  if (!context.mounted) return;

                  try {
                    final providers = user.providerData.map((p) => p.providerId).toSet();
                    if (providers.contains('google.com')) {
                      await GoogleSignIn().signOut();
                      if (!context.mounted) return;
                    }
                    if (providers.contains('facebook.com')) {
                      await FacebookAuth.instance.logOut();
                      if (!context.mounted) return;
                    }
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                      (route) => false,
                    );
                    // Navigation after sign-out is handled by the root StreamBuilder in main.dart
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('ไม่สามารถออกจากระบบได้: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
