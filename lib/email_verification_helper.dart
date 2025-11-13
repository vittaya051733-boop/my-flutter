import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'navigation_helper.dart';

import 'utils/app_colors.dart';

class EmailVerificationHelper extends StatefulWidget {
  final String? prefilledEmail;
  
  const EmailVerificationHelper({super.key, this.prefilledEmail});

  @override
  State<EmailVerificationHelper> createState() => _EmailVerificationHelperState();
}

class _EmailVerificationHelperState extends State<EmailVerificationHelper> {
  final TextEditingController _emailController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledEmail != null) {
      _emailController.text = widget.prefilledEmail!;
    }
  }

  Future<void> _checkEmailAndHelp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('กรุณาใส่อีเมล', AppColors.accent);
      return;
    }

    setState(() => _loading = true);
    
    try {
      // Instead of checking first, just try to send the reset email.
      // This is the recommended flow to prevent email enumeration attacks.
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) {
        _showDialog(
          title: '✅ ส่งคำขอรีเซ็ตแล้ว',
          content: '''หากอีเมล $email มีอยู่ในระบบ เราได้ส่งลิงก์สำหรับรีเซ็ตรหัสผ่านไปให้แล้ว

📧 ได้ส่งลิงก์รีเซ็ตรหัสผ่านไปแล้ว

🔍 วิธีหาอีเมลใน Gmail:
• ตรวจสอบใน Inbox ก่อน
• ดูในโฟลเดอร์ Spam/จดหมายขยะ
• ดูในแท็บ โปรโมชัน (Promotions)
• ค้นหาคำว่า "Firebase", "VanMarket", "รีเซ็ต"

⚡ ข้อดี: การคลิกลิงก์รีเซ็ตจะช่วยยืนยันอีเมลของคุณด้วย!

⏰ หากไม่เจออีเมล รอสัก 5-10 นาทีแล้วลองใหม่''',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('เข้าใจแล้ว'),
            ),
          ],
        );
      }
    } on FirebaseAuthException catch (e) {
      // Handle specific errors if needed, but generally we don't want to reveal
      // if an email exists or not.
      if (e.code == 'invalid-email') {
        _showMessage('รูปแบบอีเมลไม่ถูกต้อง', Colors.red);
      } else {
        // For other errors, show a generic message.
        _showMessage('เกิดข้อผิดพลาด: $e', Colors.red);
      }
    } catch (e) {
      _showMessage('เกิดข้อผิดพลาด: $e', Colors.red);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendAgain() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showMessage('📧 ส่งลิงก์รีเซ็ตใหม่แล้ว! ตรวจสอบอีเมล (รวม Spam)', Colors.green);
    } catch (e) {
      _showMessage('ไม่สามารถส่งอีเมลได้: $e', Colors.red);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _tryLoginDirectly() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
  _showMessage('กรุณาใส่อีเมล', AppColors.accent);
      return;
    }

    // Show password input dialog
    String? password = await _showPasswordDialog();
    if (password == null || password.isEmpty) return;

    setState(() => _loading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        if (credential.user!.emailVerified) {
          _showMessage('🎉 เข้าสู่ระบบสำเร็จ! อีเมลยืนยันแล้ว', Colors.green);
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            // ตรวจสอบว่าเคยเซ็นสัญญาหรือยัง
            await _navigateToNextStep(credential.user!);
          }
        } else {
          // Email not verified, offer to send verification
          await FirebaseAuth.instance.signOut();
          
          final resend = await _showYesNoDialog(
            title: '⚠️ อีเมลยังไม่ได้ยืนยัน',
            content: 'บัญชีของคุณมีอยู่แต่อีเมลยังไม่ได้ยืนยัน\nต้องการให้ส่งลิงก์รีเซ็ตรหัสผ่าน (ซึ่งจะยืนยันอีเมลด้วย) หรือไม่?',
          );
          
          if (resend == true) {
            await _sendAgain();
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'เกิดข้อผิดพลาด';
      switch (e.code) {
        case 'wrong-password':
          message = 'รหัสผ่านไม่ถูกต้อง\nลองใช้ "ส่งลิงก์รีเซ็ตรหัสผ่าน" แทน';
          break;
        case 'user-not-found':
          message = 'ไม่พบผู้ใช้นี้ กรุณาสมัครสมาชิกก่อน';
          break;
        default:
          message = e.message ?? 'เกิดข้อผิดพลาดในการเข้าสู่ระบบ';
      }
      _showMessage(message, Colors.red);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _navigateToNextStep(User user) async {
    // ใช้ NavigationHelper เพื่อตรวจสอบและนำทาง
    await NavigationHelper.navigateBasedOnUserStatus(context, user);
  }

  Future<String?> _showPasswordDialog() async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ใส่รหัสผ่าน'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'รหัสผ่าน',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showYesNoDialog({required String title, required String content}) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ไม่'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ใช่'),
          ),
        ],
      ),
    );
  }

  void _showDialog({required String title, required String content, required List<Widget> actions}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: actions,
      ),
    );
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 แก้ปัญหาอีเมลยืนยัน'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              color: Colors.blue,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎯 เครื่องมือแก้ปัญหา',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• ตรวจสอบว่าอีเมลสมัครแล้วหรือยัง\n'
                      '• ส่งลิงก์รีเซ็ตรหัสผ่าน (ยืนยันอีเมลอัตโนมัติ)\n'
                      '• แนะนำวิธีหาอีเมลใน Gmail\n'
                      '• ทดสอบเข้าสู่ระบบ',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'อีเมล',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
                helperText: 'ใส่อีเมลที่มีปัญหา',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _checkEmailAndHelp,
              icon: _loading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.help_outline),
              label: Text(_loading ? 'กำลังตรวจสอบ...' : '🔍 ตรวจสอบและช่วยแก้ปัญหา'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : _tryLoginDirectly,
              icon: const Icon(Icons.login),
              label: const Text('🚪 ลองเข้าสู่ระบบ (หากจำรหัสผ่านได้)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            const Card(
              color: AppColors.accentLight,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 เคล็ดลับหาอีเมลใน Gmail',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. ตรวจสอบใน Inbox ก่อน\n'
                      '2. ดูในโฟลเดอร์ Spam/จดหมายขยะ\n'
                      '3. ดูในแท็บ โปรโมชัน (Promotions)\n'
                      '4. ค้นหาคำว่า "Firebase", "VanMarket", "รีเซ็ต"\n'
                      '5. รอ 5-10 นาที อีเมลอาจมาช้า',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}