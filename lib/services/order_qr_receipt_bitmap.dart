import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'order_qr_receipt_layout.dart';

/// Narrow thermal / mini pocket printers (e.g. S1) usually accept bitmap only.
const double receiptPaperWidth = 384;
const double receiptPadding = 14;
const double receiptQrSize = 190;
const double receiptBodyLineHeight = 25;
const int receiptTrailingBlankLines = 3;

Future<Uint8List> buildOrderQrReceiptPngBytes({
  required String qrPayload,
  required OrderQrReceiptLayout layout,
  String receiptTitle = 'แว๊นตลาด ORDER QR',
}) async {
  await GoogleFonts.pendingFonts([GoogleFonts.notoSansThai()]);

  final titleStyle = GoogleFonts.notoSansThai(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: Colors.black,
    height: 1.2,
  );
  final sectionStyle = GoogleFonts.notoSansThai(
    fontSize: 21,
    fontWeight: FontWeight.w700,
    color: Colors.black,
    height: 1.25,
  );
  final bodyStyle = GoogleFonts.notoSansThai(
    fontSize: 19,
    color: Colors.black,
    height: 1.3,
  );
  final toppingStyle = GoogleFonts.notoSansThai(
    fontSize: 17,
    color: const Color(0xFF334155),
    height: 1.25,
  );
  final totalStyle = GoogleFonts.notoSansThai(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: Colors.black,
    height: 1.3,
  );

  final contentWidth = receiptPaperWidth - (receiptPadding * 2);
  final blocks = <_ReceiptBlock>[
    _ReceiptBlock.text(receiptTitle, titleStyle, center: true),
    _ReceiptBlock.gap(8),
    _ReceiptBlock.divider(),
    _ReceiptBlock.gap(8),
    _ReceiptBlock.text('QR CODE', sectionStyle, center: true),
    _ReceiptBlock.gap(10),
    _ReceiptBlock.qr(qrPayload),
    _ReceiptBlock.gap(12),
    _ReceiptBlock.divider(),
    _ReceiptBlock.gap(8),
    _ReceiptBlock.text('ข้อมูลที่ใช้ตรวจ QR', sectionStyle),
    _ReceiptBlock.gap(6),
    _ReceiptBlock.text('Order ID: ${layout.orderId}', bodyStyle),
    _ReceiptBlock.text(
      'เลขออเดอร์: ${layout.orderCode.isEmpty ? '-' : layout.orderCode}',
      bodyStyle,
    ),
    _ReceiptBlock.text('วันที่: ${layout.dateTimeText}', bodyStyle),
    _ReceiptBlock.gap(6),
    _ReceiptBlock.text('รายการสินค้า', sectionStyle),
    _ReceiptBlock.gap(4),
    _ReceiptBlock.leftRight(
      'ค่าสินค้า',
      formatOrderQrMoney(layout.productSubtotal),
      bodyStyle,
    ),
    _ReceiptBlock.gap(4),
  ];

  for (final item in layout.items) {
    blocks.add(
      _ReceiptBlock.leftRight(
        '${item.name} x${item.quantity}',
        formatOrderQrMoney(item.lineTotal),
        bodyStyle,
      ),
    );
    final toppings = item.toppings;
    if (toppings != null) {
      blocks.add(_ReceiptBlock.text('  ท็อปปิ้ง: $toppings', toppingStyle));
    }
  }

  blocks.addAll(<_ReceiptBlock>[
    _ReceiptBlock.gap(6),
    _ReceiptBlock.leftRight(
      'ค่าส่ง',
      formatOrderQrMoney(layout.shippingFee),
      bodyStyle,
    ),
    _ReceiptBlock.gap(4),
    _ReceiptBlock.leftRight(
      'ยอดรวม',
      formatOrderQrMoney(layout.grandTotal),
      totalStyle,
      rightStyle: totalStyle,
    ),
    _ReceiptBlock.gap(receiptBodyLineHeight * receiptTrailingBlankLines),
    _ReceiptBlock.gap(8),
  ]);

  final totalHeight = blocks.fold<double>(
        receiptPadding * 2,
        (height, block) => height + block.height(contentWidth),
      ) +
      8;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, receiptPaperWidth, totalHeight),
    Paint()..color = const Color(0xFFFFFFFF),
  );

  var y = receiptPadding;
  for (final block in blocks) {
    y += block.paint(canvas, y, contentWidth);
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    receiptPaperWidth.toInt(),
    totalHeight.ceil(),
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  if (byteData == null) {
    throw StateError('ไม่สามารถสร้างภาพใบพิมพ์ได้');
  }
  return byteData.buffer.asUint8List();
}

class _ReceiptBlock {
  _ReceiptBlock._(this._height, this._paint);

  factory _ReceiptBlock.text(
    String text,
    TextStyle style, {
    bool center = false,
  }) {
    return _ReceiptBlock._(
      0,
      (canvas, y, contentWidth) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textAlign: center ? TextAlign.center : TextAlign.left,
          textDirection: TextDirection.ltr,
          maxLines: null,
        )..layout(maxWidth: contentWidth);

        final dx = center
            ? receiptPadding + ((contentWidth - painter.width) / 2)
            : receiptPadding;
        painter.paint(canvas, Offset(dx, y));
        return painter.height;
      },
    );
  }

  factory _ReceiptBlock.leftRight(
    String left,
    String right,
    TextStyle leftStyle, {
    TextStyle? rightStyle,
  }) {
    return _ReceiptBlock._(
      0,
      (canvas, y, contentWidth) {
        final resolvedRightStyle = rightStyle ?? leftStyle;
        final rightPainter = TextPainter(
          text: TextSpan(text: right, style: resolvedRightStyle),
          textDirection: TextDirection.ltr,
        )..layout();

        final leftMaxWidth = math.max(
          40.0,
          contentWidth - rightPainter.width - 8,
        );
        final leftPainter = TextPainter(
          text: TextSpan(text: left, style: leftStyle),
          textDirection: TextDirection.ltr,
          maxLines: null,
        )..layout(maxWidth: leftMaxWidth);

        leftPainter.paint(canvas, Offset(receiptPadding, y));
        rightPainter.paint(
          canvas,
          Offset(receiptPadding + contentWidth - rightPainter.width, y),
        );
        return math.max(leftPainter.height, rightPainter.height).toDouble();
      },
    );
  }

  factory _ReceiptBlock.divider() {
    return _ReceiptBlock._(
      1,
      (canvas, y, contentWidth) {
        final paint = Paint()
          ..color = Colors.black
          ..strokeWidth = 1;
        canvas.drawLine(
          Offset(receiptPadding, y),
          Offset(receiptPadding + contentWidth, y),
          paint,
        );
        return 1;
      },
    );
  }

  factory _ReceiptBlock.gap(double size) {
    return _ReceiptBlock._(size, (_, __, ___) => size);
  }

  factory _ReceiptBlock.qr(String payload) {
    return _ReceiptBlock._(
      receiptQrSize,
      (canvas, y, _) {
        final painter = QrPainter(
          data: payload,
          version: QrVersions.auto,
          gapless: true,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Colors.black,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Colors.black,
          ),
        );
        final left = (receiptPaperWidth - receiptQrSize) / 2;
        canvas.save();
        canvas.translate(left, y);
        painter.paint(canvas, Size(receiptQrSize, receiptQrSize));
        canvas.restore();
        return receiptQrSize;
      },
    );
  }

  final double _height;
  final double Function(Canvas canvas, double y, double contentWidth) _paint;

  double height(double contentWidth) {
    if (_height > 0) {
      return _height;
    }
    return _measureHeight(contentWidth);
  }

  double paint(Canvas canvas, double y, double contentWidth) {
    return _paint(canvas, y, contentWidth);
  }

  double _measureHeight(double contentWidth) {
    final measureCanvas = Canvas(ui.PictureRecorder());
    return _paint(measureCanvas, 0, contentWidth);
  }
}
