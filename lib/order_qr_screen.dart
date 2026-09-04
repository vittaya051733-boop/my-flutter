import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'models/order_model.dart';
import 'services/order_qr_printer_service.dart';
import 'services/order_qr_receipt_layout.dart';
import 'services/shop_order_voice_commands.dart';
import 'utils/app_colors.dart';

export 'services/order_qr_printer_service.dart'
    show orderQrCodeText, printOrderQr;

String orderQrOrderCode(DetailedOrder order) {
  final code = order.orderCode?.trim();
  return code != null && code.isNotEmpty ? code : '';
}

class OrderQRScreen extends StatefulWidget {
  const OrderQRScreen({
    super.key,
    required this.order,
    this.autoStartVoiceListening = false,
  });

  final DetailedOrder order;
  final bool autoStartVoiceListening;

  @override
  State<OrderQRScreen> createState() => _OrderQRScreenState();
}

class _OrderQRScreenState extends State<OrderQRScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _voiceReady = false;
  bool _voiceAvailable = false;
  bool _voiceSessionEnabled = false;
  bool _isListening = false;
  bool _hasAutoStartedVoice = false;
  bool _isHandlingVoiceCommand = false;
  String _voiceMessage = 'กดไมค์แล้วพูด ย้อนกลับ เพื่อกลับหน้าจัดการออเดอร์';
  String _lastVoiceText = '';

  @override
  void initState() {
    super.initState();
    unawaited(_initVoiceCommands());
    if (widget.autoStartVoiceListening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_maybeAutoStartVoiceListening());
      });
    }
  }

  @override
  void dispose() {
    _voiceSessionEnabled = false;
    unawaited(_speech.stop());
    unawaited(_speech.cancel());
    super.dispose();
  }

  Future<void> _initVoiceCommands() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
            if (_voiceSessionEnabled && !_isHandlingVoiceCommand) {
              unawaited(_startVoiceListening());
            }
          }
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _voiceMessage = 'ไมค์ยังฟังไม่ได้ ลองกดไมค์อีกครั้ง';
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _voiceAvailable = available;
        _voiceReady = true;
        _voiceMessage = available
            ? _voiceMessage
            : 'ไม่พบระบบรับเสียงของเครื่อง';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _voiceReady = true;
        _voiceAvailable = false;
        _voiceMessage = 'เปิดระบบเสียงไม่สำเร็จ';
      });
    }
  }

  Future<void> _maybeAutoStartVoiceListening() async {
    if (_hasAutoStartedVoice || !_voiceReady || !_voiceAvailable) return;
    final granted = await _ensureMicrophonePermission();
    if (!granted || !mounted) return;
    _hasAutoStartedVoice = true;
    await _toggleVoiceSession();
  }

  Future<bool> _ensureMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final requested = await Permission.microphone.request();
    if (requested.isGranted) return true;
    if (!mounted) return false;
    setState(() {
      _voiceMessage = requested.isPermanentlyDenied
          ? 'กรุณาเปิดสิทธิ์ไมค์ในตั้งค่าเครื่อง'
          : 'ต้องอนุญาตไมค์ก่อนใช้คำสั่งเสียง';
    });
    return false;
  }

  Future<void> _toggleVoiceSession() async {
    if (_voiceSessionEnabled || _isListening) {
      _voiceSessionEnabled = false;
      await _speech.stop();
      await _speech.cancel();
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _voiceMessage = 'ปิดการฟังคำสั่งเสียงแล้ว';
      });
      return;
    }

    if (!_voiceReady) {
      await _initVoiceCommands();
    }
    if (!_voiceAvailable) {
      if (!mounted) return;
      setState(() => _voiceMessage = 'ไม่พบระบบรับเสียงของเครื่อง');
      return;
    }

    final granted = await _ensureMicrophonePermission();
    if (!granted) return;

    _voiceSessionEnabled = true;
    await _startVoiceListening();
  }

  Future<void> _startVoiceListening() async {
    if (!mounted || !_voiceSessionEnabled || _isHandlingVoiceCommand) return;
    if (_isListening) return;

    final started = await _speech.listen(
      onResult: (result) {
        _handleVoiceResult(
          result.recognizedWords,
          isFinal: result.finalResult,
        );
      },
      localeId: 'th_TH',
      listenMode: stt.ListenMode.confirmation,
      partialResults: true,
      cancelOnError: true,
    );

    if (!mounted) return;
    setState(() {
      _isListening = started;
      _voiceMessage = started
          ? 'พูด ย้อนกลับ เพื่อกลับหน้าจัดการออเดอร์'
          : 'เปิดไมค์ไม่สำเร็จ ลองอีกครั้ง';
    });
  }

  void _handleVoiceResult(String words, {required bool isFinal}) {
    if (!mounted || _isHandlingVoiceCommand) return;
    final heardText = words.trim();
    if (heardText.isEmpty) return;

    final isBack = ShopOrderVoiceCommands.matchBackNavigation(heardText);
    if (!isFinal) {
      setState(() {
        _lastVoiceText = heardText;
        _voiceMessage = isBack
            ? 'ได้ยิน: ย้อนกลับ'
            : 'กำลังฟัง... (พูด ย้อนกลับ)';
      });
      if (isBack) {
        unawaited(_popWithVoiceFeedback(heardText));
      }
      return;
    }

    if (!isBack) {
      setState(() {
        _lastVoiceText = heardText;
        _voiceMessage = 'ได้ยิน: $heardText — ลองพูด ย้อนกลับ';
      });
      return;
    }

    unawaited(_popWithVoiceFeedback(heardText));
  }

  Future<void> _popWithVoiceFeedback(String heardText) async {
    if (!mounted || _isHandlingVoiceCommand) return;
    _isHandlingVoiceCommand = true;
    _voiceSessionEnabled = false;
    await _speech.stop();
    await _speech.cancel();
    if (!mounted) return;
    setState(() {
      _lastVoiceText = heardText;
      _isListening = false;
      _voiceMessage = 'กำลังย้อนกลับ...';
    });
    Navigator.of(context).pop();
  }

  String _qrPayload(String type) {
    if (type == 'VAN_ORDER') return orderQrCodeText(widget.order);
    return '$type:${widget.order.orderId}|${orderQrOrderCode(widget.order)}|${widget.order.totalAmount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final universalQr = _qrPayload('VAN_ORDER');

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code สำหรับไรเดอร์'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () => printOrderQr(context, widget.order),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('พิมพ์ QR พร้อมรายละเอียดออเดอร์'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QrPayloadCard(
                    title: 'QR เดียวสำหรับออเดอร์นี้',
                    subtitle: 'สแกน QR เดียวตามสถานะออเดอร์',
                    icon: Icons.qr_code_2_rounded,
                    color: AppColors.accent,
                    payload: universalQr,
                  ),
                  const SizedBox(height: 16),
                  _OrderQrDetails(order: widget.order),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: <Widget>[
                  IconButton.filledTonal(
                    onPressed: _voiceReady ? _toggleVoiceSession : null,
                    icon: Icon(
                      _voiceSessionEnabled || _isListening
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded,
                    ),
                    tooltip: _voiceSessionEnabled
                        ? 'หยุดฟังคำสั่งเสียง'
                        : 'เริ่มฟังคำสั่งเสียง',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _voiceMessage,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (_lastVoiceText.isNotEmpty)
                          Text(
                            'ได้ยิน: $_lastVoiceText',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrPayloadCard extends StatelessWidget {
  const _QrPayloadCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.payload,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String payload;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
              ),
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 300,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: color),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              payload,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderQrDetails extends StatelessWidget {
  const _OrderQrDetails({required this.order});

  final DetailedOrder order;

  @override
  Widget build(BuildContext context) {
    final layout = buildOrderQrReceiptLayout(order);

    return Card(
      color: const Color(0xFFFFFBEB),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ข้อมูลที่ใช้ตรวจ QR',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text('Order ID: ${layout.orderId}'),
            Text('เลขออเดอร์: ${layout.orderCode.isEmpty ? '-' : layout.orderCode}'),
            Text('วันที่: ${layout.dateTimeText}'),
            const SizedBox(height: 8),
            const Text(
              'รายการสินค้า',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            _AmountRow(
              label: 'ค่าสินค้า',
              value: formatOrderQrMoney(layout.productSubtotal),
            ),
            const SizedBox(height: 4),
            ...layout.items.expand((item) {
              final rows = <Widget>[
                _AmountRow(
                  label: '${item.name} x${item.quantity}',
                  value: formatOrderQrMoney(item.lineTotal),
                ),
              ];
              final toppings = item.toppings;
              if (toppings != null) {
                rows.add(
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
                    child: Text(
                      'ท็อปปิ้ง: $toppings',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                );
              }
              return rows;
            }),
            const SizedBox(height: 6),
            _AmountRow(
              label: 'ค่าส่ง',
              value: formatOrderQrMoney(layout.shippingFee),
            ),
            _AmountRow(
              label: 'ยอดรวม',
              value: formatOrderQrMoney(layout.grandTotal),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 8),
          Text(value, style: style),
        ],
      ),
    );
  }
}
