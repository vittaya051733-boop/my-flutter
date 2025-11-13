import 'dart:io';

import 'package:flutter/material.dart';
import 'package:myapp/register_screen.dart';
import 'package:myapp/register_shop_blank.dart';

class RegisterShopNextScreen extends StatefulWidget {
  const RegisterShopNextScreen({super.key});

  @override
  State<RegisterShopNextScreen> createState() => _RegisterShopNextScreenState();
}

class _RegisterShopNextScreenState extends State<RegisterShopNextScreen> {
  DateTime getOneHourAgo() {
    return DateTime.now().subtract(const Duration(hours: 1));
  }

  DateTime getThirtyMinutesAgo() {
    return DateTime.now().subtract(const Duration(minutes: 30));
  }

  DateTime getTwoHoursAgo() {
    return DateTime.now().subtract(const Duration(hours: 2));
  }

  Future<File> cropImageWithAI(File image) async {
    // TODO: integrate real AI-based cropping if required.
    return image;
  }

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
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const RegisterShopBlankScreen()),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        // แก้ไข: ใช้ SingleChildScrollView ครอบ Column เพื่อป้องกัน overflow
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'เลือกบริการ',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 16),
              _MarketServiceButton(),
              SizedBox(height: 20),
              _ShopServiceButton(),
              SizedBox(height: 20),
              _RestaurantServiceButton(),
              SizedBox(height: 20),
              _PharmacyServiceButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestaurantServiceButton extends StatelessWidget {
  const _RestaurantServiceButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 160,
        height: 160,
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
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const RegisterScreen(
                serviceType: 'ร้านอาหาร',
              ),
            ));
          },
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FittedBox(
                fit: BoxFit.cover,
                child: Image.asset(
                  'assets/file_00000000bbe47207bb71ef6ccfba8497.png',
                  width: 140,
                  height: 140,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketServiceButton extends StatelessWidget {
  const _MarketServiceButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 160,
        height: 160,
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
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const RegisterScreen(
                serviceType: 'ตลาด',
              ),
            ));
          },
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/file_000000005608720696142f5cc8982ea6.png',
                fit: BoxFit.cover,
                width: 130,
                height: 130,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopServiceButton extends StatelessWidget {
  const _ShopServiceButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 160,
        height: 160,
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
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const RegisterScreen(
                serviceType: 'ร้านค้า',
              ),
            ));
          },
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/file_0000000091107206af5b52f49d594ba6.png',
                fit: BoxFit.cover,
                width: 160,
                height: 160,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PharmacyServiceButton extends StatelessWidget {
  const _PharmacyServiceButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 208, // 160 + 30% = 208
        height: 208,
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
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const RegisterScreen(
                serviceType: 'ร้านขายยา',
              ),
            ));
          },
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FittedBox(
                fit: BoxFit.cover,
                child: Image.asset(
                  'assets/pharmacy_equal.png',
                  width: 220,
                  height: 220,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
