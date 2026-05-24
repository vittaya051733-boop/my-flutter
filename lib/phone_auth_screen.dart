import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'dart:async'; // Import Timer
import 'navigation_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/notification_service.dart';
import 'utils/app_colors.dart';
import 'utils/phone_login_helper.dart';

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
  Map<String, dynamic>? _branchAssignmentForRegistration;

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
      final branchAssignment = args['branchAssignment'];
      if (branchAssignment is Map) {
        _branchAssignmentForRegistration = Map<String, dynamic>.from(
          branchAssignment,
        );
      }
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
    final phoneNumber = PhoneLoginHelper.normalize(
      _phoneController.text.trim(),
    );
    if (!phoneNumber.startsWith('+')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'รูปแบบเบอร์โทรไม่ถูกต้อง ต้องขึ้นต้นด้วย + ตามด้วยรหัสประเทศ (เช่น +66..., +81...)',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    _phoneController.text = phoneNumber;

    setState(() {
      _isLoading = true;
    });

    try {
      // User does not exist, proceed with OTP registration
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
          } else if (e.code == 'operation-not-allowed') {
            message = 'ยังไม่ได้เปิดการเข้าสู่ระบบด้วยเบอร์โทรใน Firebase';
          } else if (e.code == 'app-not-authorized') {
            message =
                'แอปนี้ยังไม่ได้รับอนุญาตจาก Firebase กรุณาตรวจสอบ SHA-1/SHA-256';
          } else if (e.code == 'captcha-check-failed') {
            message =
                'ยืนยันความปลอดภัยของแอปไม่สำเร็จ กรุณาลองใหม่บนเครื่องจริง';
          } else if (e.code == 'quota-exceeded') {
            message = 'โควตา SMS OTP เต็ม กรุณาลองใหม่ภายหลัง';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
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
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP ต้องเป็นตัวเลข 6 หลัก')),
      );
      return;
    }

    if (_verificationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากดส่ง OTP อีกครั้งก่อนยืนยัน')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );

      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      String message = 'OTP ไม่ถูกต้อง';
      if (e.code == 'invalid-verification-code') {
        message = 'รหัส OTP ไม่ถูกต้อง';
      } else if (e.code == 'session-expired') {
        message = 'OTP หมดอายุ กรุณาขอรหัสใหม่';
      } else if (e.code == 'invalid-verification-id') {
        message = 'รหัสยืนยันหมดอายุ กรุณากดส่ง OTP อีกครั้ง';
      } else if (e.code == 'credential-already-in-use') {
        message = 'เบอร์นี้ผูกกับบัญชีอื่นแล้ว';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      if (userCredential.user != null) {
        final normalizedPhone = PhoneLoginHelper.normalize(
          _phoneController.text.trim(),
        );
        final bool hasPassword =
            _passwordForRegistration != null &&
            _passwordForRegistration!.isNotEmpty;
        final firebaseUser = userCredential.user!;

        if (hasPassword) {
          final pseudoEmail = PhoneLoginHelper.pseudoEmail(normalizedPhone);
          final emailCredential = EmailAuthProvider.credential(
            email: pseudoEmail,
            password: _passwordForRegistration!,
          );
          try {
            await firebaseUser.linkWithCredential(emailCredential);
          } on FirebaseAuthException catch (e) {
            if (e.code == 'provider-already-linked') {
              await firebaseUser.updatePassword(_passwordForRegistration!);
            } else {
              rethrow;
            }
          }

          await FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser.uid)
              .set({
                'loginEmail': pseudoEmail,
                'loginProvider': 'phone',
                ...?_branchAssignmentForRegistration,
              }, SetOptions(merge: true));
          _passwordForRegistration = null;
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .set({
              'phoneNumber': normalizedPhone,
              'phoneVerifiedAt': FieldValue.serverTimestamp(),
              ...?_branchAssignmentForRegistration,
            }, SetOptions(merge: true));

        try {
          await NotificationService().saveUserFcmToken(firebaseUser.uid);
        } catch (e) {
          debugPrint('Failed to sync FCM token after phone auth: $e');
        }

        if (mounted) {
          // mounted check
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ยืนยันเบอร์โทรสำเร็จ! เข้าสู่ระบบแล้ว'),
              backgroundColor: Colors.green,
            ),
          );

          // ตรวจสอบสถานะและนำทางอัตโนมัติ
          // ถ้ามี serviceType มาจากการลงทะเบียน ให้บันทึกลงใน contract ก่อน
          if (_serviceTypeForRegistration != null &&
              userCredential.user != null) {
            await FirebaseFirestore.instance
                .collection('contracts')
                .doc(userCredential.user!.uid)
                .set({
                  'serviceType': _serviceTypeForRegistration,
                  'status': 'pending_acceptance', // สถานะเริ่มต้น
                  ...?_branchAssignmentForRegistration,
                }, SetOptions(merge: true));
          }

          // ใช้ NavigationHelper เพื่อนำทาง
          if (!mounted) return;
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await NavigationHelper.navigateBasedOnUserStatus(context, user);
          } else {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/home', (route) => false);
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
            const Icon(Icons.phone_android, size: 80, color: AppColors.accent),

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
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),

            const SizedBox(height: 32),

            if (!_isOtpSent) ...[
              // Phone Number Field
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
                ],
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ] else ...[
              // OTP Field
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
                      style: TextStyle(
                        color: isCountingDown ? Colors.grey : AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
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
