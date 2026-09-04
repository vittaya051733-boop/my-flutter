import 'dart:io' show Platform;

import 'package:flutter/material.dart';

enum MerchantPrintChannel {
  bluetoothClassic,
  bluetoothBle,
  wifi,
  usb,
  system,
}

Future<MerchantPrintChannel?> showMerchantPrintOptionsSheet(
  BuildContext context,
) {
  final options = <_PrintOption>[
    if (Platform.isAndroid)
      const _PrintOption(
        channel: MerchantPrintChannel.bluetoothClassic,
        icon: Icons.bluetooth_connected_rounded,
        title: 'Bluetooth (จับคู่แล้ว)',
        subtitle: 'เครื่องพิมพ์ thermal ที่จับคู่ใน Settings',
      ),
    _PrintOption(
      channel: MerchantPrintChannel.bluetoothBle,
      icon: Icons.bluetooth_rounded,
      title: Platform.isIOS ? 'Bluetooth' : 'Bluetooth (BLE)',
      subtitle: Platform.isIOS
          ? 'เครื่องพิมพ์ BLE บน iPhone/iPad'
          : 'เครื่องพิมพ์ Bluetooth Low Energy',
    ),
    const _PrintOption(
      channel: MerchantPrintChannel.wifi,
      icon: Icons.wifi_rounded,
      title: 'Wi-Fi / Ethernet',
      subtitle: 'เชื่อมต่อ TCP port 9100',
    ),
    if (Platform.isAndroid)
      const _PrintOption(
        channel: MerchantPrintChannel.usb,
        icon: Icons.usb_rounded,
        title: 'USB (OTG)',
        subtitle: 'เครื่องพิมพ์เชื่อมสาย USB',
      ),
    _PrintOption(
      channel: MerchantPrintChannel.system,
      icon: Icons.print_rounded,
      title: Platform.isIOS ? 'AirPrint / บันทึก PDF' : 'พิมพ์ระบบ / AirPrint',
      subtitle: 'เลือกเครื่องพิมพ์จากระบบ',
    ),
  ];

  return showModalBottomSheet<MerchantPrintChannel>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'เลือกวิธีพิมพ์',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'รองรับเครื่องพิมพ์ thermal, Wi-Fi, USB (Android) และ AirPrint',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              ...options.map((option) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    leading: Icon(option.icon),
                    title: Text(option.title),
                    subtitle: Text(option.subtitle),
                    onTap: () =>
                        Navigator.of(sheetContext).pop(option.channel),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}

class _PrintOption {
  const _PrintOption({
    required this.channel,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final MerchantPrintChannel channel;
  final IconData icon;
  final String title;
  final String subtitle;
}
