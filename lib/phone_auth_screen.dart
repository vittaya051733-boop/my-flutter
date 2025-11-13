import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // Import Timer
import 'navigation_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'utils/app_colors.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = false;
  bool _isOtpSent = false;
  String _verificationId = '';
  int? _resendToken;

  // New: To hold password during registration
  String? _passwordForRegistration;
  String? _serviceTypeForRegistration;

  Timer? _countdownTimer;
  int _countdownSeconds = 120;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;

    String? phoneNumber;
    if (args is Map) {
      phoneNumber = args['phone'] as String?;
      _passwordForRegistration = args['password'] as String?;
      _serviceTypeForRegistration = args['serviceType'] as String?;
    } else if (args is String) {
      phoneNumber = args;
    }

    if (phoneNumber != null && _phoneController.text.isEmpty) {
      _phoneController.text = phoneNumber;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isOtpSent) {
          _sendOtp();
        }
      });
    } else if (_phoneController.text.isEmpty) {
      _phoneController.text = '+66'; // Default if no number is passed
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel(); // Cancel any existing timer
    _countdownSeconds = 120;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdownSeconds > 0) {
          _countdownSeconds--;
        } else {
          _countdownTimer?.cancel();
        }
      });
    });
  }


  Future<void> _sendOtp() async {
    final phoneNumber = _phoneController.text.trim();
    // Firebase requires the E.164 format, which must start with a '+'.
    if (!phoneNumber.startsWith('+')) {
      if (mounted) { // curly_braces_in_flow_control_structures
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'รูปแบบเบอร์โทรไม่ถูกต้อง ต้องขึ้นต้นด้วย + ตามด้วยรหัสประเทศ (เช่น +66... หรือ +81...)'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (on some Android devices)
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          
          String message = 'เกิดข้อผิดพลาดในการส่ง OTP';
          if (e.code == 'invalid-phone-number') {
            message = 'เบอร์โทรศัพท์ไม่ถูกต้อง';
          } else if (e.code == 'too-many-requests') {
            message = 'มีการขอ OTP มากเกินไป กรุณาลองใหม่ภายหลัง';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
            ),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _isOtpSent = true;
            _verificationId = verificationId;
            _resendToken = resendToken;
          });
          if (!mounted) return;
          _startCountdown();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ส่ง OTP ไปที่ ${_phoneController.text} แล้ว'),
              backgroundColor: Colors.green,
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอก OTP 6 หลัก')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text.trim(),
      );

      await _signInWithCredential(credential);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      String message = 'OTP ไม่ถูกต้อง';
      if (e.toString().contains('invalid-verification-code')) {
        message = 'รหัส OTP ไม่ถูกต้อง';
      } else if (e.toString().contains('session-expired')) {
        message = 'OTP หมดอายุ กรุณาขอรหัสใหม่';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        // If a password was provided during registration, update the user's password now.
        if (_passwordForRegistration != null && _passwordForRegistration!.isNotEmpty) {
          await userCredential.user!.updatePassword(_passwordForRegistration!);
          // Clear the password from memory
          _passwordForRegistration = null;
        }

        if (mounted) { // mounted check
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ยืนยันเบอร์โทรสำเร็จ! เข้าสู่ระบบแล้ว'),
              backgroundColor: Colors.green,
            ),
          );
          
          // ตรวจสอบสถานะและนำทางอัตโนมัติ
          // ถ้ามี serviceType มาจากการลงทะเบียน ให้บันทึกลงใน contract ก่อน
          if (_serviceTypeForRegistration != null && userCredential.user != null) {
            await FirebaseFirestore.instance.collection('contracts').doc(userCredential.user!.uid).set({
              'serviceType': _serviceTypeForRegistration,
              'status': 'pending_acceptance', // สถานะเริ่มต้น
            }, SetOptions(merge: true));
          }

          // ใช้ NavigationHelper เพื่อนำทาง
          if (!mounted) return;
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await NavigationHelper.navigateBasedOnUserStatus(context, user);
          } else {
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการเข้าสู่ระบบ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('ยืนยันเบอร์โทร'),
  backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            
            // Phone Icon
            const Icon(
              Icons.phone_android,
              size: 80,
              color: AppColors.accent,
            ),
            
            const SizedBox(height: 24),
            
            // Title
            Text(
              _isOtpSent ? 'ยืนยันรหัส OTP' : 'เข้าสู่ระบบด้วยเบอร์โทร',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Description
            Text(
              _isOtpSent 
                  ? 'กรุณากรอกรหัส OTP 6 หลักที่ส่งไปที่\n${_phoneController.text}'
                  : 'กรุณากรอกเบอร์โทรศัพท์เพื่อรับรหัส OTP',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            
            const SizedBox(height: 32),
            
            if (!_isOtpSent) ...[
              // Phone Number Field
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'เบอร์โทรศัพท์',
                  hintText: '+66812345678',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Send OTP Button
              ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'ส่งรหัส OTP',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ] else ...[
              // OTP Field
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  labelText: 'รหัส OTP',
                  hintText: '123456',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Verify OTP Button
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'ยืนยัน OTP',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              
              const SizedBox(height: 16),
              
              // Resend OTP Button
              ValueListenableBuilder<bool>(
                valueListenable: ValueNotifier(_countdownSeconds > 0),
                builder: (context, isCountingDown, child) {
                  return TextButton(
                    onPressed: (_isLoading || isCountingDown) ? null : _sendOtp,
                    child: Text(
                      isCountingDown
                          ? 'ส่งรหัส OTP อีกครั้ง (${_countdownSeconds}s)'
                          : 'ส่งรหัส OTP อีกครั้ง',
                      style: TextStyle(color: isCountingDown ? Colors.grey : AppColors.accent, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Back to login
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'กลับไปหน้าเข้าสู่ระบบ',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }
}