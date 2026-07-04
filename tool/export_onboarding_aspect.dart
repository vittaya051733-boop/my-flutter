import 'dart:io';

import 'package:image/image.dart' as img;

/// ปรับภาพเป็น portrait ตามสัดส่วน
/// mode: crop (crop กลางแล้ว resize) | fill | fit
void main(List<String> args) {
  if (args.length < 5) {
    stderr.writeln(
      'Usage: dart run tool/export_onboarding_aspect.dart <input> <output> <wRatio> <hRatio> <crop|fill|fit>',
    );
    exit(1);
  }

  final aspectW = double.parse(args[2]);
  final aspectH = double.parse(args[3]);
  final mode = args[4];
  const targetWidth = 1080;
  final targetHeight = (targetWidth * aspectH / aspectW).round();

  final source = img.decodeImage(File(args[0]).readAsBytesSync());
  if (source == null) {
    stderr.writeln('Failed to decode image: ${args[0]}');
    exit(1);
  }

  late img.Image output;
  switch (mode) {
    case 'crop':
      var cropH = source.height;
      var cropW = (cropH * aspectW / aspectH).round();
      if (cropW > source.width) {
        cropW = source.width;
        cropH = (cropW * aspectH / aspectW).round();
      }
      final cropX = ((source.width - cropW) / 2).round();
      final cropY = ((source.height - cropH) / 2).round();
      final cropped = img.copyCrop(
        source,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );
      output = img.copyResize(
        cropped,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.cubic,
      );
    case 'fill':
      final scale = targetHeight / source.height;
      final scaledWidth = (source.width * scale).round();
      final scaled = img.copyResize(
        source,
        width: scaledWidth,
        height: targetHeight,
        interpolation: img.Interpolation.cubic,
      );
      final cropX = ((scaledWidth - targetWidth) / 2)
          .round()
          .clamp(0, scaledWidth - targetWidth);
      output = img.copyCrop(
        scaled,
        x: cropX,
        y: 0,
        width: targetWidth,
        height: targetHeight,
      );
    default:
      final background = img.ColorRgb8(255, 255, 255);
      final scale = targetWidth / source.width;
      final scaledHeight = (source.height * scale).round();
      final scaled = img.copyResize(
        source,
        width: targetWidth,
        height: scaledHeight,
        interpolation: img.Interpolation.cubic,
      );
      output = img.Image(width: targetWidth, height: targetHeight);
      img.fill(output, color: background);
      final offsetY =
          ((targetHeight - scaledHeight) / 2).round().clamp(0, targetHeight);
      img.compositeImage(output, scaled, dstX: 0, dstY: offsetY);
  }

  File(args[1]).writeAsBytesSync(img.encodePng(output));
  stdout.writeln('${aspectW}:${aspectH} [$mode] => ${output.width}x${output.height} -> ${args[1]}');
}
