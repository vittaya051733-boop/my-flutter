import 'package:flutter/material.dart';
import 'register_base_screen.dart';
import 'login_screen.dart';

String getCollectionForService(String serviceType) {
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
      return 'other_registrations';
  }
}



class RegisterMarketScreen extends RegisterBaseScreen {
  const RegisterMarketScreen({required super.serviceType, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'เปิดร้านกับ Van เพื่อเข้าถึงกลุ่มลูกค้าได้มากขึ้น\nประเภท: $serviceType',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () async {
                  // ส่ง serviceType ไปยังหน้า Login
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => LoginScreen(serviceType: serviceType),
                    ),
                  );
                },
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: Image.asset(
                      'assets/file_000000005608720696142f5cc8982ea6.png', // ใช้ไฟล์นี้แทน
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// สาเหตุที่อาจเกิด error:
//
// 1. ไฟล์ภาพ 'assets/van_market_logo.png' ไม่อยู่ในโฟลเดอร์ assets หรือยังไม่ได้ประกาศใน pubspec.yaml
//    - ตรวจสอบว่าไฟล์ภาพอยู่ในโฟลเดอร์ assets จริง
//    - เปิด pubspec.yaml แล้วเพิ่ม (และ uncomment) เช่น:
//
//      flutter:
//        assets:
//          - assets/van_market_logo.png
//
// 2. หาก error เกี่ยวกับ ElevatedButton หรือ Ink ให้ตรวจสอบว่าใช้ Flutter เวอร์ชันที่รองรับ
//
// 3. หาก error อื่น ๆ ให้ดูข้อความ error ที่แสดงใน console เพื่อระบุสาเหตุ

// สาเหตุที่ภาพไม่แสดง อาจเกิดจาก:
// 1. ไฟล์ภาพยังไม่ได้ถูกวางไว้ในโฟลเดอร์ assets ของโปรเจกต์ (เช่น c:\Users\TAM\Desktop\t3\my-flutter\assets\van_market_logo.png)
// 2. ยังไม่ได้ประกาศ assets ใน pubspec.yaml

// วิธีแก้ไข:
// - ให้นำไฟล์ภาพที่แนบมา (van_market_logo.png) ไปไว้ในโฟลเดอร์ assets
// - เปิดไฟล์ pubspec.yaml แล้วเพิ่มหรือแก้ไขส่วนนี้ (อย่าลืมจัด format และเว้นวรรคให้ถูกต้อง):

/*
flutter:
  assets:
    - assets/van_market_logo.png
*/

// - จากนั้นรันคำสั่ง `flutter pub get` ใน terminal เพื่ออัปเดต assets

// หากยังไม่แสดง ให้ตรวจสอบชื่อไฟล์และ path ว่าตรงกันหรือไม่ (ต้องเป็น 'assets/van_market_logo.png')
// ตรวจสอบ pubspec.yaml ว่าประกาศ assets ถูกต้องหรือยัง
// ตัวอย่างที่ถูกต้อง (ต้องอยู่ในไฟล์ pubspec.yaml และจัด format/indent ให้ถูกต้อง):

/*
flutter:
  assets:
    - assets/van_market_logo.png
*/

// หลังจากแก้ไข pubspec.yaml แล้ว ให้รันคำสั่งนี้ใน terminal:
/// flutter pub get

// หากยังไม่แสดง ให้ตรวจสอบชื่อไฟล์ว่าเป็น van_market_logo.png (ไม่ใช่ .jpg หรือ .jpeg)
// และ path ต้องตรงกับ assets/van_market_logo.png
