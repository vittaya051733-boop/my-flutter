import 'package:flutter/material.dart';

import 'utils/app_colors.dart';

class RegisterShopBlankScreen extends StatelessWidget {
  const RegisterShopBlankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, size: 28),
                tooltip: 'ย้อนกลับ',
                onPressed: () {
                  final nav = Navigator.of(context);
                  if (nav.canPop()) {
                    nav.pop();
                  } else {
                    nav.pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'เปิดร้านกับ Van เพื่อเข้าถึงกลุ่มลูกค้าได้มากกว่า',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'โปรดดำเนินการตามขั้นตอนต่อไปนี้',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  SizedBox(height: 28),
                  Text(
                    'ลงทะเบียนเข้าสู่ระบบ',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    ' สามารถลงทะเบียนได้ 4 รูปแบบ 1 การลงทะเบียนด้วยเปิดโทรศัพท์ 2 ลงทะเบียนด้วย อีเมล์ 3 ลงทะเบียนด้วย เฟซบุ๊ก 4ลงทะเบียนด้วย กูเกิล แอคเคาท์',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'เซนสัญญา',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'ลงนามในสัญญาเพื่อเข้าร่วมเป็นพาร์ทเนอร์กับ Van',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ตั้งค่าร้านค้าของฉัน',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'สร้างโปรไฟล์ร้านค้าของคุณให้โดดเด่นด้วยการอัปโหลดภาพ จัดการเมนู และอื่นๆ เพื่อเพิ่มการมองเห็นของลูกค้า',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Expanded(child: SizedBox()),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    elevation: 2,
                  ),
                  onPressed: () {
                    debugPrint('ปุ่มต่อไปถูกกด!');
                    Navigator.of(context).pushNamed('/register-shop-next');
                  },
                  child: const Text('ต่อไป'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
