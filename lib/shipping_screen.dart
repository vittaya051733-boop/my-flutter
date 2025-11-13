import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

import 'utils/app_colors.dart';

class ShippingScreen extends StatefulWidget {
  const ShippingScreen({super.key});

  @override
  State<ShippingScreen> createState() => _ShippingScreenState();
}

class _ShippingScreenState extends State<ShippingScreen> {
  final BlueThermalPrinter printer = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isConnecting = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _getBondedDevices();
  }

  Future<void> _getBondedDevices() async {
    try {
      final devices = await printer.getBondedDevices();
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      // handle error
    }
  }

  Future<void> _disconnectPrinter() async {
    await printer.disconnect();
    setState(() {
      _isConnected = false;
      _selectedDevice = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ตัดการเชื่อมต่อเครื่องปริ้นแล้ว')),
    );
  }

  Future<void> _connectPrinter(BluetoothDevice device) async {
    setState(() => _isConnecting = true);
    await printer.connect(device);
    setState(() {
      _selectedDevice = device;
      _isConnecting = false;
      _isConnected = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('เชื่อมต่อกับ ${device.name} แล้ว')),
    );
  }

  void _printOrder(String qrData) async {
    if (_selectedDevice == null || !_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเชื่อมต่อเครื่องปริ้นก่อน')),
      );
      return;
    }
    if (_isConnecting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กำลังเชื่อมต่อเครื่องปริ้น กรุณารอสักครู่')),
      );
      return;
    }
    await printer.write('ข้อมูลออเดอร์:\n');
    await printer.write(qrData + '\n');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('สั่งพิมพ์ข้อมูลเรียบร้อย')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ตัวอย่างข้อมูลออเดอร์
    final orderInfo = {
      'orderId': 'ORDER123',
      'shopLat': 13.7563,
      'shopLng': 100.5018,
      'customerLat': 13.7000,
      'customerLng': 100.4000,
      'amount': 1500,
      'productName': 'สินค้า A',
      'status': 'shipping', // ตัวอย่างสถานะ: received, prepared, shipped, delivering, delivered
      'timestamp': DateTime.now().toIso8601String(),
    };
    // QR code เฉพาะพิกัดร้านและลูกค้า
    final qrData = '{"shopLat":${orderInfo['shopLat']},"shopLng":${orderInfo['shopLng']},"customerLat":${orderInfo['customerLat']},"customerLng":${orderInfo['customerLng']}}';

    // Roadmap ขั้นตอน
    final List<Map<String, dynamic>> steps = [
      {'label': 'รับออเดอร์', 'key': 'received', 'icon': Icons.assignment_turned_in},
      {'label': 'จัดเตรียมสินค้า', 'key': 'prepared', 'icon': Icons.inventory_2},
      {'label': 'จัดส่ง', 'key': 'shipped', 'icon': Icons.local_shipping},
      {'label': 'กำลังส่ง', 'key': 'delivering', 'icon': Icons.delivery_dining},
      {'label': 'ส่งสินค้าสำเร็จ', 'key': 'delivered', 'icon': Icons.check_circle},
    ];
    final currentStep = steps.indexWhere((s) => s['key'] == orderInfo['status']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('การจัดส่ง'),
        backgroundColor: AppColors.accent,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(_isConnected ? Icons.print : Icons.print_disabled),
            tooltip: _isConnected ? 'สั่งพิมพ์/ตัดการเชื่อมต่อ' : 'เชื่อมต่อเครื่องปริ้น',
            itemBuilder: (context) {
              final items = <PopupMenuEntry<String>>[];
              if (!_isConnected) {
                items.addAll(_devices.map((d) => PopupMenuItem(
                  value: d.address,
                  child: Text(d.name ?? d.address ?? 'Unknown'),
                )));
              } else {
                items.add(const PopupMenuItem(
                  value: 'print',
                  child: Text('สั่งพิมพ์ข้อมูล'),
                ));
                items.add(const PopupMenuItem(
                  value: 'disconnect',
                  child: Text('ตัดการเชื่อมต่อ'),
                ));
              }
              return items;
            },
            onSelected: (value) async {
              if (!_isConnected) {
                final device = _devices.firstWhere(
                  (d) => d.address == value,
                  orElse: () => _devices.first,
                );
                await _connectPrinter(device);
              } else if (value == 'print') {
                _printOrder(qrData);
              } else if (value == 'disconnect') {
                await _disconnectPrinter();
              }
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              // Roadmap Stepper
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(steps.length, (i) {
                    final step = steps[i];
                    final isActive = i <= currentStep;
                    return Row(
                      children: [
                        Column(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isActive ? AppColors.accent : Colors.grey[300],
                              child: Icon(step['icon'], color: isActive ? Colors.white : Colors.grey[500]),
                            ),
                            const SizedBox(height: 4),
                            Text(step['label'], style: TextStyle(fontSize: 13, color: isActive ? AppColors.accent : Colors.grey)),
                          ],
                        ),
                        if (i < steps.length - 1)
                          Container(
                            width: 40,
                            height: 2,
                            color: i < currentStep ? AppColors.accent : Colors.grey[300],
                          ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 18),
              const Text('QR Code สำหรับการจัดส่ง', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 220.0,
              ),
              const SizedBox(height: 24),
              // แสดงรายละเอียดสินค้า ราคา ชื่อสินค้า ใต้ QR
              Text('ชื่อสินค้า: ${orderInfo['productName']}', style: const TextStyle(fontSize: 16)),
              Text('ราคา: ${orderInfo['amount']} บาท', style: const TextStyle(fontSize: 16)),
              Text('Order ID: ${orderInfo['orderId']}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
              if (_isConnecting)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              if (_isConnected)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('เชื่อมต่อกับเครื่องปริ้นแล้ว', style: TextStyle(color: AppColors.accent)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
