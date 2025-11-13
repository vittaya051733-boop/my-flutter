import 'package:flutter/material.dart';
import 'dart:math';

import 'utils/app_colors.dart';

class SliderCaptchaWidget extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback? onFail;

  const SliderCaptchaWidget({
    super.key,
    required this.onSuccess,
    this.onFail,
  });

  @override
  State<SliderCaptchaWidget> createState() => _SliderCaptchaWidgetState();
}

class _SliderCaptchaWidgetState extends State<SliderCaptchaWidget> {
  double _sliderValue = 0;
  double _targetPosition = 0;
  bool _isVerifying = false;
  bool _isSuccess = false;
  bool _isFailed = false;
  final double _tolerance = 10.0; // ความคลาดเคลื่อนที่ยอมรับได้ (pixels)

  @override
  void initState() {
    super.initState();
    _generateNewChallenge();
  }

  void _generateNewChallenge() {
    setState(() {
      // สุ่มตำแหน่งเป้าหมาย (20% - 80% ของความกว้าง)
      _targetPosition = 0.2 + Random().nextDouble() * 0.6;
      _sliderValue = 0;
      _isSuccess = false;
      _isFailed = false;
      _isVerifying = false;
    });
  }

  void _verifyPosition() {
    setState(() {
      _isVerifying = true;
    });

    // จำลองการตรวจสอบ (ในความเป็นจริงอาจต้องส่งไปตรวจสอบที่ server)
    Future.delayed(const Duration(milliseconds: 500), () {
      final difference = (_sliderValue - _targetPosition).abs();
      
      if (difference <= _tolerance / 300) { // แปลง tolerance เป็นเปอร์เซนต์
        setState(() {
          _isSuccess = true;
          _isVerifying = false;
        });
        
        // แจ้งผลสำเร็จหลังจาก animation เสร็จ
        Future.delayed(const Duration(milliseconds: 500), () {
          widget.onSuccess();
        });
      } else {
        setState(() {
          _isFailed = true;
          _isVerifying = false;
        });
        
        if (widget.onFail != null) {
          widget.onFail!();
        }
        
        // รีเซ็ตหลังจาก 1 วินาที
        Future.delayed(const Duration(seconds: 1), () {
          _generateNewChallenge();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.security,
                  color: AppColors.accent,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'ยืนยันตัวตนด้วย Captcha',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // พื้นที่แสดงภาพ Captcha
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: Stack(
                children: [
                  // ภาพพื้นหลัง
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CustomPaint(
                        painter: BackgroundPatternPainter(),
                      ),
                    ),
                  ),
                  
                  // ช่องว่างที่ต้องเลื่อน
                  Positioned(
                    left: _targetPosition * (MediaQuery.of(context).size.width - 120),
                    top: 75,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isSuccess 
                              ? Colors.green 
                              : _isFailed 
                                  ? Colors.red 
                                  : Colors.blue,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white.withAlpha(77), // withOpacity(0.3)
                      ),
                    ),
                  ),
                  
                  // ชิ้นส่วนที่เลื่อน
                  Positioned(
                    left: _sliderValue * (MediaQuery.of(context).size.width - 120),
                    top: 75,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _isSuccess 
                            ? Colors.green
                              : _isFailed
                                ? Colors.red 
                                : Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                          color: Colors.black.withAlpha(51), // withOpacity(0.2)
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isSuccess 
                            ? Icons.check 
                            : _isFailed 
                                ? Icons.close 
                                : Icons.touch_app,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Slider
            if (!_isSuccess && !_isVerifying)
              Column(
                children: [
                  Text(
                    _isFailed 
                        ? 'ไม่ถูกต้อง กรุณาลองใหม่' 
                        : 'เลื่อนชิ้นส่วนไปยังตำแหน่งที่ถูกต้อง',
                    style: TextStyle(
                      color: _isFailed ? Colors.red : Colors.grey[700],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _sliderValue,
                    onChanged: _isVerifying ? null : (value) {
                      setState(() {
                        _sliderValue = value;
                      });
                    },
                    onChangeEnd: (value) {
                      if (!_isVerifying) {
                        _verifyPosition();
                      }
                    },
                    activeColor: AppColors.accent,
                    inactiveColor: Colors.grey[300],
                  ),
                ],
              ),
            
            if (_isVerifying)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('กำลังตรวจสอบ...'),
                ],
              ),
            
            if (_isSuccess)
              Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ยืนยันตัวตนสำเร็จ!',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// วาดลวดลายพื้นหลัง
class BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.fill;

    // วาดลายจุดเล็กๆ
    for (double i = 0; i < size.width; i += 20) {
      for (double j = 0; j < size.height; j += 20) {
        canvas.drawCircle(Offset(i, j), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
