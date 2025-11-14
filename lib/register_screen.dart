import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // เพิ่ม import ที่ขาดไป
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'register_shop_next.dart';
import 'contract_screen.dart';
import 'utils/app_colors.dart';

class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

class RegisterScreen extends StatefulWidget {
  final String? serviceType;
  const RegisterScreen({super.key, this.serviceType});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _loading = false;
  bool _isTypingPhoneNumber = false;
  bool _isSocialLoading = false;
  String? _socialLoadingKey;
  final _debouncer = Debouncer(milliseconds: 300);
  List<MapEntry<String, String>> _countryCodeSuggestions = [];

  // A simple map of country codes for suggestions.
  // In a real app, this might come from a larger library or asset file.
  static const Map<String, String> _countryCodes = {
    '+66': 'Thailand',
    '+81': 'Japan',
    '+1': 'USA / Canada',
    '+44': 'United Kingdom',
    '+86': 'China',
    '+91': 'India',
    '+49': 'Germany',
    '+33': 'France',
    '+82': 'South Korea',
  };

  // Updated to be more internationally-friendly.
  // It checks if the input starts with a '+' and is followed by digits,
  // or if it's a local Thai number starting with '0'.
  bool _isPhoneNumber(String input) {
    final cleanInput = input.replaceAll(' ', '').replaceAll('-', '');
    final internationalPhoneRegex = RegExp(r'^\+[1-9]\d{1,14}$');
    // Expanded the local phone number regex to support more formats, including Japanese 11-digit numbers.
    // It now accepts numbers starting with '0' followed by 8 to 12 digits.
    final localPhoneRegex = RegExp(r'^0\d{8,12}$');
    return internationalPhoneRegex.hasMatch(cleanInput) || localPhoneRegex.hasMatch(cleanInput);
  }

  // Updated to handle Thai numbers specifically and assume others are either
  // already formatted with a country code or need to be handled by the user.
  String _formatPhoneNumber(String phone) {
    String cleanPhone = phone.replaceAll(' ', '').replaceAll('-', '');
    // Only format as Thai number if it starts with 0 and has 10 digits total.
    if (cleanPhone.startsWith('0') && cleanPhone.length == 10) {
      return '+66${cleanPhone.substring(1)}';
    }
    // If it already starts with '+', assume it's correctly formatted.
    // For other local formats (like Japan's 090...), we pass them as is,
    // relying on the user to input the country code for non-Thai numbers.
    return cleanPhone; // e.g., +14155552671
  }

  String? _serviceTypeNormalized;
  static const Set<String> _allowedServiceTypes = {
    'ตลาด',
    'ร้านค้า',
    'ร้านอาหาร',
    'ร้านขายยา',
  };
  static const Map<String, String> _serviceTypeAliases = {
    'market': 'ตลาด',
    'shop': 'ร้านค้า',
    'restaurant': 'ร้านอาหาร',
    'pharmacy': 'ร้านขายยา',
    'ตลาดสด': 'ตลาด',
    'marketplace': 'ตลาด',
    'store': 'ร้านค้า',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureServiceType());
  }

  Future<void> _ensureServiceType() async {
    final direct = _normalizeServiceType(widget.serviceType);
    if (direct != null) {
      if (mounted) setState(() => _serviceTypeNormalized = direct);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('contracts').doc(user.uid).get();
        final stored = _normalizeServiceType(doc.data()?['serviceType'] as String?);
        if (stored != null) {
          if (mounted) setState(() => _serviceTypeNormalized = stored);
          return;
        }
      } catch (e) {
        debugPrint('Failed to load serviceType: $e');
      }
    }

    _promptServiceTypeSelection();
  }

  String? _normalizeServiceType(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (_allowedServiceTypes.contains(trimmed)) return trimmed;
    final compact = trimmed.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    return _serviceTypeAliases[compact];
  }

  void _promptServiceTypeSelection() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('เลือกประเภทบริการ'),
        content: Text(
          'ไม่พบประเภทบริการที่ถูกต้อง (${widget.serviceType ?? 'ไม่ระบุ'})\nกรุณาเลือกใหม่อีกครั้ง',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const RegisterShopNextScreen()),
              );
            },
            child: const Text('เลือกบริการ'),
          ),
        ],
      ),
    );
  }

  void _navigateToContract() {
    if (_serviceTypeNormalized == null) {
      _promptServiceTypeSelection();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ContractScreen(serviceType: _serviceTypeNormalized),
      ),
      (route) => false,
    );
  }

  Future<void> _register() async {
    if (_serviceTypeNormalized == null) {
      _promptServiceTypeSelection();
      return;
    }
    final contactInput = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (contactInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกอีเมลหรือเบอร์โทรศัพท์')));
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกรหัสผ่าน')));
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('รหัสผ่านไม่ตรงกัน')));
      return;
    }

    setState(() => _loading = true);
    try {
      debugPrint('🔄 เริ่มสร้างบัญชี: $contactInput'); // Debug log
      
      if (_isPhoneNumber(contactInput)) {
        // Navigate to phone verification screen
        final args = {
          'phone': _formatPhoneNumber(contactInput),
          'password': password,
          'serviceType': _serviceTypeNormalized,
        };
        Navigator.pushNamed(context, '/phone_auth', arguments: args);
        setState(() => _loading = false);
        return; // Stop execution here
      }

      // Proceed with email registration
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: contactInput, password: password);
      final user = cred.user;
      debugPrint('✅ สร้างบัญชีสำเร็จ: ${user?.uid}'); // Debug log

      if (user != null) {
        // *** แก้ไข: บันทึก serviceType ลงใน contracts collection ทันทีหลังสร้าง user ***
        if (_serviceTypeNormalized != null) {
          await FirebaseFirestore.instance.collection('contracts').doc(user.uid).set({
            'serviceType': _serviceTypeNormalized,
            'status': 'pending_acceptance',
          });
        }

        if (user.emailVerified) {
          await _saveServiceRegistration();
          _navigateToContract();
          return;
        } else {
          try {
            await user.sendEmailVerification();
            debugPrint('📧 ส่งอีเมลยืนยันไปที่: ${user.email}');
          } catch (emailError) {
            debugPrint('❌ เกิดข้อผิดพลาดในการส่งอีเมล: $emailError');
            debugPrint('Rollback: กำลังลบบัญชีที่สร้างไม่สำเร็จ...');
            
            // Rollback: Delete the user if email sending fails.
            await user.delete();
            debugPrint('🗑️ ลบบัญชี ${user.uid} เรียบร้อยแล้ว');

            // Throw an exception to be caught by the outer catch block.
            throw Exception('การสร้างบัญชีล้มเหลวเนื่องจากไม่สามารถส่งอีเมลยืนยันได้ กรุณาลองใหม่อีกครั้ง');
          }
        }
      }
      
      // Wait a moment to ensure email is sent before signing out
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;
      
      // Navigate to the email verification screen instead of popping.
      // The user must verify their email before proceeding.
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/email-verification',
        (route) => false,
        arguments: {
          'serviceType': _serviceTypeNormalized,
          'nextRoute': 'contract',
        },
      );
    } on FirebaseAuthException catch (e) {
      String message = 'เกิดข้อผิดพลาด';
      bool showResendOption = false;
      
      switch (e.code) {
        case 'email-already-in-use':
          message = 'อีเมลนี้ถูกใช้แล้ว! อาจยังไม่ได้ยืนยันอีเมล\nลองเข้าสู่ระบบหรือใช้ "ส่งลิงก์รีเซ็ตอีเมล" ในหน้า Login';
          showResendOption = true;
          break;
        case 'weak-password':
          message = 'รหัสผ่านไม่ปลอดภัย กรุณาใช้รหัสผ่านที่แข็งแรงกว่า';
          break;
        case 'invalid-email':
          message = 'รูปแบบอีเมลไม่ถูกต้อง';
          break;
        case 'operation-not-allowed':
          message = 'การสมัครสมาชิกถูกปิดใช้งาน';
          break;
        default:
          message = e.message ?? 'เกิดข้อผิดพลาดในการสมัครสมาชิก';
      }
      
      debugPrint('❌ FirebaseAuthException: ${e.code} - $message'); // Debug log
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: showResendOption ? AppColors.accent : Colors.red,
            duration: Duration(seconds: showResendOption ? 8 : 5),
            action: showResendOption ? SnackBarAction(
              label: 'ไปหน้า Login',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pop(context);
              },
            ) : null,
          ),
        );
      }
    } catch (e) {
      // Catch other exceptions, like the one we threw for email failure.
      final message = e.toString().replaceFirst('Exception: ', '');
      debugPrint('❌ Exception: $message');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // แปลงประเภทบริการเป็นชื่อคอลเลกชั่น
  String _getCollectionName(String serviceType) {
    switch (serviceType) {
      case 'ตลาด':
        return 'market_registrations';
      case 'ร้านค้า':
        return 'shop_registrations';
      case 'ร้านอาหาร':
        return 'restaurant_registrations';
      case 'ร้านขายยา':
        return 'pharmacy_registrations';
      default:
        return 'shop_registrations';
    }
  }

  Future<void> _saveServiceRegistration() async {
    final serviceType = _serviceTypeNormalized;
    if (serviceType == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final collectionName = _getCollectionName(serviceType);
      
      // บันทึกลงคอลเลกชั่นตามประเภทบริการ
      await FirebaseFirestore.instance.collection(collectionName).doc(user.uid).set({
        'email': user.email ?? '',
        'phone': user.phoneNumber ?? '',
        'serviceType': serviceType,
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending_contract',
        'isProfileCompleted': false,
      }, SetOptions(merge: true));
      
      // บันทึกลง contracts collection
      await FirebaseFirestore.instance.collection('contracts').doc(user.uid).set({
        'serviceType': serviceType,
        'status': 'pending_acceptance',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('✅ บันทึกข้อมูลลง $collectionName และ contracts สำเร็จ');
    } catch (e) {
      debugPrint('❌ Firestore error: $e');
    }
  }

  Future<void> _handleSocialSignIn() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // ตรวจสอบว่ามีประเภทบริการหรือยัง
    if (_serviceTypeNormalized == null) {
      _promptServiceTypeSelection();
      return;
    }
    
    // บันทึกข้อมูลลงคอลเลกชั่นตามประเภทบริการทันที
    await _saveServiceRegistration();
    
    if (!mounted) return;
    
    // ส่งอีเมลยืนยัน (ถ้าเป็น Google/Facebook ที่มีอีเมล)
    if (user.email != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
        debugPrint('📧 ส่งอีเมลยืนยันไปที่: ${user.email}');
      } catch (e) {
        debugPrint('⚠️ ไม่สามารถส่งอีเมลยืนยัน: $e');
      }
    }
    
    // นำทางไปยืนยันอีเมลก่อนไปหน้าสัญญา
    if (user.email != null && !user.emailVerified) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/email-verification',
        (route) => false,
        arguments: {
          'serviceType': _serviceTypeNormalized,
          'nextRoute': 'contract',
        },
      );
    } else {
      // ถ้ายืนยันแล้วหรือไม่มีอีเมล → ไปหน้าสัญญาเลย
      _navigateToContract();
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSocialLoading = true;
      _socialLoadingKey = 'google';
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) {
          setState(() {
            _isSocialLoading = false;
            _socialLoadingKey = null;
          });
        }
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      setState(() { _isSocialLoading = false; _socialLoadingKey = null; });
      if (!mounted) return;
      await _handleSocialSignIn();

    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Google เข้าสู่ระบบล้มเหลว');
      if (mounted) {
        setState(() {
          _isSocialLoading = false;
          _socialLoadingKey = null;
        });
      }
    } catch (_) {
      _showSnack('เกิดข้อผิดพลาดขณะเข้าสู่ระบบด้วย Google');
      if (mounted) {
        setState(() {
          _isSocialLoading = false;
          _socialLoadingKey = null;
        });
      }
    }
  }

  Future<void> _signInWithFacebook() async {
    setState(() {
      _isSocialLoading = true;
      _socialLoadingKey = 'facebook';
    });
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status != LoginStatus.success) {
        if (mounted) {
          setState(() {
            _isSocialLoading = false;
            _socialLoadingKey = null;
          });
        }
        return;
      }
      final credential = FacebookAuthProvider.credential(result.accessToken!.token);
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      setState(() { _isSocialLoading = false; _socialLoadingKey = null; });
      if (!mounted) return;
      await _handleSocialSignIn();
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Facebook เข้าสู่ระบบล้มเหลว');
      if (mounted) {
        setState(() {
          _isSocialLoading = false;
          _socialLoadingKey = null;
        });
      }
    } catch (_) {
      _showSnack('เกิดข้อผิดพลาดขณะเข้าสู่ระบบด้วย Facebook');
      if (mounted) {
        setState(() {
          _isSocialLoading = false;
          _socialLoadingKey = null;
        });
      }
    }
  }

  Widget _socialButton({
    required VoidCallback? onPressed,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    required String buttonKey,
    String? assetSvg,
    IconData? icon,
  }) {
    final isLoading = _isSocialLoading && _socialLoadingKey == buttonKey;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_loading || _isSocialLoading) ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          side: BorderSide(color: Colors.grey.shade300),
        ),
        icon: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                ),
              )
            : (assetSvg != null
                ? SvgPicture.asset(assetSvg, height: 22, width: 22)
                : Icon(icon, size: 22, color: foregroundColor)),
        label: Text(label, style: TextStyle(fontSize: 16, color: foregroundColor, fontWeight: FontWeight.w500)),
      ),
    );
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('สมัครสมาชิก'), // Title is already set
  backgroundColor: AppColors.accent, // Match the app's theme
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            // Logo section
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha(77), // withOpacity(0.3)
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_add,
                  size: 50,
                  color: AppColors.accentDark,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Registration form card
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'สร้างบัญชีใหม่',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'กรอกข้อมูลเพื่อสมัครสมาชิก',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // Email field
                    Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                            color: Colors.grey.shade50,
                          ),
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.text, // Allow both email and phone
                            onChanged: (value) => _debouncer.run(() {
                              if (mounted) {
                                setState(() {
                                  final cleanValue = value.trim();
                                  if (cleanValue.isNotEmpty) {
                                    final firstChar = cleanValue[0];
                                    _isTypingPhoneNumber = (int.tryParse(firstChar) != null || firstChar == '+');

                                    if (_isTypingPhoneNumber && cleanValue.startsWith('+')) {
                                      _countryCodeSuggestions = _countryCodes.entries
                                          .where((entry) => entry.key.startsWith(cleanValue))
                                          .toList();
                                    } else {
                                      _countryCodeSuggestions = [];
                                    }
                                  } else {
                                    _isTypingPhoneNumber = false;
                                    _countryCodeSuggestions = [];
                                  }
                                });
                              }
                            }),
                            decoration: InputDecoration(
                              labelText: 'อีเมล หรือ เบอร์โทรศัพท์',
                              prefixIcon: const Icon(Icons.person_outline, color: AppColors.accentDark, size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              labelStyle: TextStyle(color: Colors.grey.shade600),
                              helperText: _isTypingPhoneNumber && _countryCodeSuggestions.isEmpty ? 'รูปแบบที่แนะนำ: +66812345678' : null,
                              helperStyle: TextStyle(color: Colors.green.shade700),
                            ),
                          ),
                        ),
                        if (_countryCodeSuggestions.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            constraints: const BoxConstraints(maxHeight: 150),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _countryCodeSuggestions.length,
                              itemBuilder: (context, index) {
                                final suggestion = _countryCodeSuggestions[index];
                                return ListTile(
                                  dense: true,
                                  title: Text('${suggestion.value} (${suggestion.key})'),
                                  onTap: () {
                                    _emailController.text = '${suggestion.key} ';
                                    _emailController.selection = TextSelection.fromPosition(TextPosition(offset: _emailController.text.length));
                                    setState(() => _countryCodeSuggestions = []);
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Password field
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        color: Colors.grey.shade50,
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'รหัสผ่าน',
                          prefixIcon: Icon(Icons.lock_outline, color: AppColors.accentDark, size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          labelStyle: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Confirm password field
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        color: Colors.grey.shade50,
                      ),
                      child: TextField(
                        controller: _confirmController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'ยืนยันรหัสผ่าน',
                          prefixIcon: Icon(Icons.lock_outline, color: AppColors.accentDark, size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          labelStyle: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _socialButton(
                      onPressed: _isSocialLoading ? null : _signInWithGoogle,
                      assetSvg: 'assets/icons/google_logo.svg',
                      label: 'เข้าสู่ระบบด้วย Google',
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      buttonKey: 'google',
                    ),
                    const SizedBox(height: 12),
                    _socialButton(
                      onPressed: _isSocialLoading ? null : _signInWithFacebook,
                      icon: Icons.facebook,
                      label: 'เข้าสู่ระบบด้วย Facebook',
                      backgroundColor: const Color(0xFF1877F2),
                      foregroundColor: Colors.white,
                      buttonKey: 'facebook',
                    ),
                    const SizedBox(height: 24),
                    
                    // Register button
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [AppColors.accent, AppColors.accentDarker],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _loading 
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(
                                color: Colors.white, 
                                strokeWidth: 2
                              )
                            )
                          : Icon(Icons.person_add, size: 20, color: Colors.white),
                        label: Text(
                          _loading ? 'กำลังสมัคร...' : 'สมัครสมาชิก',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // ลบการ์ดช่วยแก้ปัญหาอีเมลออกตามคำสั่งของผู้ใช้
            // (เดิมเป็น Card สีส้มพร้อมปุ่ม "ไปที่เครื่องมือแก้ปัญหา")
            // เว้นระยะห่างไว้เล็กน้อยเพื่อไม่ให้ UI อัดแน่น
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
