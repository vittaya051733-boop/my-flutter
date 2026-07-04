import 'dart:io';

import 'package:image/image.dart' as img;

/// ปรับภาพเป็น portrait 9:16 (1080×1920) — เต็มความสูง ตัดขอบซ้ายขวา
void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run tool/export_onboarding_9x16.dart <input.png> <output.png>');
    exit(1);
  }

  const targetWidth = 1080;
  const targetHeight = 1920;

  final source = img.decodeImage(File(args[0]).readAsBytesSync());
  if (source == null) {
    stderr.writeln('Failed to decode image: ${args[0]}');
    exit(1);
  }

  final scale = targetHeight / source.height;
  final scaledWidth = (source.width * scale).round();
  final scaled = img.copyResize(
    source,
    width: scaledWidth,
    height: targetHeight,
    interpolation: img.Interpolation.cubic,
  );

  final cropX = ((scaledWidth - targetWidth) / 2).round().clamp(0, scaledWidth - targetWidth);
  final output = img.copyCrop(
    scaled,
    x: cropX,
    y: 0,
    width: targetWidth,
    height: targetHeight,
  );

  File(args[1]).writeAsBytesSync(img.encodePng(output));
  stdout.writeln('${output.width}x${output.height} -> ${args[1]}');
}
