import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async'; // Import the async library for Timer
import 'utils/app_colors.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isSendingVerification = false;
  Timer? _timer;
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // Start a timer to periodically check the email verification status.
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _checkEmailVerified());
  }

  @override
  void dispose() {
    _timer?.cancel(); // Always cancel the timer to prevent memory leaks.
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser?.emailVerified == true) {
        _timer?.cancel();
        if (!mounted) return;

        final args = ModalRoute.of(context)?.settings.arguments;
        String? serviceType;
        String? nextRoute;
        if (args is Map<String, dynamic>) {
          serviceType = args['serviceType'] as String?;
          nextRoute = args['nextRoute'] as String?;
        } else if (args is String?) {
          serviceType = args;
        }

        final targetRoute = switch (nextRoute) {
          'contract' => '/contract',
          'post-intro' => '/post-verification-intro',
          _ => '/contract',
        };

        Navigator.of(context).pushNamedAndRemoveUntil(
          targetRoute,
          (route) => false,
          arguments: serviceType,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.message?.contains('Too many attempts') ?? false) {
        await Future.delayed(const Duration(seconds: 5));
      }
    } catch (e) {
      // ดักจับ error ที่อาจเกิดจากการ reload บ่อยไป (เช่น too-many-requests)
      // ไม่ต้องทำอะไร ปล่อยให้ timer ทำงานรอบถัดไป
      // debugPrint('Error checking email verification: $e');
    }
  }

  Future<void> _sendVerificationEmail() async {
    if (user == null) return;

    setState(() {
      _isSendingVerification = true;
    });

    try {
      // Always reload user state before any action to get the latest status.
      await user!.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser?.emailVerified == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ อีเมลของคุณได้รับการยืนยันแล้ว!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      // Send verification email
      await user!.sendEmailVerification();
      debugPrint('📧 ส่งอีเมลยืนยันแล้ว: ${user!.email}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ส่งอีเมลยืนยันไปที่ ${user!.email} อีกครั้งแล้ว กรุณาตรวจสอบโฟลเดอร์ Spam/Junk ด้วย'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ เกิดข้อผิดพลาดในการส่งอีเมล: $e');
      if (mounted) {
        String errorMessage = 'เกิดข้อผิดพลาดในการส่งอีเมล';

        if (e is FirebaseAuthException && e.code == 'too-many-requests') {
          errorMessage = '⚠️ ส่งอีเมลบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่';
        } else if (e.toString().contains('network')) {
          errorMessage = '🌐 เกิดปัญหาเครือข่าย กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingVerification = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ยืนยันอีเมล'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.email_outlined, size: 80, color: AppColors.accent),
              const SizedBox(height: 24),
              const Text(
                'กรุณายืนยันอีเมลของคุณ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'เราได้ส่งลิงก์ยืนยันไปที่:\n${user?.email ?? "อีเมลของคุณ"}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📧 วิธีตรวจสอบอีเมล:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('• ตรวจสอบกล่องจดหมาย (Inbox)'),
                    const Text('• ตรวจสอบโฟลเดอร์สแปม/ขยะ (Spam/Junk)'),
                    const Text('• ตรวจสอบโฟลเดอร์โฆษณา (Promotions)'),
                    const Text('• รอ 5-10 นาทีหากยังไม่เห็นอีเมล'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isSendingVerification ? null : _sendVerificationEmail,
                icon: _isSendingVerification
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: Text(_isSendingVerification ? 'กำลังส่ง...' : 'ส่งอีเมลยืนยันอีกครั้ง'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/email-helper', arguments: user?.email);
                },
                icon: const Icon(Icons.help_outline),
                label: const Text('พบปัญหา?'),
                style: TextButton.styleFrom(foregroundColor: Colors.blue.shade700),
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text('ออกจากระบบ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}