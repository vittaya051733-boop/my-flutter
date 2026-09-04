import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;

import 'order_qr_receipt_bitmap.dart';

Future<List<int>> buildEscPosReceiptBytes(Uint8List receiptPng) async {
  final profile = await CapabilityProfile.load();
  final generator = Generator(PaperSize.mm58, profile);
  final decoded = img.decodePng(receiptPng);
  if (decoded == null) {
    throw Exception('ไม่สามารถอ่านภาพใบเสร็จได้');
  }

  final gray = img.grayscale(decoded);
  return <int>[
    ...generator.imageRaster(gray, align: PosAlign.center),
    ...generator.feed(receiptTrailingBlankLines),
    ...generator.cut(),
  ];
}
