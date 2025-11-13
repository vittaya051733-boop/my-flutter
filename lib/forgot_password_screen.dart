import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'utils/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _loading = false;

  // Use the same robust phone number validation as in RegisterScreen
  bool _isPhoneNumber(String input) {
    final cleanInput = input.replaceAll(' ', '').replaceAll('-', '');
    final internationalPhoneRegex = RegExp(r'^\+[1-9]\d{1,14}$');
    final localPhoneRegex = RegExp(r'^0\d{8,12}$');
    return internationalPhoneRegex.hasMatch(cleanInput) || localPhoneRegex.hasMatch(cleanInput);
  }


  Future<void> _sendReset() async {
    final contactInput = _emailController.text.trim();
    if (contactInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกอีเมลหรือเบอร์โทรศัพท์')));
      return;
    }
    setState(() => _loading = true);
    try {
      if (_isPhoneNumber(contactInput)) {
        // ปิด flow เบอร์โทรฯ ชั่วคราวเพื่อไม่ให้แอปล้ม (ยังไม่มี route '/phone_auth')
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('การรีเซ็ตด้วยเบอร์โทรฯ ยังไม่พร้อมใช้งาน โปรดใช้การรีเซ็ตผ่านอีเมล')),
          );
        }
        return;
      } else {
        // For emails, send a password reset link
        await FirebaseAuth.instance.sendPasswordResetEmail(email: contactInput);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ส่งลิงก์รีเซ็ตรหัสผ่านไปที่ $contactInput แล้ว'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'เกิดข้อผิดพลาด';
      if (e.code == 'user-not-found') {
        message = 'ไม่พบอีเมลนี้ในระบบ';
      } else if (e.code == 'invalid-email') {
        message = 'รูปแบบอีเมลไม่ถูกต้อง';
      } else {
        message = e.message ?? 'เกิดข้อผิดพลาดที่ไม่รู้จัก';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose(); // ป้องกัน memory leak
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รีเซ็ตรหัสผ่าน')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.vpn_key_outlined, size: 80, color: AppColors.accent),
              const SizedBox(height: 24),
              const Text(
                'ลืมรหัสผ่าน?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'กรอกอีเมลหรือเบอร์โทรศัพท์ที่ลงทะเบียนไว้\nเพื่อรับคำแนะนำในการรีเซ็ตรหัสผ่าน',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress, // เหมาะกับอีเมลมากกว่า
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: 'อีเมล หรือ เบอร์โทรศัพท์',
                  prefixIcon: const Icon(Icons.contact_mail_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _sendReset,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('ส่งคำขอรีเซ็ต', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('กลับไปหน้าเข้าสู่ระบบ'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
