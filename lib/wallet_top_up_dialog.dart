import 'dart:async';
import 'dart:math';

import 'utils/io_platform.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'services/merchant_security_deposit_service.dart';
import 'services/promptpay_qr_payload.dart';

class WalletTopUpDialog extends StatefulWidget {
  const WalletTopUpDialog({
    super.key,
    this.initialAmount,
    this.minimumAmount,
    this.isSecurityDeposit = false,
  });

  final double? initialAmount;
  final double? minimumAmount;
  final bool isSecurityDeposit;

  @override
  State<WalletTopUpDialog> createState() => _WalletTopUpDialogState();
}

class _WalletTopUpDialogState extends State<WalletTopUpDialog> {
  static const List<double> _presets = <double>[500, 1000, 2000, 3000];
  static const double _maxTopUpAmount = 5000;

  final TextEditingController _customAmountController = TextEditingController();

  bool _loadingConfig = true;
  bool _isBusy = false;

  String? _promptPayNationalId;
  String? _recipientDisplayName;
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
      _promptPayNationalId = _resolvePromptPayId(data) ?? '1410400168710';
      final name = data['recipientDisplayName']?.toString().trim();
      _recipientDisplayName =
          name != null && name.isNotEmpty ? name : 'วิทยา ทนหงษา';
    } catch (_) {
      _promptPayNationalId = '1410400168710';
      _recipientDisplayName = 'วิทยา ทนหงษา';
    } finally {
      if (mounted) setState(() => _loadingConfig = false);
      _applyInitialAmountIfNeeded();
    }
  }

  void _applyInitialAmountIfNeeded() {
    final initial = widget.initialAmount;
    if (initial == null || initial <= 0 || !mounted) {
      return;
    }
    setState(() {
      _selectedAmount = initial.clamp(0, _maxTopUpAmount);
      _customAmountController.text = '';
    });
  }

  double? get _amount => _selectedAmount;

  String? _resolvePromptPayId(Map<String, dynamic> data) {
    const fallback = '1410400168710';

    String digitsOnly(String? raw) =>
        raw?.replaceAll(RegExp(r'\D'), '') ?? '';

    final nationalDigits = digitsOnly(
      data['promptPayNationalIdOrTaxId']?.toString(),
    );
    if (nationalDigits.length == 13) {
      return nationalDigits;
    }

    final phoneDigits = digitsOnly(data['promptPayPhoneNumber']?.toString());
    if (phoneDigits.length >= 9 && phoneDigits.length <= 10) {
      return phoneDigits;
    }

    if (nationalDigits.length >= 9 && nationalDigits.length <= 10) {
      return nationalDigits;
    }

    final fallbackDigits = digitsOnly(fallback);
    return fallbackDigits.length == 13 ? fallbackDigits : null;
  }

  String? _buildPromptPayPayload(double amount) {
    final promptPayId = _promptPayNationalId;
    if (promptPayId == null || promptPayId.isEmpty) {
      return null;
    }
    return PromptPayQrPayload.build(promptPayId: promptPayId, amount: amount);
  }

  bool get _canGeneratePromptPayQr {
    final amount = _amount;
    if (amount == null || amount <= 0) {
      return false;
    }
    return _buildPromptPayPayload(amount) != null;
  }

  void _selectPreset(double amount) {
    setState(() {
      _selectedAmount = amount.clamp(0, _maxTopUpAmount);
      _customAmountController.text = '';
    });
  }

  void _onCustomAmountChanged(String value) {
    final parsed = double.tryParse(value);
    setState(() {
      if (parsed == null || parsed <= 0) {
        _selectedAmount = null;
        return;
      }
      _selectedAmount = parsed > _maxTopUpAmount ? _maxTopUpAmount : parsed;
      if (parsed > _maxTopUpAmount) {
        _customAmountController.value = TextEditingValue(
          text: _maxTopUpAmount.toStringAsFixed(0),
          selection: TextSelection.collapsed(offset: _maxTopUpAmount.toStringAsFixed(0).length),
        );
      }
    });
  }

  Future<void> _pickSlipImage() async {
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
    if (amount > _maxTopUpAmount) {
      _showSnack('ยอดเติมสูงสุด ${_maxTopUpAmount.toStringAsFixed(0)} บาทต่อครั้ง');
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
      final bytes = await image.readAsBytes();
      await ref.putData(
        bytes,
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
        'expectedPromptPayId': _promptPayNationalId,
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

        if (widget.isSecurityDeposit) {
          final minimum = widget.minimumAmount ??
              MerchantSecurityDepositService.requiredAmountBaht;
          final paidEnough =
              verifiedAmount != null && verifiedAmount >= minimum;
          if (!paidEnough) {
            _showSnack(
              'ยอดที่ตรวจสอบได้ยังไม่ครบ ${minimum.toStringAsFixed(0)} บาท',
            );
            return;
          }
          await MerchantSecurityDepositService.instance.markPaid(
            uid: user.uid,
            amount: verifiedAmount,
          );
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
                child: kIsWeb
                    ? FutureBuilder<Uint8List>(
                        future: selectedSlipImage.readAsBytes(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          }
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                          );
                        },
                      )
                    : buildLocalFilePreviewFromXFile(
                        selectedSlipImage,
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

  Widget _buildTopUpAmountForm(double? amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'เลือกจำนวนเงิน',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        Text(
          'สูงสุด ${_maxTopUpAmount.toStringAsFixed(0)} บาทต่อครั้ง · ส่งสลิปได้ไม่เกิน 3 ครั้งต่อวัน',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in _presets)
              ChoiceChip(
                label: Text(preset.toStringAsFixed(0)),
                selected: amount == preset,
                onSelected: _isBusy ? null : (_) => _selectPreset(preset),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _customAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          enabled: !_isBusy,
          decoration: InputDecoration(
            labelText: 'กำหนดเอง',
            hintText: 'เช่น 1500 (สูงสุด ${_maxTopUpAmount.toStringAsFixed(0)})',
            border: const OutlineInputBorder(),
          ),
          onChanged: _onCustomAmountChanged,
        ),
      ],
    );
  }

  Widget _buildPromptPayQrCard({
    required double amount,
    required String nationalId,
    required String recipientName,
  }) {
    final amountLabel = amount.toStringAsFixed(2);
    final payload = _buildPromptPayPayload(amount);
    final maskedPromptPay = PromptPayQrPayload.maskedDisplayLabel(nationalId);

    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _ThaiQrPaymentBar(),
            const SizedBox(height: 10),
            const _PromptPayWordmark(),
            const SizedBox(height: 12),
            if (payload == null || payload.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Text('PromptPay ID ไม่ถูกต้อง'),
              )
            else
              SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    QrImageView(
                      data: payload,
                      size: 240,
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      backgroundColor: Colors.white,
                    ),
                    const _QrCenterAppLogo(),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'โอนให้ $recipientName',
              style: const TextStyle(
                color: Color(0xFF2D2D2D),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              maskedPromptPay,
              style: const TextStyle(
                color: Color(0xFF2D2D2D),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Amount $amountLabel Baht',
              style: const TextStyle(
                color: Color(0xFF2D2D2D),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGenerateQr = _canGeneratePromptPayQr;
    final amount = _amount;
    final nationalId = _promptPayNationalId;
    final recipientName = _recipientDisplayName ?? 'วิทยา ทนหงษา';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(widget.isSecurityDeposit ? 'เติมเครดิต — ค่าประกัน' : 'เติมเครดิต'),
        leading: IconButton(
          tooltip: 'ย้อนกลับ',
          icon: const Icon(Icons.arrow_back),
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: _loadingConfig
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.isSecurityDeposit) ...<Widget>[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFED7AA)),
                            ),
                            child: Text(
                              'ชำระค่าประกัน ${MerchantSecurityDepositService.requiredAmountBaht.toStringAsFixed(0)} บาท '
                              'ผ่านการเติมเครดิตและตรวจสลิปให้ผ่านก่อนเริ่มอัปโหลดสินค้า',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _buildTopUpAmountForm(amount),
                        const SizedBox(height: 18),
                        if (!canGenerateQr)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFFED7AA),
                              ),
                            ),
                            child: const Text(
                              'กรุณาเลือกจำนวนเงินเพื่อสร้าง QR',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          )
                        else
                          _buildPromptPayQrCard(
                            amount: amount!,
                            nationalId: nationalId!,
                            recipientName: recipientName,
                          ),
                        const SizedBox(height: 14),
                        _buildSlipPickerPanel(),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ThaiQrPaymentBar extends StatelessWidget {
  const _ThaiQrPaymentBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 32,
      color: const Color(0xFF0E55AA),
      alignment: Alignment.center,
      child: Image.asset(
        'assets/images/thai_qr_payment.png',
        package: 'promptpay_qrcode_generate',
        height: 25,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _PromptPayWordmark extends StatelessWidget {
  const _PromptPayWordmark();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/prompt_pay_logo.png',
      package: 'promptpay_qrcode_generate',
      height: 31,
      fit: BoxFit.contain,
    );
  }
}

class _QrCenterAppLogo extends StatelessWidget {
  const _QrCenterAppLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/app_logo.png',
        fit: BoxFit.cover,
      ),
    );
  }
}
