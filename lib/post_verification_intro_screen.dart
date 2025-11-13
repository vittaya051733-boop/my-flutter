import 'package:flutter/material.dart';
import 'utils/app_colors.dart';

class PostVerificationIntroScreen extends StatelessWidget {
  final String? serviceType;
  const PostVerificationIntroScreen({super.key, this.serviceType});

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
                icon: const Icon(Icons.arrow_back_ios_new, size: 28),
                tooltip: 'ย้อนกลับ',
                onPressed: () {
                  // Prevent going back to verification screen
                  // This button is mostly for visual consistency
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
                    'ยืนยันตัวตนสำเร็จ!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'ขั้นตอนต่อไปคือการเซ็นสัญญาและลงทะเบียนร้านค้าของคุณ',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  SizedBox(height: 28),
                  Text(
                    '1. เซ็นสัญญา',
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2. ตั้งค่าร้านค้าของคุณ',
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
            const Spacer(),
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
                  ),
                  onPressed: () {
                    // Navigate to the contract screen and pass the serviceType
                    Navigator.of(context).pushReplacementNamed(
                      '/contract',
                      arguments: serviceType,
                    );
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