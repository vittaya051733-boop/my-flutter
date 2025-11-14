import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'map_picker_screen.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img; // เพิ่ม: สำหรับแปลงรูปภาพ
import 'firebase_options.dart';
import 'utils/app_colors.dart';

class ShopRegistrationScreen extends StatefulWidget {
  final String? serviceType;
  final DocumentSnapshot? shopData; // optional: existing shop doc to edit
  
  const ShopRegistrationScreen({super.key, this.serviceType, this.shopData});

  @override
  State<ShopRegistrationScreen> createState() => _ShopRegistrationScreenState();
}

class _ShopRegistrationScreenState extends State<ShopRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  final _shopNameController = TextEditingController();
  final _shopDescriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  // ข้อมูลสมุดบัญชีธนาคาร
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountOwnerController = TextEditingController();
  
  // รายชื่อธนาคารในประเทศไทยสำหรับตัวเลือก
  static const List<String> _thaiBanks = <String>[
    'ธนาคารกรุงเทพ (BBL)',
    'ธนาคารกสิกรไทย (KBank)',
    'ธนาคารไทยพาณิชย์ (SCB)',
    'ธนาคารกรุงไทย (KTB)',
    'ธนาคารกรุงศรีอยุธยา (BAY)',
    'ทีเอ็มบีธนชาต (TTB)',
    'ธนาคารยูโอบี (UOB)',
    'ธนาคารซีไอเอ็มบีไทย (CIMB)',
    'ธนาคารเกียรตินาคินภัทร (KKP)',
    'ธนาคารทิสโก้ (TISCO)',
    'ธนาคารแลนด์แอนด์เฮ้าส์ (LH Bank)',
    'ธนาคารออมสิน',
    'ธ.ก.ส. (ธนาคารเพื่อการเกษตรและสหกรณ์การเกษตร)',
    'อื่นๆ',
  ];
  
  File? _selectedImage;
  bool _isSaving = false;
  String? _existingShopImageUrl;
  
  File? _selectedBookBankImage;
  bool _isUploadingBookBank = false;
  String? _existingBookBankImageUrl;
  bool _isCheckingExisting = true;
  String? _resolvedServiceType;
  
  // เก็บผล OCR จากรูปสมุดบัญชี
  String _ocrText = '';

  // อ่านข้อความด้วย Google Cloud Vision API
  Future<String> _extractTextWithBestOCR(File imageFile) async {
    return await _extractTextWithGoogleVisionAPI(imageFile);
  } 

  // เรียก Google Cloud Vision API เพื่ออ่านข้อความจากรูป
  Future<String> _extractTextWithGoogleVisionAPI(File imageFile) async {
    // แก้ไข: อ่าน API Key จาก DefaultFirebaseOptions.currentPlatform.apiKey
    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    
    // เพิ่มการตรวจสอบว่าได้ตั้งค่า API Key มาจาก --dart-define หรือไม่
    if (apiKey.isEmpty) {
      throw Exception('Google Cloud Vision API Key ไม่ได้ถูกตั้งค่าใน firebase_options.dart');
    }

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final url = Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey');
    final requestBody = jsonEncode({
      'requests': [
        {
          'image': {'content': base64Image},
          'features': [
            // แก้ไข: เปลี่ยนเป็น DOCUMENT_TEXT_DETECTION เพื่อความแม่นยำในเอกสาร
            {'type': 'DOCUMENT_TEXT_DETECTION'}
          ]
        }
      ]
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final textAnnotations = jsonResponse['responses']?[0]?['textAnnotations'] as List?;
      if (textAnnotations == null || textAnnotations.isEmpty) {
        return '';
      }
      final fullText = textAnnotations[0]['description'] as String;
      return fullText;
    } else {
      // เพิ่มการแสดง error จาก API เพื่อให้ debug ง่ายขึ้น
      debugPrint('Google Vision API Error: ${response.body}');
      return '';
    }
  }
  
  // ข้อความแจ้งเตือนแบบ real-time
  String? _bankNameError;
  String? _accountNumberError;
  String? _accountOwnerError;
  
  // พิกัด GPS
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initRegistrationStatus());
    _prefillIfEditing();
  }

  void _prefillIfEditing() {
    if (widget.shopData == null || !widget.shopData!.exists) return;
    final data = widget.shopData!.data() as Map<String, dynamic>?;
    if (data == null) return;
    _shopNameController.text = (data['name'] ?? '').toString();
    _shopDescriptionController.text = (data['description'] ?? '').toString();
    _addressController.text = (data['address'] ?? '').toString();
    _phoneController.text = (data['phone'] ?? '').toString();
    _emailController.text = (data['email'] ?? '').toString();
    _bankNameController.text = (data['bankName'] ?? '').toString();
    _accountNumberController.text = (data['accountNumber'] ?? '').toString();
    _accountOwnerController.text = (data['accountOwner'] ?? '').toString();
    final loc = data['location'];
    if (loc is Map) {
      _latitude = (loc['latitude'] as num?)?.toDouble();
      _longitude = (loc['longitude'] as num?)?.toDouble();
    }
    _resolvedServiceType = (data['serviceType'] ?? widget.serviceType)?.toString();
    _isCheckingExisting = false; // ready to edit

    // keep existing media urls for preview/save
    _existingShopImageUrl = (data['shopImageUrl'] ?? '').toString();
    _existingBookBankImageUrl = (data['bookBankImageUrl'] ?? '').toString();
  }

  Future<void> _initRegistrationStatus() async {
    // ถ้าเป็นโหมดแก้ไข (มี shopData) ให้ข้ามการ redirect
    if (widget.shopData != null && widget.shopData!.exists) {
      if (mounted) setState(() => _isCheckingExisting = false);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isCheckingExisting = false);
      return;
    }

    String? serviceType = widget.serviceType;
    if (serviceType == null) {
      try {
        final snapshot = await FirebaseFirestore.instance.collection('contracts').doc(user.uid).get();
        serviceType = (snapshot.data()?['serviceType'] as String?)?.trim();
      } catch (e) {
        debugPrint('Failed to load serviceType: $e');
      }
    }

    if (mounted) {
      _resolvedServiceType = serviceType;
    }

    if (serviceType == null) {
      if (mounted) setState(() => _isCheckingExisting = false);
      return;
    }

    try {
      final collection = _collectionForService(serviceType);
      final doc = await FirebaseFirestore.instance.collection(collection).doc(user.uid).get();
      if (doc.exists) {
        final Map<String, dynamic>? data = doc.data();
        final alreadyComplete = _hasCompletedProfile(data);
        // ถ้าลงทะเบียนครบแล้ว และไม่ได้อยู่ในโหมดแก้ไข ให้กลับหน้า Home
        if (alreadyComplete && widget.shopData == null) {
          if (!mounted) return;
          _navigateHome();
          return;
        }
      }
    } catch (e) {
      debugPrint('Failed to check existing registration: $e');
    }

    if (mounted) setState(() => _isCheckingExisting = false);
  }

  Future<void> _loadUserEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      setState(() {
        _emailController.text = user.email!;
      });
    }
  }

  void _navigateHome() {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  String _collectionForService(String serviceType) {
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
        throw Exception('ประเภทบริการไม่ถูกต้อง: $serviceType');
    }
  }

  bool _hasCompletedProfile(Map<String, dynamic>? data) {
    if (data == null) return false;
    final completedFlag = data['isProfileCompleted'];
    if (completedFlag is bool && completedFlag) {
      return true;
    }

    final status = (data['status'] as String?)?.toLowerCase();
    if (status == null || status == 'pending_contract') {
      return false;
    }

    final hasCoreDetails =
        (data['name']?.toString().isNotEmpty ?? false) &&
        (data['address']?.toString().isNotEmpty ?? false) &&
        (data['shopImageUrl']?.toString().isNotEmpty ?? false) &&
        (data['bankName']?.toString().isNotEmpty ?? false);

    return hasCoreDetails;
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopDescriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountOwnerController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // ลบโค้ดขอ permission ออก (ใช้ ImagePicker ตามปกติ)
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _pickBookBankImage() async {
    // ลบโค้ดขอ permission ออก (ใช้ ImagePicker ตามปกติ)
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      maxHeight: 1400,
      imageQuality: 90,
    );
    if (image != null) {
      setState(() {
        _selectedBookBankImage = File(image.path);
        _isUploadingBookBank = true;
      });
      try {
        final ocrText = await _extractTextWithBestOCR(_selectedBookBankImage!);
        if (ocrText.trim().isEmpty || ocrText.length < 20) {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ ไม่สามารถอ่านข้อมูลจากรูปสมุดบัญชี หรือภาพเบลอ กรุณาเลือกรูปใหม่'), backgroundColor: Colors.red)
            );
            setState(() {
              _selectedBookBankImage = null;
              _ocrText = '';
              _isUploadingBookBank = false;
            });
          }
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ รูปภาพสมุดบัญชีผ่านการตรวจสอบความชัดเจน'), backgroundColor: Colors.green)
          );
        }
      } catch (e) {
        // ... โค้ดส่วนที่เหลือไม่มีการเปลี่ยนแปลง ...
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ เกิดข้อผิดพลาดในการตรวจสอบรูปภาพ'), backgroundColor: Colors.red)
          );
          setState(() {
            _selectedBookBankImage = null;
            _ocrText = '';
            _isUploadingBookBank = false;
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUploadingBookBank = false;
          });
        }
      }

    } // ปิด if (image != null)
  } // ปิด _pickBookBankImage
  void _validateFieldAgainstOCR(String fieldName) {
    if (_ocrText.isEmpty || _selectedBookBankImage == null) return;

    final lowerOcr = _ocrText.toLowerCase();

    setState(() {
      if (fieldName == 'bank' || fieldName == 'all') {
        final raw = _bankNameController.text.trim();
        if (raw.isEmpty) {
          _bankNameError = null;
        } else {
          final cleaned = raw
              .toLowerCase()
              .replaceAll(RegExp(r'\([^)]*\)'), '')
              .replaceAll('ธนาคาร', '')
              .replaceAll('ธ.ก.ส.', 'ธกส')
              .replaceAll(RegExp(r'[^\u0E00-\u0E7Fa-z0-9\s]'), '')
              .trim();
          final matchesBank = cleaned
              .split(RegExp(r'\s+'))
              .where((segment) => segment.length >= 3)
              .any((segment) => lowerOcr.contains(segment));
          _bankNameError = matchesBank ? null : 'ชื่อธนาคารไม่ตรงกับรูปสมุดบัญชี';
        }
      }

      if (fieldName == 'account' || fieldName == 'all') {
        final digits = _accountNumberController.text.replaceAll(RegExp(r'[\s\-\.]'), '');
        if (digits.length >= 8) {
          final ocrDigits = _ocrText.replaceAll(RegExp(r'\D'), '');
          final minMatch = (digits.length * 0.5).round().clamp(4, digits.length);
          final hasExact = ocrDigits.contains(digits);
          final hasPartial = hasExact ||
              List.generate(digits.length - minMatch + 1, (i) => digits.substring(i, i + minMatch))
                  .any(ocrDigits.contains) ||
              (digits.length >= 10 &&
                  List.generate(digits.length - 3, (i) => digits.substring(i, i + 4))
                      .any(ocrDigits.contains));
          _accountNumberError =
              hasPartial ? null : 'หมายเลขบัญชีไม่ตรงกับรูปสมุดบัญชี';
        } else {
          _accountNumberError = null;
        }
      }

      if (fieldName == 'owner' || fieldName == 'all') {
        final owner = _accountOwnerController.text.trim().toLowerCase();
        if (owner.isEmpty) {
          _accountOwnerError = null;
        } else {
          final tokens = owner.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
          final required = (tokens.length * 0.4).ceil();
          int matches = 0;

          for (final token in tokens) {
            if (['นาย', 'นาง', 'นางสาว', 'mr', 'mrs', 'miss'].contains(token)) {
              matches++;
              continue;
            }
            if (token.length >= 2 && lowerOcr.contains(token)) {
              matches++;
            }
          }

          _accountOwnerError =
              matches >= required ? null : 'ชื่อเจ้าของบัญชีไม่ตรงกับรูปสมุดบัญชี';
        }
      }
    });
  }

  Future<void> _pickLocationFromMap() async {
    // ก่อนเปิดแผนที่ ให้ตรวจสอบชื่อเจ้าของบัญชีที่กรอกไปแล้ว
    if (_accountOwnerController.text.isNotEmpty && _ocrText.isNotEmpty) {
      _validateFieldAgainstOCR('owner');
    }
    
    final result = await Navigator.of(context).push<Map<String, double>>(
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latitude = result['latitude'];
        _longitude = result['longitude'];
      });
      
      _showSnackBar('✅ ปักหมุดตำแหน่งสำเร็จ!', Colors.green);
    }
  }

  Future<void> _saveShopRegistration() async {
    // เปิดโหมดแสดงข้อผิดพลาดในฟอร์ม
    setState(() {
      _autoValidateMode = AutovalidateMode.always;
    });

    // 1. ตรวจสอบ FormFields ทั้งหมดด้วย validator
    final formIsValid = _formKey.currentState?.validate() ?? false;

    // 2. ตรวจสอบ OCR-based errors อีกครั้ง (เพื่อให้แน่ใจว่าอัปเดตล่าสุด)
    _validateFieldAgainstOCR('all');

    // 3. รวบรวมข้อผิดพลาดทั้งหมด (จาก FormFields และ OCR-based)
    final allErrors = _collectAllValidationErrors();
    if (!formIsValid || allErrors.isNotEmpty) {
      _showValidationDialog(allErrors);
      return; // หยุดการทำงานถ้ามีข้อผิดพลาด
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('ไม่พบข้อมูลผู้ใช้');
      final serviceType = _resolvedServiceType ?? widget.serviceType;
      if (serviceType == null) throw Exception('ประเภทบริการไม่ถูกต้อง');

      // เตรียมรูปภาพ: ถ้าไม่อัปโหลดใหม่ ให้ใช้ของเดิม
      String? shopImageUrl = _existingShopImageUrl;
      String? bookBankImageUrl = _existingBookBankImageUrl;

      // อัปโหลดไฟล์ใหม่ถ้ามี และลบไฟล์เก่าใน Storage
      if (_selectedImage != null) {
        final newUrl = await _uploadImage();
        if (newUrl == null) throw Exception('อัปโหลดรูปร้านค้าล้มเหลว');
        final oldUrl = _existingShopImageUrl;
        shopImageUrl = newUrl;
        if (oldUrl != null && oldUrl.isNotEmpty && oldUrl != newUrl) {
          _deleteOldStorageFile(oldUrl);
        }
      }

      if (_selectedBookBankImage != null) {
        final newUrl = await _uploadBookBankImage();
        if (newUrl == null) throw Exception('อัปโหลดรูปสมุดบัญชีล้มเหลว');
        final oldUrl = _existingBookBankImageUrl;
        bookBankImageUrl = newUrl;
        if (oldUrl != null && oldUrl.isNotEmpty && oldUrl != newUrl) {
          _deleteOldStorageFile(oldUrl);
        }
      }

      final collection = _collectionForService(serviceType);

      // นับจำนวนร้านในประเภทนี้เพื่อกำหนดลำดับ
      final querySnapshot = await FirebaseFirestore.instance
          .collection(collection)
          .get();
      final orderNumber = querySnapshot.docs.length + 1;

      // บันทึกข้อมูลร้านค้าลง Firestore (แต่ละประเภทเป็น Collection แยก)
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(user.uid)
          .set({
        'name': _shopNameController.text.trim(),
        'serviceType': serviceType, // ใช้ field นี้เป็นหลัก
        'rating': 0.0, // เริ่มต้นที่ 0 รอรีวิว
        'location': {
          'latitude': _latitude ?? 0.0,
          'longitude': _longitude ?? 0.0,
        },
        'ownerId': user.uid,
        'order': orderNumber, // ลำดับที่ของร้านในประเภทนี้
        'description': _shopDescriptionController.text.trim(), 
        'address': _addressController.text.trim(), // ใช้ที่อยู่ที่กรอกเอง
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'shopImageUrl': shopImageUrl,
        'bookBankImageUrl': bookBankImageUrl,
        'bankName': _bankNameController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'accountOwner': _accountOwnerController.text.trim(),
        'status': 'pending', // รอการอนุมัติ
        'isProfileCompleted': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _showSnackBar('✅ ลงทะเบียนร้านค้าสำเร็จ!', Colors.green);

      await Future.delayed(const Duration(seconds: 1));

      _navigateHome();
    } catch (e) {
      _showSnackBar('❌ เกิดข้อผิดพลาด: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteOldStorageFile(String url) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('Skip delete old file: $e');
    }
  }

  // ตรวจสอบอีเมลรูปแบบทั่วไป
  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(email);
  }

  // ตรวจสอบเบอร์โทรแบบไทย: รองรับ 0XXXXXXXXX (10 หลัก) หรือ +66XXXXXXXXX/66XXXXXXXXX (11 หลัก)
  bool _isValidThaiPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) {
      return digits.length == 10;
    }
    if (digits.startsWith('66')) {
      return digits.length == 11; // 66 + 9 หลักที่เหลือ
    }
    return false;
  }

  // รวมตรวจสอบทุกช่องที่จำเป็น และคืนรายการข้อความผิดพลาด
  List<String> _validateFields() {
    final errors = <String>[];

    final name = _shopNameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || name.length < 2) {
      errors.add('• ชื่อร้านค้า: กรุณากรอกอย่างน้อย 2 ตัวอักษร');
    }
    if (_latitude == null || _longitude == null) {
      errors.add('• ที่อยู่: กรุณาปักหมุดตำแหน่งร้านค้าบนแผนที่');
    }
    if (phone.isEmpty || !_isValidThaiPhone(phone)) {
      errors.add('• เบอร์โทรศัพท์: รูปแบบไม่ถูกต้อง (เช่น 0812345678 หรือ +66812345678)');
    }
    if (email.isEmpty || !_isValidEmail(email)) {
      errors.add('• อีเมล: รูปแบบไม่ถูกต้อง');
    }

    // หมายเหตุ: คำอธิบายร้าน ไม่บังคับ ตามที่ผู้ใช้ระบุ
    // สมุดบัญชีธนาคาร: อนุญาตให้เว้นได้ (ไม่บังคับ)

    return errors;
  }

  // รวบรวมข้อผิดพลาดทั้งหมดจากทั้ง FormFields และ OCR-based errors
  List<String> _collectAllValidationErrors() {
    final errors = _validateFields(); // รวบรวมข้อผิดพลาดพื้นฐาน

    // เพิ่มข้อผิดพลาดจาก OCR-based validation
    if (_bankNameError != null) errors.add('• ธนาคาร: $_bankNameError');
    if (_accountNumberError != null) errors.add('• หมายเลขบัญชี: $_accountNumberError');
    if (_accountOwnerError != null) errors.add('• ชื่อเจ้าของบัญชี: $_accountOwnerError');

    // ตรวจสอบว่ามีรูปสมุดบัญชีหรือไม่ ถ้ามีแต่ข้อมูลไม่ครบ ก็ควรแจ้ง
    // (แต่ตอนนี้ OCR validation จะจัดการเรื่องนี้อยู่แล้ว)
    return errors;
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showValidationDialog(List<String> errors) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('กรุณากรอกข้อมูลให้ครบถ้วน'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: errors.map((e) => Text(e)).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ตกลง'),
            ),
          ],
        );
      },
    );
  }

  // เพิ่มฟังก์ชัน _uploadImage ที่หายไป เพื่อให้อัปโหลดรูปร้านค้าได้
Future<String?> _uploadImage() async {
    if (_selectedImage == null) {
      debugPrint('❌ _selectedImage is null');
      return null;
    }
    if (!await _selectedImage!.exists()) {
      debugPrint('❌ _selectedImage file does not exist: ${_selectedImage!.path}');
      return null;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('ไม่พบข้อมูลผู้ใช้');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'shop_images/${user.uid}_$timestamp.webp';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);

      final bytes = await _selectedImage!.readAsBytes();
      debugPrint('✅ Read shop image bytes: ${bytes.length}');
      final image = img.decodeImage(bytes);
      if (image == null) {
        debugPrint('❌ Could not decode shop image.');
        throw Exception('ไม่สามารถอ่านข้อมูลรูปภาพร้านค้าได้ (ไฟล์อาจเสียหาย)');
      }
      final webpBytes = img.encodePng(image);

      final uploadTask = await storageRef.putData(
        Uint8List.fromList(webpBytes),
        SettableMetadata(contentType: 'image/png'),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('✅ Uploaded shop image: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ อัปโหลดรูปร้านค้าล้มเหลว: $e');
      throw Exception('อัปโหลดรูปร้านค้าล้มเหลว: $e');
    }
}

// เพิ่มฟังก์ชัน _uploadBookBankImage ที่หายไป เพื่อให้อัปโหลดรูปสมุดบัญชีได้
Future<String?> _uploadBookBankImage() async {
  if (_selectedBookBankImage == null) return null;
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ไม่พบข้อมูลผู้ใช้');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'book_bank_images/${user.uid}_$timestamp.webp';
    final storageRef = FirebaseStorage.instance.ref().child(fileName);

    final bytes = await _selectedBookBankImage!.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('ไม่สามารถอ่านรูปภาพได้');
    final pngBytes = img.encodePng(image);

    final uploadTask = await storageRef.putData(
      Uint8List.fromList(pngBytes),
      SettableMetadata(contentType: 'image/png'),
    );
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    return downloadUrl;
  } catch (e) {
    throw Exception('อัปโหลดรูปสมุดบัญชีล้มเหลว: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('ลงทะเบียนร้านค้า'),
  backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed('/contract');
          },
        ),
      ),
      body: _isCheckingExisting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                autovalidateMode: _autoValidateMode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // หัวข้อ
                    Text(
                      'กรอกข้อมูลร้านค้า',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ชื่อร้านค้า
                    TextFormField(
                      controller: _shopNameController,
                      decoration: InputDecoration(
                        labelText: 'ชื่อร้านค้า *',
                        hintText: 'เช่น ร้านอาหารสมชาย',
                        prefixIcon: const Icon(Icons.store),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'กรุณากรอกชื่อร้านค้า';
                        if (v.length < 2) return 'กรุณากรอกชื่อร้านค้าอย่างน้อย 2 ตัวอักษร';
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),

                    // คำอธิบายร้านค้า (ย้ายมาใต้ชื่อร้าน และให้สูงเท่าช่องทั่วไป)
                    TextFormField(
                      controller: _shopDescriptionController,
                      maxLines: 1,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'คำอธิบายร้านค้า',
                        hintText: 'เช่น ร้านอาหารไทยพื้นบ้าน รสชาติอร่อย',
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // รูปภาพร้านค้า
                    const Text(
                      'รูปภาพร้านค้า',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    GestureDetector(
                      onTap: _isSaving ? null : _pickImage,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: _isSaving
                            ? const Center(
                                child: CircularProgressIndicator(),
                              )
                              : _selectedImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      _selectedImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                  : (_existingShopImageUrl != null && _existingShopImageUrl!.isNotEmpty)
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            _existingShopImageUrl!,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate,
                                        size: 64,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'คลิกเพื่อเลือกรูปภาพ',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // สมุดบัญชีธนาคาร
                    const Text(
                      'สมุดบัญชีธนาคาร',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 12),

                    GestureDetector(
                      onTap: _isUploadingBookBank ? null : _pickBookBankImage,
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: _isUploadingBookBank
                            ? const Center(child: CircularProgressIndicator())
                            : _selectedBookBankImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      _selectedBookBankImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : (_existingBookBankImageUrl != null && _existingBookBankImageUrl!.isNotEmpty)
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          _existingBookBankImageUrl!,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.credit_card,
                                        size: 56,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'คลิกเพื่ออัปโหลดรูปหน้าสมุดบัญชี',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'ควรให้เห็นชื่อบัญชีและเลขบัญชีชัดเจน',
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      )
                                    ],
                                  ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ชื่อธนาคาร (ตัวเลือกแบบ Dropdown)
                    DropdownButtonFormField<String>(
                      isExpanded: true, // To prevent overflow
                      initialValue: _thaiBanks.contains(_bankNameController.text) ? _bankNameController.text : null,
                      items: _thaiBanks
                          .map((bank) => DropdownMenuItem<String>(
                                value: bank,
                                child: Text(
                                  bank,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      decoration: InputDecoration(
                        labelText: 'ชื่อธนาคาร *',
                        hintText: 'เลือกชื่อธนาคาร',
                        prefixIcon: const Icon(Icons.account_balance),
                        errorText: _bankNameError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _bankNameController.text = value ?? '';
                        });
                        _validateFieldAgainstOCR('bank');
                      },
                      validator: (value) {
                        // แก้ไข: ตรวจสอบจาก controller โดยตรง
                        if (_bankNameController.text.trim().isEmpty) {
                          // ถ้าผู้ใช้เลือก "อื่นๆ" แต่ไม่ได้กรอกช่องอื่น ก็อาจต้อง validate เพิ่ม
                          // แต่ในที่นี้ ตรวจสอบแค่ว่ามีการเลือกหรือไม่
                          return 'กรุณาเลือกชื่อธนาคาร';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // หมายเลขบัญชี
                    TextFormField(
                      controller: _accountNumberController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'หมายเลขบัญชี *',
                        hintText: 'เช่น 1643440349',
                        helperText: 'ใส่ได้เฉพาะตัวเลขเท่านั้น',
                        helperStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        prefixIcon: const Icon(Icons.credit_card),
                        errorText: _accountNumberError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onTap: () {
                        if (_bankNameController.text.isNotEmpty && _ocrText.isNotEmpty) {
                          _validateFieldAgainstOCR('bank');
                        }
                      },
                      onChanged: (value) {
                        _validateFieldAgainstOCR('account');
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'กรุณากรอกหมายเลขบัญชี';
                        }
                        if (value.trim().length < 10) {
                          return 'หมายเลขบัญชีต้องมีอย่างน้อย 10 หลัก';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // ชื่อเจ้าของบัญชี
                    TextFormField(
                      controller: _accountOwnerController,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[ก-๙a-zA-Z\s]'))],
                      decoration: InputDecoration(
                        labelText: 'ชื่อเจ้าของบัญชี *',
                        hintText: 'เช่น นาย สมชาย ใจดี',
                        helperText: 'ใส่ได้เฉพาะตัวอักษรไทย/อังกฤษ',
                        prefixIcon: const Icon(Icons.person),
                        errorText: _accountOwnerError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onTap: () {
                        if (_accountNumberController.text.isNotEmpty && _ocrText.isNotEmpty) {
                          _validateFieldAgainstOCR('account');
                        }
                      },
                      onChanged: (value) {
                        _validateFieldAgainstOCR('owner');
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'กรุณากรอกชื่อเจ้าของบัญชี';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // ที่อยู่ร้านค้า - ปักหมุดเท่านั้น
                    const Text(
                      'ที่อยู่ร้านค้า *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // ปุ่มปักหมุด
                    InkWell(
                      onTap: _pickLocationFromMap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _latitude != null && _longitude != null
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _latitude != null && _longitude != null
                                ? Colors.green.shade300
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                color: _latitude != null && _longitude != null
                  ? Colors.green.shade100
                  : AppColors.accentLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.location_pin,
                                color: _latitude != null && _longitude != null
                                    ? Colors.green.shade700
                                    : AppColors.accent,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _latitude != null && _longitude != null
                                        ? 'ปักหมุดแล้ว'
                                        : 'ปักหมุดตำแหน่งร้านค้า',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _latitude != null && _longitude != null
                                          ? Colors.green.shade700
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _latitude != null && _longitude != null
                                        ? 'Lat: ${_latitude!.toStringAsFixed(6)}\nLng: ${_longitude!.toStringAsFixed(6)}'
                                        : 'คลิกเพื่อเปิดแผนที่และเลือกตำแหน่ง',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _latitude != null && _longitude != null
                                          ? Colors.green.shade600
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    // เบอร์โทรศัพท์
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'เบอร์โทรศัพท์ *',
                        hintText: 'เช่น 081-234-5678',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'กรุณากรอกเบอร์โทรศัพท์';
                        if (!_isValidThaiPhone(v)) {
                          return 'กรุณากรอกเบอร์โทรศัพท์ให้ถูกต้อง (เช่น 0812345678 หรือ +66812345678)';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),

                    // อีเมล
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'อีเมล *',
                        hintText: 'example@email.com',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'กรุณากรอกอีเมล';
                        if (!_isValidEmail(v)) return 'รูปแบบอีเมลไม่ถูกต้อง';
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 32),

                    // ปุ่มบันทึก
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_isSaving || _isUploadingBookBank)
                            ? null
                            : _saveShopRegistration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'บันทึกข้อมูล',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    // ข้อความเพิ่มเติม
                    Center(
                      child: Text(
                        '* หมายถึงข้อมูลที่จำเป็นต้องกรอก',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
