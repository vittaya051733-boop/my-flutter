import 'dart:typed_data';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/services.dart';

///Simple helper used by the example app to send demo content to the printer.
class TestPrint {
    TestPrint({BlueThermalPrinter? printer})
            : bluetooth = printer ?? BlueThermalPrinter.instance;

    final BlueThermalPrinter bluetooth;

    Future<void> sample() async {
        final isConnected = await bluetooth.isConnected;
        if (isConnected != true) {
            throw StateError('Printer must be connected before printing.');
        }

        await bluetooth.printNewLine();
        await bluetooth.printCustom('Blue Thermal Printer', 3, 1);
        await bluetooth.printCustom('Sample Receipt', 2, 1);
        await bluetooth.printNewLine();

        await bluetooth.printLeftRight('Ticket', '#123456', 1);
        await bluetooth.printLeftRight('Date', DateTime.now().toString(), 1);
        await bluetooth.printNewLine();

        await bluetooth.print4Column('Qty', 'Item', 'Price', 'Total', 1);
        await bluetooth.print4Column('1', 'Coffee', '70', '70', 1);
        await bluetooth.print4Column('2', 'Sandwich', '90', '180', 1);
        await bluetooth.printNewLine();
        await bluetooth.printLeftRight('SUBTOTAL', '250', 2);
        await bluetooth.printLeftRight('VAT (7%)', '17.5', 2);
        await bluetooth.printLeftRight('TOTAL', '267.5', 2);
        await bluetooth.printNewLine();

        final logoBytes = await _loadLogoBytes();
        if (logoBytes != null) {
            await bluetooth.printImageBytes(logoBytes);
            await bluetooth.printNewLine();
        }

        await bluetooth.printCustom('Scan to reorder', 1, 1);
        await bluetooth.printQRcode('https://example.com/order/123456', 200, 200, 1);
        await bluetooth.printNewLine();
        await bluetooth.printCustom('*** Thank you ***', 2, 1);
        await bluetooth.printNewLine();
    }

    Future<Uint8List?> _loadLogoBytes() async {
        try {
            final bytes = await rootBundle.load('assets/images/yourlogo.png');
            return bytes.buffer.asUint8List();
        } catch (_) {
            return null;
        }
    }
}
