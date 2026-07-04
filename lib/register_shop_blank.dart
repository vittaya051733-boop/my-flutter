import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// หน้าชักชวนเปิดร้าน — ภาพเดียว scale เท่ากันทุกด้าน (ไม่ยืด) ปุ่มอยู่ในภาพ
class RegisterShopBlankScreen extends StatefulWidget {
  const RegisterShopBlankScreen({super.key});

  static const String assetPath = 'assets/merchant_onboarding_9_20.png';

  /// โซนกดทับปุ่ม "เริ่มเปิดร้านเลย" ในภาพ (ไม่แสดงปุ่ม Flutter)
  static const double ctaLeftRatio = 0.065;
  static const double ctaRightRatio = 0.065;
  static const double ctaBottomRatio = 0.136;
  static const double ctaHeightRatio = 0.048;

  @override
  State<RegisterShopBlankScreen> createState() => _RegisterShopBlankScreenState();
}

class _RegisterShopBlankScreenState extends State<RegisterShopBlankScreen> {
  /// ขนาดภาพจริง — ใช้ก่อนโหลดเสร็จ เพื่อจัดวางโซนกดให้ตรง
  Size _imageSize = const Size(459, 1024);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_resolveImageSize());
  }

  Future<void> _resolveImageSize() async {
    final stream = AssetImage(RegisterShopBlankScreen.assetPath)
        .resolve(createLocalImageConfiguration(context));
    final completer = Completer<Size>();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!completer.isCompleted) {
          completer.complete(
            Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            ),
          );
        }
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);

    try {
      final size = await completer.future;
      if (mounted) {
        setState(() => _imageSize = size);
      }
    } catch (_) {
      // คงค่า default portrait ไว้
    }
  }

  void _goBack(BuildContext context) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  void _startRegistration(BuildContext context) {
    Navigator.of(context).pushNamed('/register-shop-next');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final imageSize = _imageSize;

          final scale = math.min(
            constraints.maxWidth / imageSize.width,
            constraints.maxHeight / imageSize.height,
          );
          final displayWidth = imageSize.width * scale;
          final displayHeight = imageSize.height * scale;
          final offsetX = (constraints.maxWidth - displayWidth) / 2;
          final offsetY = (constraints.maxHeight - displayHeight) / 2;

          final ctaLeft =
              offsetX + displayWidth * RegisterShopBlankScreen.ctaLeftRatio;
          final ctaWidth = displayWidth *
              (1 -
                  RegisterShopBlankScreen.ctaLeftRatio -
                  RegisterShopBlankScreen.ctaRightRatio);
          final ctaHeight =
              displayHeight * RegisterShopBlankScreen.ctaHeightRatio;
          final ctaTop = offsetY +
              displayHeight -
              (displayHeight * RegisterShopBlankScreen.ctaBottomRatio) -
              ctaHeight;

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: offsetX,
                top: offsetY,
                width: displayWidth,
                height: displayHeight,
                child: Image.asset(
                  RegisterShopBlankScreen.assetPath,
                  width: displayWidth,
                  height: displayHeight,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              Positioned(
                left: ctaLeft,
                top: ctaTop,
                width: ctaWidth,
                height: ctaHeight,
                child: Semantics(
                  button: true,
                  label: 'เริ่มเปิดร้านเลย',
                  child: GestureDetector(
                    key: const Key('merchant_onboarding_cta'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _startRegistration(context),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.82),
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        tooltip: 'ย้อนกลับ',
                        onPressed: () => _goBack(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
