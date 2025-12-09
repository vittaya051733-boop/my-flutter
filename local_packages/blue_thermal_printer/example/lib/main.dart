import 'dart:async';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'testprint.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  MyAppState()
      : bluetooth = BlueThermalPrinter.instance,
        testPrint = TestPrint(printer: BlueThermalPrinter.instance);

  final BlueThermalPrinter bluetooth;
  final TestPrint testPrint;
  final List<BluetoothDevice> _devices = <BluetoothDevice>[];

  BluetoothDevice? _device;
  bool _connected = false;
  StreamSubscription<int?>? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _listenToState();
    _loadDevices();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }

  void _listenToState() {
    _stateSubscription = bluetooth.onStateChanged().listen((state) {
      if (!mounted) {
        return;
      }
      switch (state) {
        case BlueThermalPrinter.CONNECTED:
          setState(() => _connected = true);
          break;
        case BlueThermalPrinter.DISCONNECTED:
        case BlueThermalPrinter.DISCONNECT_REQUESTED:
        case BlueThermalPrinter.STATE_TURNING_OFF:
        case BlueThermalPrinter.STATE_OFF:
        case BlueThermalPrinter.STATE_TURNING_ON:
        case BlueThermalPrinter.STATE_ON:
        case BlueThermalPrinter.ERROR:
        default:
          setState(() => _connected = false);
          break;
      }
    });
  }

  Future<void> _loadDevices() async {
    bool connected = false;
    List<BluetoothDevice> devices = <BluetoothDevice>[];
    try {
      connected = await bluetooth.isConnected ?? false;
      devices = await bluetooth.getBondedDevices();
    } on PlatformException catch (err) {
      debugPrint('Unable to load bonded devices: $err');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _devices
        ..clear()
        ..addAll(devices);
      _connected = connected;
      if (_device == null && _devices.isNotEmpty) {
        _device = _devices.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blue Thermal Printer',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Blue Thermal Printer')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: <Widget>[
              _DevicePicker(
                devices: _devices,
                value: _device,
                onChanged: (device) => setState(() => _device = device),
              ),
              const SizedBox(height: 16),
              _ActionRow(
                connected: _connected,
                onRefresh: _loadDevices,
                onConnect: _connect,
                onDisconnect: _disconnect,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _connected ? _printSample : null,
                child: const Text('Print Test'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _connect() async {
    final target = _device;
    if (target == null) {
      await _showMessage('No device selected.');
      return;
    }

    try {
      await bluetooth.connect(target);
      setState(() => _connected = true);
    } catch (err) {
      setState(() => _connected = false);
      await _showMessage('Failed to connect: $err');
    }
  }

  Future<void> _disconnect() async {
    await bluetooth.disconnect();
    if (mounted) {
      setState(() => _connected = false);
    }
  }

  Future<void> _printSample() async {
    try {
      await testPrint.sample();
      await _showMessage('Sample sent to printer.');
    } on StateError catch (err) {
      await _showMessage(err.message);
    } catch (err) {
      await _showMessage('Unable to print: $err');
    }
  }

  Future<void> _showMessage(String message,
      {Duration duration = const Duration(seconds: 3)}) async {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
        ),
      );
  }
}

class _DevicePicker extends StatelessWidget {
  const _DevicePicker({
    required this.devices,
    required this.value,
    required this.onChanged,
  });

  final List<BluetoothDevice> devices;
  final BluetoothDevice? value;
  final ValueChanged<BluetoothDevice?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = _items();
    final currentValue = items.any((item) => item.value == value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Device', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButton<BluetoothDevice?>(
          isExpanded: true,
          hint: const Text('Select a device'),
          value: currentValue,
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  List<DropdownMenuItem<BluetoothDevice?>> _items() {
    if (devices.isEmpty) {
      return const <DropdownMenuItem<BluetoothDevice?>>[
        DropdownMenuItem<BluetoothDevice?>(
          value: null,
          child: Text('No paired devices found'),
        ),
      ];
    }
    return devices
        .map(
          (device) => DropdownMenuItem<BluetoothDevice?>(
            value: device,
            child: Text(device.name ?? device.address ?? 'Unknown device'),
          ),
        )
        .toList();
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.connected,
    required this.onRefresh,
    required this.onConnect,
    required this.onDisconnect,
  });

  final bool connected;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
          onPressed: () {
            onRefresh();
          },
          child: const Text('Refresh', style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(width: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: connected ? Colors.red : Colors.green,
          ),
          onPressed: () {
            if (connected) {
              onDisconnect();
            } else {
              onConnect();
            }
          },
          child: Text(
            connected ? 'Disconnect' : 'Connect',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
