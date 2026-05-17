import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

class WalletTopUpDialog extends StatefulWidget {
  const WalletTopUpDialog({super.key});

  @override
  State<WalletTopUpDialog> createState() => _WalletTopUpDialogState();
}

class _WalletTopUpDialogState extends State<WalletTopUpDialog> {
  static const List<double> _presets = <double>[500, 1000, 2000, 3000];
  static const String _promptPayPurposeNote = 'เติม เครดิตร้านค้า';

  final TextEditingController _customAmountController = TextEditingController();

  bool _loadingConfig = true;
  bool _isBusy = false;

  String? _promptPayNationalId;
  double? _selectedAmount;
  XFile? _selectedSlipImage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPaymentConfig());
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentConfig() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('payment_config')
          .doc('collection')
          .get()
          .timeout(const Duration(seconds: 5));
      final data = snapshot.data() ?? const <String, dynamic>{};
      final value = data['promptPayNationalIdOrTaxId']?.toString().trim();
      _promptPayNationalId = value != null && value.isNotEmpty
          ? value
          : '1410400168710';
    } catch (_) {
      _promptPayNationalId = '1410400168710';
    } finally {
      if (mounted) setState(() => _loadingConfig = false);
    }
  }

  double? get _amount => _selectedAmount;

  bool get _canGeneratePromptPayQr {
    final amount = _amount;
    final nationalId = _promptPayNationalId;
    return amount != null &&
        amount > 0 &&
        nationalId != null &&
        nationalId.isNotEmpty;
  }

  void _selectPreset(double amount) {
    setState(() {
      _selectedAmount = amount;
      _customAmountController.text = '';
    });
  }

  void _onCustomAmountChanged(String value) {
    final parsed = double.tryParse(value);
    setState(
      () => _selectedAmount = parsed != null && parsed > 0 ? parsed : null,
    );
  }

  Future<void> _pickSlipImage() async {
    if (kIsWeb) {
      _showSnack('แนบสลิปบน Web ยังไม่รองรับ');
      return;
    }
    if (!_canGeneratePromptPayQr) {
      _showSnack('กรุณาเลือกจำนวนเงินก่อน');
      return;
    }

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (image == null || !mounted) return;
      setState(() => _selectedSlipImage = image);
    } catch (error) {
      _showSnack('เลือกสลิปไม่สำเร็จ: $error');
    }
  }

  Future<void> _verifySelectedSlip() async {
    if (kIsWeb) {
      _showSnack('แนบสลิปบน Web ยังไม่รองรับ');
      return;
    }

    final image = _selectedSlipImage;
    if (image == null) {
      _showSnack('กรุณาเลือกรูปสลิปก่อน');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('กรุณาเข้าสู่ระบบก่อน');
      return;
    }

    final amount = _amount;
    if (amount == null || amount <= 0) {
      _showSnack('กรุณาเลือกจำนวนเงินก่อน');
      return;
    }

    setState(() => _isBusy = true);
    try {
      const source = ImageSource.gallery;
      final paymentGroupId = _newPaymentGroupId(user.uid);
      final fileName = image.name.isNotEmpty ? image.name : 'slip.jpg';
      final contentType = _guessContentType(fileName);
      final objectPath = 'shops/${user.uid}/topups/$paymentGroupId/$fileName';

      await _ensureTopUpSlipDocExists(
        uid: user.uid,
        paymentGroupId: paymentGroupId,
        expectedAmount: amount,
        storagePath: objectPath,
        fileName: fileName,
        contentType: contentType,
        source: source,
      );

      final ref = FirebaseStorage.instance.ref().child(objectPath);
      await ref.putFile(
        File(image.path),
        SettableMetadata(contentType: contentType),
      );

      await _patchTopUpSlipDoc(
        uid: user.uid,
        paymentGroupId: paymentGroupId,
        patch: <String, dynamic>{
          'status': 'uploaded',
          'uploadedAt': FieldValue.serverTimestamp(),
        },
      );

      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('verifyTopUpSlip');
      final response = await callable.call(<String, dynamic>{
        'uid': user.uid,
        'expectedAmount': amount,
        'storagePath': objectPath,
        'bucket': Firebase.app().options.storageBucket,
        'paymentGroupId': paymentGroupId,
        'fileName': fileName,
        'contentType': contentType,
        'sourceApp': 'van1_merchant',
      });

      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      final success = data['success'] == true;
      final message = data['message']?.toString().trim();
      final verifiedAmount = data['verifiedAmount'] is num
          ? (data['verifiedAmount'] as num).toDouble()
          : null;
      final remainingAmount = data['remainingAmount'] is num
          ? (data['remainingAmount'] as num).toDouble()
          : null;
      final overpaidAmount = data['overpaidAmount'] is num
          ? (data['overpaidAmount'] as num).toDouble()
          : null;

      await _patchTopUpSlipDoc(
        uid: user.uid,
        paymentGroupId: paymentGroupId,
        patch: <String, dynamic>{
          'status': success ? 'verified' : 'failed',
          'verifiedAt': FieldValue.serverTimestamp(),
          'success': success,
          if (message != null && message.isNotEmpty) 'message': message,
          if (verifiedAmount != null) 'verifiedAmount': verifiedAmount,
          if (remainingAmount != null) 'remainingAmount': remainingAmount,
          if (overpaidAmount != null) 'overpaidAmount': overpaidAmount,
          'rawResponse': data,
        },
      );

      if (!mounted) return;
      if (success) {
        final details = <String>[];
        if (verifiedAmount != null) {
          details.add('เติมเครดิต ${verifiedAmount.toStringAsFixed(2)} บาท');
        }
        if (remainingAmount != null && remainingAmount > 0) {
          details.add(
            'คงเหลือต้องจ่ายอีก ${remainingAmount.toStringAsFixed(2)} บาท',
          );
        }
        if (overpaidAmount != null && overpaidAmount > 0) {
          details.add('จ่ายเกิน ${overpaidAmount.toStringAsFixed(2)} บาท');
        }

        final shouldContinueForRemaining = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ผลตรวจสลิป'),
            content: Text(
              [
                if (message != null && message.isNotEmpty) message,
                if (details.isNotEmpty) details.join('\n'),
              ].where((line) => line.trim().isNotEmpty).join('\n\n'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ปิด'),
              ),
              if (remainingAmount != null && remainingAmount > 0)
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('สร้าง QR ยอดคงเหลือ'),
                )
              else
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('ตกลง'),
                ),
            ],
          ),
        );

        if (!mounted) return;
        if (remainingAmount != null &&
            remainingAmount > 0 &&
            shouldContinueForRemaining == true) {
          setState(() {
            _selectedAmount = remainingAmount;
            _customAmountController.text = remainingAmount.toStringAsFixed(2);
            _selectedSlipImage = null;
          });
          _showSnack('สร้าง QR สำหรับยอดคงเหลือเรียบร้อย');
          return;
        }

        Navigator.of(context).pop(true);
      } else {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ผลตรวจสลิป'),
            content: Text(
              message?.isNotEmpty == true ? message! : 'ตรวจสลิปไม่สำเร็จ',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ตกลง'),
              ),
            ],
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      _showSnack(error.message ?? 'ตรวจสลิปไม่สำเร็จ');
    } catch (error) {
      _showSnack('ตรวจสลิปไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  DocumentReference<Map<String, dynamic>> _topUpSlipDocRef({
    required String uid,
    required String paymentGroupId,
  }) {
    return FirebaseFirestore.instance
        .collection('shop_topup_slips')
        .doc(uid)
        .collection('items')
        .doc(paymentGroupId);
  }

  Future<void> _ensureTopUpSlipDocExists({
    required String uid,
    required String paymentGroupId,
    required double expectedAmount,
    required String storagePath,
    required String fileName,
    required String contentType,
    required ImageSource source,
  }) async {
    try {
      final ref = _topUpSlipDocRef(uid: uid, paymentGroupId: paymentGroupId);
      final snap = await ref.get();
      if (snap.exists) return;
      await ref.set(<String, dynamic>{
        'uid': uid,
        'paymentGroupId': paymentGroupId,
        'expectedAmount': expectedAmount,
        'storagePath': storagePath,
        'fileName': fileName,
        'contentType': contentType,
        'source': source.name,
        'status': 'picked',
        'sourceApp': 'van1_merchant',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _patchTopUpSlipDoc({
    required String uid,
    required String paymentGroupId,
    required Map<String, dynamic> patch,
  }) async {
    try {
      final ref = _topUpSlipDocRef(uid: uid, paymentGroupId: paymentGroupId);
      await ref.set(<String, dynamic>{
        ...patch,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  String _newPaymentGroupId(String uid) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'shop_topup_${uid}_$stamp$rand';
  }

  String _guessContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildSlipPickerPanel() {
    final enabled = !_isBusy && _canGeneratePromptPayQr;
    final selectedSlipImage = _selectedSlipImage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'แนบสลิป',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: selectedSlipImage == null
                    ? 'เลือกจากแกลเลอรี'
                    : 'เปลี่ยนรูปสลิป',
                visualDensity: VisualDensity.compact,
                onPressed: enabled ? () => unawaited(_pickSlipImage()) : null,
                icon: const Icon(Icons.photo_library_outlined),
              ),
            ],
          ),
          if (selectedSlipImage != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: double.infinity,
                height: 160,
                child: Image.file(
                  File(selectedSlipImage.path),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: enabled ? _verifySelectedSlip : null,
                child: _isBusy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('ส่งสลิปเพื่อตรวจสอบ'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _twoDigitLength(int length) =>
      length < 10 ? '0$length' : '$length';

  static int _crc16CcittFalse(String data) {
    var crc = 0xFFFF;
    final bytes = utf8.encode(data);
    for (final byte in bytes) {
      var value = ((crc >> 8) ^ byte) & 0xFF;
      value ^= value >> 4;
      crc = ((crc << 8) ^ (value << 12) ^ (value << 5) ^ value) & 0xFFFF;
    }
    return crc;
  }

  static String _generatePromptPayPayload({
    required String promptPayId,
    required double amount,
    String? purposeNote,
  }) {
    if (promptPayId.length != 10 && promptPayId.length != 13) return '';

    const start = '000201';
    const acceptRecycle = '010211';
    const merchantInfo = '0016A000000677010111';
    final merchantInfoType = promptPayId.length == 10
        ? '2937$merchantInfo'
              '01130066${promptPayId.substring(1)}'
        : '2937$merchantInfo'
              '0213$promptPayId';
    const country = '5802TH';
    const currencyISO = '5303764';
    final amountText = amount.toStringAsFixed(2);
    final dataAmount = '54${_twoDigitLength(amountText.length)}$amountText';

    var additionalData = '';
    final note = purposeNote?.trim();
    if (note != null && note.isNotEmpty) {
      final noteByteLen = utf8.encode(note).length;
      final subField = '08${_twoDigitLength(noteByteLen)}$note';
      final subFieldByteLen = utf8.encode(subField).length;
      additionalData = '62${_twoDigitLength(subFieldByteLen)}$subField';
    }

    const checkSumTag = '6304';
    final payloadBeforeCrc =
        '$start$acceptRecycle$merchantInfoType$country$dataAmount$currencyISO$additionalData$checkSumTag';
    final crc = _crc16CcittFalse(
      payloadBeforeCrc,
    ).toRadixString(16).toUpperCase().padLeft(4, '0');
    return '$payloadBeforeCrc$crc';
  }

  @override
  Widget build(BuildContext context) {
    final canGenerateQr = _canGeneratePromptPayQr;
    final amount = _amount;
    final nationalId = _promptPayNationalId;
    final amountLabel = (amount ?? 0).toStringAsFixed(2);

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Text('เติมเครดิต'),
      content: SizedBox(
        width: 420,
        child: _loadingConfig
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.72,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('เลือกจำนวนเงิน'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final preset in _presets)
                            ChoiceChip(
                              label: Text(preset.toStringAsFixed(0)),
                              selected: amount == preset,
                              onSelected: _isBusy
                                  ? null
                                  : (_) => _selectPreset(preset),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        enabled: !_isBusy,
                        decoration: const InputDecoration(
                          labelText: 'กำหนดเอง',
                          hintText: 'เช่น 1500',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: _onCustomAmountChanged,
                      ),
                      const SizedBox(height: 14),
                      if (!canGenerateQr)
                        const Text('กรุณาเลือกจำนวนเงินเพื่อสร้าง QR')
                      else
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Center(
                              child: Container(
                                width: 240,
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  10,
                                  14,
                                  14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.black12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      height: 34,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0E55AA),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        'PromptPay',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: 170,
                                      height: 170,
                                      child: Builder(
                                        builder: (context) {
                                          final data =
                                              _generatePromptPayPayload(
                                                promptPayId: nationalId!,
                                                amount: amount!,
                                                purposeNote:
                                                    _promptPayPurposeNote,
                                              );
                                          if (data.isEmpty) {
                                            return const Center(
                                              child: Text(
                                                'PromptPay ID ไม่ถูกต้อง',
                                              ),
                                            );
                                          }
                                          return QrImageView(
                                            data: data,
                                            errorCorrectionLevel:
                                                QrErrorCorrectLevel.Q,
                                            backgroundColor: Colors.white,
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'ยอด $amountLabel บาท',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Account ($nationalId)',
                                      style: const TextStyle(fontSize: 12),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildSlipPickerPanel(),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(false),
          child: const Text('ปิด'),
        ),
      ],
    );
  }
}
