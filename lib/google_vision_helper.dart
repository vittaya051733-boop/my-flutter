import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'firebase_options.dart'; // เพิ่ม import

class GoogleVisionHelper {
  /// ตรวจสอบว่ารูปภาพเป็นสมุดบัญชีหรือไม่
  static Future<Map<String, dynamic>> validateBookBankImage(File imageFile) async {
    try {
      final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
      final visionApiUrl = 'https://vision.googleapis.com/v1/images:annotate?key=$apiKey';
      // แปลงรูปภาพเป็น base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // สร้าง request body
      final requestBody = {
        'requests': [
          {
            'image': {'content': base64Image},
            'features': [
              {'type': 'DOCUMENT_TEXT_DETECTION'}
            ]
          }
        ]
      };

      // ส่ง request ไป Google Cloud Vision API
      final response = await http.post(
        Uri.parse(visionApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        return {
          'isValid': false,
          'error': 'API Error: ${response.statusCode}',
          'missingItems': []
        };
      }

      final data = jsonDecode(response.body);
      final textAnnotations = data['responses'][0]['textAnnotations'];

      if (textAnnotations == null || textAnnotations.isEmpty) {
        return {
          'isValid': false,
          'error': 'ไม่พบข้อความในรูปภาพ',
          'missingItems': ['ชื่อธนาคาร', 'หมายเลขบัญชี', 'ชื่อเจ้าของบัญชี']
        };
      }

      // ดึงข้อความทั้งหมด
      final fullText = textAnnotations[0]['description'].toString().toLowerCase();

      // ตรวจสอบ 3 องค์ประกอบ
      bool hasBankName = false;
      bool hasAccountNumber = false;
      bool hasAccountOwner = false;
      final missingItems = <String>[];

      // 1. ตรวจสอบชื่อธนาคาร
      final bankNames = [
        'ธนาคาร', 'bank',
        'กรุงเทพ', 'bangkok',
        'กสิกร', 'kasikorn',
        'กรุงไทย', 'krung thai',
        'ไทยพาณิชย์', 'siam commercial',
        'กรุงศรี', 'krungsri',
        'ออมสิน', 'government savings',
        'อาคารสงเคราะห์', 'government housing',
        'ธ.ก.ส', 'baac', 'เพื่อการเกษตร',
        'ธนชาต', 'thanachart',
        'ทหารไทยธนชาต', 'ttb',
        'ซีไอเอ็มบี', 'cimb',
        'ยูโอบี', 'united overseas',
        'แลนด์ แอนด์ เฮ้าส์', 'land and houses'
      ];

      for (final bank in bankNames) {
        if (fullText.contains(bank)) {
          hasBankName = true;
          break;
        }
      }

      if (!hasBankName) {
        missingItems.add('ชื่อธนาคาร');
      }

      // 2. ตรวจสอบหมายเลขบัญชี
      final accountNumberPattern1 = RegExp(r'\d{10,13}');
      final accountNumberPattern2 = RegExp(r'\d{1,4}[-\s]?\d{1,2}[-\s]?\d{4,6}[-\s]?\d{1,2}');
      
      if (accountNumberPattern1.hasMatch(fullText.replaceAll(RegExp(r'[\s\-]'), '')) ||
          accountNumberPattern2.hasMatch(fullText)) {
        hasAccountNumber = true;
      }

      if (!hasAccountNumber) {
        missingItems.add('หมายเลขบัญชี');
      }

      // 3. ตรวจสอบชื่อเจ้าของบัญชี
      if (fullText.contains('ชื่อ') ||
          fullText.contains('name') ||
          fullText.contains('นาย') ||
          fullText.contains('นาง') ||
          fullText.contains('mr.') ||
          fullText.contains('mrs.') ||
          fullText.contains('miss') ||
          textAnnotations.length >= 5) {
        hasAccountOwner = true;
      }

      if (!hasAccountOwner) {
        missingItems.add('ชื่อเจ้าของบัญชี');
      }

      // ส่งผลลัพธ์
      return {
        'isValid': hasBankName && hasAccountNumber && hasAccountOwner,
        'missingItems': missingItems,
        'fullText': fullText,
      };

    } catch (e) {
      return {
        'isValid': false,
        'error': 'เกิดข้อผิดพลาด: $e',
        'missingItems': []
      };
    }
  }
}
