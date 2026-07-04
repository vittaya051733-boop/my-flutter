import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:van1/register_screen.dart';
import 'package:van1/register_shop_blank.dart';

/// หน้าเลือกประเภทบริการ — ภาพเดียว + โซนกดทับแต่ละการ์ด
class RegisterShopNextScreen extends StatefulWidget {
  const RegisterShopNextScreen({super.key});

  static const String assetPath = 'assets/merchant_service_select_9_20.png';

  // พิกัดโซนกดอ้างอิงตำแหน่งการ์ดจริงในภาพ (วัดจากไอคอน/ลูกศรของแต่ละการ์ด)
  // โซนต่อเนื่องกันเพื่อไม่ให้มีจุดตายระหว่างการ์ด
  static const List<_ServiceTapZone> tapZones = <_ServiceTapZone>[
    _ServiceTapZone(
      key: Key('service_tap_market'),
      serviceType: 'ตลาด',
      label: 'ตลาด',
      topRatio: 0.368,
      heightRatio: 0.161,
      leftRatio: 0.04,
      rightRatio: 0.04,
    ),
    _ServiceTapZone(
      key: Key('service_tap_shop'),
      serviceType: 'ร้านค้า',
      label: 'ร้านค้า',
      topRatio: 0.529,
      heightRatio: 0.147,
      leftRatio: 0.04,
      rightRatio: 0.04,
    ),
    _ServiceTapZone(
      key: Key('service_tap_restaurant'),
      serviceType: 'ร้านอาหาร',
      label: 'ร้านอาหาร',
      topRatio: 0.676,
      heightRatio: 0.136,
      leftRatio: 0.04,
      rightRatio: 0.04,
    ),
    _ServiceTapZone(
      key: Key('service_tap_pharmacy'),
      serviceType: 'ร้านขายยา',
      label: 'ร้านขายยา',
      topRatio: 0.812,
      heightRatio: 0.133,
      leftRatio: 0.04,
      rightRatio: 0.04,
    ),
  ];

  @override
  State<RegisterShopNextScreen> createState() => _RegisterShopNextScreenState();
}

class _ServiceTapZone {
  const _ServiceTapZone({
    required this.key,
    required this.serviceType,
    required this.label,
    required this.topRatio,
    required this.heightRatio,
    required this.leftRatio,
    required this.rightRatio,
  });

  final Key key;
  final String serviceType;
  final String label;
  final double topRatio;
  final double heightRatio;
  final double leftRatio;
  final double rightRatio;
}

class _RegisterShopNextScreenState extends State<RegisterShopNextScreen> {
  Size _imageSize = const Size(458, 1024);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_resolveImageSize());
  }

  Future<void> _resolveImageSize() async {
    final stream = AssetImage(RegisterShopNextScreen.assetPath)
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
      // คงค่า default ไว้
    }
  }

  void _goBack(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const RegisterShopBlankScreen(),
      ),
    );
  }

  void _selectService(BuildContext context, String serviceType) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegisterScreen(serviceType: serviceType),
      ),
    );
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

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: offsetX,
                top: offsetY,
                width: displayWidth,
                height: displayHeight,
                child: Image.asset(
                  RegisterShopNextScreen.assetPath,
                  width: displayWidth,
                  height: displayHeight,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              for (final zone in RegisterShopNextScreen.tapZones)
                Positioned(
                  left: offsetX + displayWidth * zone.leftRatio,
                  top: offsetY + displayHeight * zone.topRatio,
                  width: displayWidth * (1 - zone.leftRatio - zone.rightRatio),
                  height: displayHeight * zone.heightRatio,
                  child: Semantics(
                    button: true,
                    label: zone.label,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: zone.key,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () => _selectService(context, zone.serviceType),
                      ),
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
