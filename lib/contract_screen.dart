import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data'; // เพิ่มบรรทัดนี้
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:signature/signature.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import './shop_registration_screen.dart';
import 'package:file_saver/file_saver.dart'; // เพิ่ม
import 'package:image/image.dart' as img; // เพิ่มบรรทัดนี้
import 'register_shop_next.dart'; // เพิ่ม import สำหรับ RegisterShopNextScreen ด้านบนไฟล์
import 'utils/app_colors.dart';

class ContractScreen extends StatefulWidget {
  final String? serviceType;

  const ContractScreen({super.key, this.serviceType});

  @override
  State<ContractScreen> createState() => _ContractScreenState();
}

class _ContractScreenState extends State<ContractScreen> {
  static const List<String> _thaiMonthNames = <String>[
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  String _buildDefaultContractTemplate() {
    return '''
สัญญาฉบับนี้ จัดทำขึ้น ณ วันที่ $_currentDay เดือน $_currentMonthName พ.ศ. $_currentYear
ระหว่าง
บริษัท Van Market จำกัด ซึ่งต่อไปในสัญญานี้เรียกว่า “บริษัท”
โดยมี นายวิทยา ทนหงษา ผู้มีอำนาจลงนาม เป็นผู้แทนฝ่ายบริษัทกับร้านค้า
ซึ่งต่อไปในสัญญานี้เรียกว่า “ร้านค้า”

หมวดที่ 1 : วัตถุประสงค์ของสัญญา

บริษัทตกลงให้ร้านค้าร่วมจำหน่ายอาหารหรือสินค้าอาหารผ่านแพลตฟอร์ม Van Market

ร้านค้าตกลงให้บริการจำหน่ายอาหารตามเงื่อนไขและมาตรฐานที่บริษัทกำหนด เพื่อให้เกิดความปลอดภัยและความพึงพอใจสูงสุดของลูกค้า

หมวดที่ 2 : การรับรองคุณภาพอาหาร

ร้านค้ารับรองว่าอาหารที่จำหน่ายผ่านแพลตฟอร์มปลอดภัย ปรุงจากวัตถุดิบที่มีคุณภาพ ไม่หมดอายุ และผ่านมาตรฐานสุขาภิบาล

ร้านค้าต้องไม่ใช้สารเคมีหรือวัตถุเจือปนต้องห้าม เช่น ฟอร์มาลิน สารบอแรกซ์ หรือสารกันเสียที่ไม่ได้รับอนุญาตจากสำนักงานคณะกรรมการอาหารและยา (อย.)

ร้านค้าต้องจัดเก็บวัตถุดิบและอุปกรณ์ในสภาพที่ถูกสุขลักษณะ และพร้อมให้บริษัทตรวจสอบได้ตามความจำเป็น

หมวดที่ 3 : ความรับผิดชอบเมื่อเกิดความเสียหาย

หากตรวจสอบพบว่าอาหารที่ร้านค้าผลิตหรือจำหน่ายมีสารเคมี หรือไม่ปลอดภัยต่อผู้บริโภค
→ ร้านค้าต้องรับผิดชอบ ค่าเสียหายทั้งหมด 100% ต่อผู้บริโภคที่ได้รับผลกระทบ รวมถึงค่ารักษาพยาบาล ค่าชดเชย และค่าใช้จ่ายอื่น ๆ ที่เกิดขึ้น

ร้านค้าต้องชดใช้ค่าเสียหายแก่ลูกค้าในกรณีที่มีอาการแพ้ เจ็บป่วย หรือได้รับอันตรายจากอาหารของร้าน
บริษัทมีสิทธิ์ระงับบัญชีร้านค้าชั่วคราว หรือยกเลิกบัญชีถาวร หากมีการร้องเรียนซ้ำซ้อนเกิน 3 ครั้ง หรือพิสูจน์ได้ว่าอาหารไม่ปลอดภัย

บริษัทมีสิทธิ์เรียกเก็บค่าใช้จ่ายจริงจากร้านค้า เช่น ค่าชดเชยลูกค้า ค่าตรวจวิเคราะห์ในห้องแล็บ และค่าใช้จ่ายทางกฎหมาย

หมวดที่ 4 : การร้องเรียนของลูกค้า

เมื่อลูกค้าร้องเรียน บริษัทจะตรวจสอบหลักฐาน เช่น ภาพถ่าย ใบเสร็จ หรือรายงานแพทย์ (ถ้ามี)

หากตรวจสอบแล้วพบว่าข้อร้องเรียนเป็นจริง ร้านค้าต้องคืนเงินเต็มจำนวนให้ลูกค้า และชดใช้ค่าเสียหายอื่น ๆ ตามที่ตกลง

ร้านค้าต้องให้ความร่วมมืออย่างเต็มที่ในการสอบสวนข้อร้องเรียนโดยไม่ปกปิดข้อมูล

หมวดที่ 5 : การตรวจสอบและควบคุมคุณภาพ

บริษัทมีสิทธิ์สุ่มตรวจอาหาร วัตถุดิบ หรือกระบวนการผลิตของร้านค้า เพื่อรักษามาตรฐานความปลอดภัย

หากพบความผิดปกติ บริษัทมีสิทธิ์สั่งระงับการขายชั่วคราว จนกว่าร้านค้าจะปรับปรุงให้ได้มาตรฐาน

ร้านค้าต้องเข้ารับการอบรมเรื่องสุขาภิบาลอาหารหรือมาตรฐานคุณภาพที่บริษัทจัดให้ตามความเหมาะสม

หมวดที่ 6 : การยกเลิกสัญญา

บริษัทมีสิทธิ์ยกเลิกสัญญาทันที โดยไม่ต้องแจ้งล่วงหน้า หากร้านค้า

พบว่ามีการใช้สารเคมีหรือวัตถุเจือปนต้องห้าม

ปลอมแปลงข้อมูลวัตถุดิบ ใบอนุญาต หรือแหล่งที่มาของอาหาร

ไม่ให้ความร่วมมือในการตรวจสอบ หรือปกปิดข้อมูลที่เกี่ยวข้องกับความปลอดภัยของอาหาร

การยกเลิกสัญญาไม่กระทบต่อสิทธิ์ของบริษัทในการเรียกร้องค่าเสียหายย้อนหลัง

หมวดที่ 7 : ข้อตกลงทั่วไป

ร้านค้าต้องไม่ใช้ชื่อ โลโก้ หรือข้อมูลของบริษัทเพื่อผลประโยชน์อื่นใดโดยไม่ได้รับอนุญาต

สัญญาฉบับนี้มีอายุ ______ ปี นับตั้งแต่วันที่ลงนาม และต่ออายุโดยอัตโนมัติ เว้นแต่ฝ่ายใดฝ่ายหนึ่งจะแจ้งยกเลิกเป็นลายลักษณ์อักษร

หากมีข้อพิพาทเกิดขึ้น ทั้งสองฝ่ายตกลงใช้กฎหมายไทยเป็นหลัก และให้อยู่ในเขตอำนาจของศาลจังหวัดที่บริษัทตั้งอยู่

ลงชื่อ ___________________________
(นายวิทยา ทนหงษา)
ผู้มีอำนาจลงนามฝ่ายบริษัท
วันที่ $_currentDay/$_currentMonthNumber/$_currentYear
''';

  }

  bool _accepted = false;
  bool _isUploading = false;
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2.5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );

  File? _selectedIdCardFrontImage;
  File? _selectedIdCardBackImage;
  bool _isProcessingIdCardFront = false;
  bool _isProcessingIdCardBack = false;
  String? _resolvedServiceType;

  String _currentDay = '';
  String _currentMonthNumber = '';
  String _currentYear = '';
  String _currentMonthName = '';

  // เพิ่มฟังก์ชัน _setCurrentDate
  void _setCurrentDate() {
    final now = DateTime.now();
    _currentDay = now.day.toString();
    _currentMonthNumber = now.month.toString().padLeft(2, '0');
    _currentYear = (now.year + 543).toString();
    _currentMonthName = _thaiMonthNames[now.month - 1];
  }

  bool _isLoading = true;
  String? _error;
  final TextEditingController _contractTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _resolvedServiceType = widget.serviceType;
    _setCurrentDate();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureContractState());
  }

  Future<void> _ensureContractState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _fetchContractText();
      return;
    }
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('contracts').doc(user.uid).get();
      final data = snapshot.data();
      final storedServiceType = data?['serviceType'] as String?;
      final status = data?['status'] as String?;
      if (mounted && storedServiceType != null && storedServiceType != _resolvedServiceType) {
        setState(() => _resolvedServiceType = storedServiceType);
      }
      final serviceType = _resolvedServiceType ?? storedServiceType;
      if (status == 'accepted') {
        if (!mounted) return;
        if (serviceType == null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const RegisterShopNextScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => ShopRegistrationScreen(serviceType: serviceType)),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('Failed to check existing contract status: $e');
    }
    _fetchContractText();
  }

  Future<void> _fetchContractText() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

  var template = _buildDefaultContractTemplate();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('contracts').doc(user.uid).get();
        final stored = doc.data()?['contractText'] as String?;
        if (stored != null && stored.trim().isNotEmpty) {
          template = stored;
        }
      }
    } catch (e) {
      setState(() => _error = 'ไม่สามารถโหลดสัญญา: $e');
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _contractTextController.text = template;
    });
  }
  Future<void> _captureAndUploadContract() async {
    if (!_accepted) {
  _showSnackBar('กรุณายอมรับข้อกำหนดก่อน', AppColors.accent);
      return;
    }
    if (_signatureController.isEmpty) {
  _showSnackBar('กรุณาลงลายมือชื่อของเจ้าของร้านค้า', AppColors.accent);
      return;
    }
    if (_selectedIdCardFrontImage == null) {
  _showSnackBar('กรุณาอัปโหลดรูปบัตรประชาชน (ด้านหน้า)', AppColors.accent);
      return;
    }
    if (_selectedIdCardBackImage == null) {
  _showSnackBar('กรุณาอัปโหลดรูปบัตรประชาชน (ด้านหลัง)', AppColors.accent);
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('กรุณาเข้าสู่ระบบก่อน');
      await user.reload();
      final freshUser = FirebaseAuth.instance.currentUser;
      if (freshUser == null) throw Exception('Session หมดอายุ กรุณาเข้าสู่ระบบใหม่');
      if (!mounted) return;
      if (mounted) {
        _showSnackBar('กำลังอัปโหลดรูปบัตรประชาชน...', Colors.blue);
      }
      String? signatureUrl;
      
      // อัปโหลดรูปบัตรประชาชน (ไม่ต้องเก็บ URL)
      if (_selectedIdCardFrontImage != null) {
        await _uploadImageOnly(_selectedIdCardFrontImage!, 'id_card_images');
      }
      if (_selectedIdCardBackImage != null) {
        await _uploadImageOnly(_selectedIdCardBackImage!, 'id_card_images');
      }

      // อัปโหลดลายเซ็นเป็น WebP
      if (!mounted) return;
      if (mounted) {
        _showSnackBar('กำลังอัปโหลดลายเซ็น (WebP)...', Colors.blue);
      }
      final signatureBytes = await _signatureController.toPngBytes();
      if (signatureBytes != null) {
        final signatureFile = File('${Directory.systemTemp.path}/signature_${freshUser.uid}.png');
        await signatureFile.writeAsBytes(signatureBytes);
        signatureUrl = await _uploadImageAsWebp(signatureFile, 'signatures');
      }

      // อัปโหลดข้อความสัญญาเป็น .txt
      if (!mounted) return;
      if (mounted) {
        _showSnackBar('กำลังบันทึกไฟล์สัญญา (.txt)...', Colors.blue);
      }
      final contractText = '${_contractTextController.text}\n\nลายมือชื่อ (ฝั่งร้านค้า): [ลงลายมือชื่อในระบบ]\nวันที่ $_currentDay/$_currentMonthNumber/$_currentYear';
      final contractBytes = utf8.encode(contractText);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final contractFileName =
          'contracts/${freshUser.uid}_${_resolvedServiceType ?? 'unknown'}_$timestamp.txt';
      final contractStorageRef = FirebaseStorage.instance.ref().child(contractFileName);
      final contractUploadTask = contractStorageRef.putData(
        Uint8List.fromList(contractBytes),
        SettableMetadata(
          contentType: 'text/plain',
          customMetadata: {
            'userId': freshUser.uid,
            'serviceType': widget.serviceType ?? 'unknown',
            'timestamp': timestamp.toString(),
          },
        ),
      );
      await contractUploadTask.timeout(const Duration(seconds: 60));
      final contractDownloadUrl = await contractStorageRef.getDownloadURL();

      // Update Firestore: บันทึก URL ของแต่ละไฟล์แยกกัน
      await FirebaseFirestore.instance.collection('contracts').doc(freshUser.uid).set({
        'serviceType': _resolvedServiceType,
        'status': 'accepted',
        'contractTextUrl': contractDownloadUrl,
        'signatureImageUrl': signatureUrl,
        'contractText': _contractTextController.text,
        'acceptedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        _showSnackBar('✅ ยอมรับสัญญาและบันทึกข้อมูลสำเร็จ!', Colors.green);
      }

      // บันทึกไฟล์ลงเครื่องผู้ใช้ (ข้อความสัญญา)
      try {
        await FileSaver.instance.saveFile(
          name: 'contract_${freshUser.uid}_$timestamp',
          bytes: contractBytes,
          ext: 'txt');
        if (mounted) {
          _showSnackBar('📄 สัญญาถูกบันทึกในโฟลเดอร์ Downloads แล้ว', Colors.blue);
        }
      } catch (e) {
        _showErrorDialog('ไม่สามารถบันทึกไฟล์ลงเครื่องได้: $e');
      }

      // บันทึกลายเซ็นลงเครื่องผู้ใช้ (PNG)
      if (signatureBytes != null) {
        try {
          await FileSaver.instance.saveFile(
            name: 'signature_${freshUser.uid}_$timestamp',
            bytes: signatureBytes,
            ext: 'png');
        } catch (e) {
          _showErrorDialog('ไม่สามารถบันทึกลายเซ็นลงเครื่องได้: $e');
        }
      }

      // บันทึกรูปบัตรประชาชนลงเครื่องผู้ใช้ (PNG)
      if (_selectedIdCardFrontImage != null) {
        try {
          await FileSaver.instance.saveFile(
            name: 'id_card_front_${freshUser.uid}_$timestamp',
            bytes: await _selectedIdCardFrontImage!.readAsBytes(),
            ext: 'png');
        } catch (e) {
          _showErrorDialog('ไม่สามารถบันทึกรูปบัตรประชาชน (หน้า) ลงเครื่องได้: $e');
        }
      }
      if (_selectedIdCardBackImage != null) {
        // ... (โค้ดบันทึกบัตรด้านหลังจะถูกเพิ่มในขั้นตอนถัดไป)
      }

      // Navigate to the next step
      final serviceType = _resolvedServiceType ??
          (await FirebaseFirestore.instance
                  .collection('contracts')
                  .doc(freshUser.uid)
                  .get())
              .data()
              ?['serviceType'] as String?;

      if (!mounted) return;

      if (serviceType == null) {
        _showSnackBar('❌ ไม่พบประเภทบริการของบัญชีนี้ กรุณาเลือกบริการใหม่', Colors.red);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RegisterShopNextScreen()),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ShopRegistrationScreen(serviceType: serviceType),
        ),
      );
    } catch (e) {
      _showErrorDialog('เกิดข้อผิดพลาดทั่วไป: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // ฟังก์ชันอัปโหลดรูปภาพเป็น WebP
  /// อัปโหลดไฟล์แบบไม่ดึง URL กลับมา (สำหรับบัตรประชาชน)
  Future<void> _uploadImageOnly(File file, String path) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

      if (!await file.exists()) {
        throw Exception('ไม่พบไฟล์ที่เลือก กรุณาเลือกรูปภาพใหม่');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$path/${user.uid}_$timestamp.png';

      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('ไม่สามารถอ่านรูปภาพได้');
      final pngBytes = img.encodePng(decoded);

      final storage = FirebaseStorage.instanceFor(
        bucket: 'vanmarket-50d9d.firebasestorage.app',
      );
      final storageRef = storage.ref().child(fileName);
      print('📤 กำลังอัปโหลดไฟล์: $fileName');
      print('📍 Bucket: ${storage.bucket}');

      await storageRef.putData(
        Uint8List.fromList(pngBytes),
        SettableMetadata(contentType: 'image/png'),
      );

      print('✅ อัปโหลดสำเร็จ (ไม่ดึง URL)');
    } catch (e) {
      print('❌ Error อัปโหลด $path: $e');
      throw Exception('อัปโหลดไฟล์ใน $path ล้มเหลว: $e');
    }
  }

  Future<String?> _uploadImageAsWebp(File file, String path) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

      if (!await file.exists()) {
        throw Exception('ไม่พบไฟล์ที่เลือก กรุณาเลือกรูปภาพใหม่');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$path/${user.uid}_$timestamp.png';

      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('ไม่สามารถอ่านรูปภาพได้');
      final pngBytes = img.encodePng(decoded);

      final storage = FirebaseStorage.instanceFor(
        bucket: 'vanmarket-50d9d.firebasestorage.app',
      );
      final storageRef = storage.ref().child(fileName);
      print('📤 กำลังอัปโหลดไฟล์: $fileName');
      final uploadTask = await storageRef.putData(
        Uint8List.fromList(pngBytes),
        SettableMetadata(contentType: 'image/png'),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      print('✅ อัปโหลดสำเร็จ: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Error อัปโหลด $path: $e');
      throw Exception('อัปโหลดไฟล์ใน $path ล้มเหลว: $e');
    }
  }

  /// ฟังก์ชันตัวอย่างสำหรับตัดขอบรูปให้พอดีกับกรอบที่กำหนด (mock)
  /// ในโปรเจกต์จริงควรใช้ package เช่น 'image' หรือ API ภายนอก
  Future<File> cropImageToFrame(File imageFile, {int width = 180, int height = 180}) async {
    final bytes = await imageFile.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) return imageFile;

    // ปรับขนาดให้ด้านสั้นเท่ากับกรอบก่อน
    img.Image resized;
    if (original.width > original.height) {
      // กว้างกว่าสูง: resize สูงให้ตรง, กว้างตามอัตราส่วน
      resized = img.copyResize(original, height: height);
    } else {
      // สูงกว่ากว้างหรือเท่ากัน: resize กว้างให้ตรง, สูงตามอัตราส่วน
      resized = img.copyResize(original, width: width);
    }

    // crop ตรงกลางให้ได้ขนาด width x height
    int startX = (resized.width - width) ~/ 2;
    int startY = (resized.height - height) ~/ 2;
    final cropped = img.copyCrop(
      resized,
      x: startX,
      y: startY,
      width: width,
      height: height,
    );
    final outBytes = img.encodeJpg(cropped);
    final outFile = await imageFile.writeAsBytes(outBytes, flush: true);
    return outFile;
  }

  // ฟังก์ชันตรวจสอบความเบลอของภาพ (แบบง่าย)
  Future<bool> isImageBlurry(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return true;

    // แปลงเป็น grayscale
    final grayscale = img.grayscale(image);

    // วัดค่า contrast (ส่วนเบี่ยงเบนมาตรฐานของ pixel)
    final pixels = grayscale.getBytes();
    final mean = pixels.reduce((a, b) => a + b) / pixels.length;
    final variance = pixels.map((p) => (p - mean) * (p - mean)).reduce((a, b) => a + b) / pixels.length;
    final stddev = math.sqrt(variance);

    // threshold ต่ำถือว่าเบลอ
    return stddev < 20;
  }

  // ฟังก์ชันเลือกและตรวจสอบรูปภาพบัตรประชาชน
  Future<void> _pickAndValidateIdCardImage({required ImageSource source, required bool isFront}) async {
    String? imagePath;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 90,
      );
      if (image == null) return;
      imagePath = image.path;
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาดในการสแกน: $e', Colors.red);
    }

    if (imagePath == null) return;

    final originalFile = File(imagePath);

    setState(() {
      if (isFront) {
        _selectedIdCardFrontImage = null;
        _isProcessingIdCardFront = true;
      } else {
        _selectedIdCardBackImage = null;
        _isProcessingIdCardBack = true;
      }
    });

    try {
      final blurry = await isImageBlurry(originalFile);
      if (!mounted) return;

      if (blurry) {
        _showSnackBar('❌ ภาพเบลอ กรุณาเลือกรูปใหม่หรือถ่ายรูปให้ชัดเจน', Colors.red);
        setState(() {
          if (isFront) {
            _selectedIdCardFrontImage = null;
          } else {
            _selectedIdCardBackImage = null;
          }
        });
        return;
      }

      final persistedFile = await _persistTemporaryImage(originalFile, isFront: isFront);
      if (!mounted) return;

      setState(() {
        if (isFront) {
          _selectedIdCardFrontImage = persistedFile;
        } else {
          _selectedIdCardBackImage = persistedFile;
        }
      });

      _showSnackBar('✅ รูปภาพผ่านการตรวจสอบความชัดเจน', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('❌ เกิดข้อผิดพลาดในการตรวจสอบรูปภาพ: $e', Colors.red);
      setState(() {
        if (isFront) {
          _selectedIdCardFrontImage = null;
        } else {
          _selectedIdCardBackImage = null;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          if (isFront) {
            _isProcessingIdCardFront = false;
          } else {
            _isProcessingIdCardBack = false;
          }
        });
      }
    }
  }

  Future<File> _persistTemporaryImage(File source, {required bool isFront}) async {
    final suffix = isFront ? 'front' : 'back';
    final targetPath =
        '${Directory.systemTemp.path}/id_card_${suffix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    return source.copy(targetPath);
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('❌ เกิดข้อผิดพลาด'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(error), // Make error selectable
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text('💡 วิธีแก้ไข (สำหรับ Permission Denied):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const SelectableText(
                '''
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /contracts/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}''',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ปิด'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Retry
              _captureAndUploadContract();
            },
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () {
            // เมื่อกดปุ่มย้อนกลับ ให้ไปหน้า register_shop_next.dart
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => RegisterShopNextScreen(),
              ),
            );
          },
        ),
        title: const Text('สัญญาการให้บริการ'),
  backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'สัญญาการให้บริการ Van Merchant',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 24),
              const Text(
                'เนื้อหาสัญญา (สามารถแก้ไขได้)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red))
              else
                TextField(
                  controller: _contractTextController,
                  maxLines: null,
                  minLines: 10,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Color(0xFF2C3E50),
                  ),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'เนื้อหาสัญญา',
                    alignLabelWithHint: true,
                  ),
                ),
              const SizedBox(height: 40),
              const Text(
                'ลายมือชื่อ (ฝั่งร้านค้า)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Signature(
                  controller: _signatureController,
                  backgroundColor: Colors.transparent,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _signatureController.clear(),
                  icon: const Icon(Icons.clear, size: 20),
                  label: const Text('ล้างลายเซ็น'),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: Text(
                  'วันที่ $_currentDay/$_currentMonthNumber/$_currentYear',
                  style: const TextStyle(fontSize: 16, color: Color(0xFF2C3E50)),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'เอกสารยืนยันตัวตน',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'กรุณาอัปโหลดรูปถ่ายบัตรประชาชนที่ชัดเจน',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              _buildIdCardUploader(
                title: 'บัตรประชาชน (ด้านหน้า)',
                imageFile: _selectedIdCardFrontImage,
                isProcessing: _isProcessingIdCardFront,
                onTap: () => _showImageSourceDialog(isFront: true),
              ),
              const SizedBox(height: 16),
              _buildIdCardUploader(
                title: 'บัตรประชาชน (ด้านหลัง)',
                imageFile: _selectedIdCardBackImage,
                isProcessing: _isProcessingIdCardBack,
                onTap: () => _showImageSourceDialog(isFront: false),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _accepted,
                      onChanged: (value) {
                        setState(() => _accepted = value ?? false);
                      },
                      activeColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'ข้าพเจ้ายอมรับข้อกำหนดและเงื่อนไขในสัญญานี้',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_accepted && !_isUploading) ? _captureAndUploadContract : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: _isUploading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('กำลังบันทึกสัญญา...'),
                          ],
                        )
                      : const Text('ยอมรับและดำเนินการต่อ'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Dialog สำหรับเลือกแหล่งที่มาของรูป (กล้อง/คลังภาพ)
  Future<void> _showImageSourceDialog({required bool isFront}) async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('ใช้กล้องถ่ายรูป'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndValidateIdCardImage(source: ImageSource.camera, isFront: isFront);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('เลือกจากคลังภาพ'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndValidateIdCardImage(source: ImageSource.gallery, isFront: isFront);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Widget สำหรับสร้าง UI ของการอัปโหลดบัตร
  Widget _buildIdCardUploader({
    required String title,
    required File? imageFile,
    required bool isProcessing,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: isProcessing ? null : onTap,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: isProcessing
                ? const Center(child: CircularProgressIndicator())
                : imageFile != null
                    ? Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            imageFile,
                            fit: BoxFit.contain,
                            width: 180,
                            height: 180,
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'แตะเพื่ออัปโหลดรูปภาพ',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }
}
