import 'dart:typed_data';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/order_model.dart';
import '../widgets/merchant_print_options_sheet.dart';
import 'merchant_bluetooth_printer_service.dart';
import 'merchant_thermal_printer_service.dart';
import 'order_qr_receipt_bitmap.dart';
import 'order_qr_receipt_layout.dart';

const String orderQrReceiptTitle = 'แว๊นตลาด ORDER QR';

String orderQrCodeText(DetailedOrder order) {
  final code = order.orderCode?.trim();
  final orderCode = code != null && code.isNotEmpty ? code : '';
  return 'VAN_ORDER:${order.orderId}|$orderCode|${order.totalAmount.toStringAsFixed(2)}';
}

Future<void> printOrderQr(BuildContext context, DetailedOrder order) async {
  final universalQr = orderQrCodeText(order);
  final receiptLayout = buildOrderQrReceiptLayout(order);

  try {
    final receiptPng = await buildOrderQrReceiptPngBytes(
      qrPayload: universalQr,
      layout: receiptLayout,
      receiptTitle: orderQrReceiptTitle,
    );

    if (!context.mounted) return;
    final channel = await showMerchantPrintOptionsSheet(context);
    if (channel == null || !context.mounted) return;

    switch (channel) {
      case MerchantPrintChannel.bluetoothClassic:
        await _printReceiptViaBluetooth(context, receiptPng);
      case MerchantPrintChannel.bluetoothBle:
        await MerchantThermalPrinterService.instance.printViaBle(
          context,
          receiptPng,
        );
      case MerchantPrintChannel.wifi:
        await MerchantThermalPrinterService.instance.printViaWifi(
          context,
          receiptPng,
        );
      case MerchantPrintChannel.usb:
        await MerchantThermalPrinterService.instance.printViaUsb(
          context,
          receiptPng,
        );
      case MerchantPrintChannel.system:
        await _printReceiptViaSystemPrint(context, receiptPng);
    }
  } on PrinterUserException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }
}

Future<void> _printReceiptViaBluetooth(
  BuildContext context,
  Uint8List receiptPng,
) async {
  final printerService = MerchantBluetoothPrinterService.instance;
  final device = await printerService.resolvePrinterDevice(context);
  await printerService.connect(device);
  final printer = printerService.printer;

  await printer.printImageBytes(receiptPng);
  await _feedLines(printer, receiptTrailingBlankLines);
  await printer.paperCut();

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('พิมพ์ QR และรายละเอียดออเดอร์แล้ว')),
    );
  }
}

Future<void> _printReceiptViaSystemPrint(
  BuildContext context,
  Uint8List receiptPng,
) async {
  await Printing.layoutPdf(
    name: 'van_order_qr_receipt.pdf',
    format: _receiptPageFormat(receiptPng),
    onLayout: (_) => _buildReceiptPdfBytes(receiptPng),
  );

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'เปิดหน้าพิมพ์แล้ว — เลือกเครื่องพิมพ์ AirPrint หรือบันทึก PDF',
        ),
      ),
    );
  }
}

PdfPageFormat _receiptPageFormat(Uint8List receiptPng) {
  final decoded = img.decodePng(receiptPng);
  final pageWidth = 58 * PdfPageFormat.mm;
  if (decoded == null || decoded.width <= 0) {
    return PdfPageFormat(pageWidth, pageWidth * 2, marginAll: 0);
  }
  final pageHeight = pageWidth * decoded.height / decoded.width;
  return PdfPageFormat(pageWidth, pageHeight, marginAll: 0);
}

Future<Uint8List> _buildReceiptPdfBytes(Uint8List receiptPng) async {
  final format = _receiptPageFormat(receiptPng);
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.zero,
      build: (context) => pw.Image(
        pw.MemoryImage(receiptPng),
        fit: pw.BoxFit.fill,
      ),
    ),
  );
  return doc.save();
}

Future<void> _feedLines(BlueThermalPrinter printer, int count) async {
  for (var i = 0; i < count; i++) {
    await printer.printNewLine();
  }
}
