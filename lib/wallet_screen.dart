import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'qr_scanner_screen.dart';
import 'package:flutter/services.dart';
import 'wallet_action_dialogs.dart';
import 'utils/app_colors.dart';


class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  // ...existing code...
  void _openQRScanner() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(),
      ),
    );
    if (result != null && result is String) {
      _handleScannedQRCode(result);
    }
  }

  void _handleScannedQRCode(String data) async {
    // Example: If QR contains 'pay:<amount>' or 'receive:<amount>'
    if (data.startsWith('pay:')) {
      final amount = double.tryParse(data.substring(4));
      if (amount != null && amount > 0) {
        // Deduct credit
        setState(() => _currentCredit -= amount);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('จ่ายเงิน $amount บาท สำเร็จ')),
        );
      }
    } else if (data.startsWith('receive:')) {
      final amount = double.tryParse(data.substring(8));
      if (amount != null && amount > 0) {
        // Add credit
        setState(() => _currentCredit += amount);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('รับเงิน $amount บาท สำเร็จ')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR ไม่ถูกต้อง: $data')),
      );
    }
  }
  final TextEditingController _creditController = TextEditingController();
  bool _isLoading = false;

  double _currentCredit = 0.0;
  String? _uid;

  Future<void> _fetchCurrentCredit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
  setState(() => _uid = user.uid);
    final snapshot = await FirebaseFirestore.instance
        .collection('credits')
        .where('uid', isEqualTo: user.uid)
        .get();
    double total = 0.0;
    for (final doc in snapshot.docs) {
      final amount = doc['amount'];
      if (amount is num) total += amount.toDouble();
    }
    setState(() => _currentCredit = total);
  }

  Future<void> _requestWithdraw() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')),
      );
      return;
    }
    await _fetchCurrentCredit();
    if (_currentCredit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คุณไม่มีเครดิตสำหรับถอนเงิน')),
      );
      return;
    }
    // Mock: ส่งคำขอถอนเงินไปยังบริษัท (ยังไม่มีบัญชีจริง)
    await FirebaseFirestore.instance.collection('withdraw_requests').add({
      'uid': user.uid,
      'amount': _currentCredit,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
      'companyBankAccount': null, // ยังไม่มีบัญชีบริษัท
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ส่งคำขอถอนเงินเรียบร้อย (รอบริษัทอนุมัติ)')),
    );
  }

  Future<void> _submitCredit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')),
      );
      return;
    }
    final credit = double.tryParse(_creditController.text);
    if (credit == null || credit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกจำนวนเครดิตที่ถูกต้อง')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('credits').add({
        'uid': user.uid,
        'amount': credit,
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกเครดิตเรียบร้อยแล้ว')),
      );
      _creditController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
  // ...existing code...
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? _uid ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_downward),
                      label: const Text('รับเงิน'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => ReceiveMoneyDialog(uid: uid),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_upward),
                      label: const Text('จ่ายเงิน'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => PayMoneyDialog(uid: uid),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.compare_arrows),
                      label: const Text('โอนเงิน'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => TransferMoneyDialog(uid: uid),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.money_off),
                      label: const Text('ถอนเงิน'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: _requestWithdraw,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Balance Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 4,
                      color: AppColors.accent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
                                const SizedBox(width: 12),
                                const Text('ยอดเงินคงเหลือ', style: TextStyle(fontSize: 18, color: Colors.white)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${_currentCredit.toStringAsFixed(2)} บาท',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text('UID: ', style: const TextStyle(color: Colors.white70)),
                                SelectableText(
                                  uid.length > 10
                                      ? uid.substring(0, 6) + '...' + uid.substring(uid.length - 4)
                                      : uid,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, color: Colors.white),
                                  tooltip: 'คัดลอก UID เต็ม',
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: uid));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('คัดลอก UID เรียบร้อย')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // QR & Scan Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  barrierDismissible: true,
                                  builder: (context) => GestureDetector(
                                    onTap: () => Navigator.of(context).pop(),
                                    child: Dialog(
                                      backgroundColor: Colors.transparent,
                                      child: Center(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(24),
                                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)],
                                          ),
                                          padding: const EdgeInsets.all(32),
                                          child: QrImageView(
                                            data: uid,
                                            size: 280.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                ),
                                padding: const EdgeInsets.all(12),
                                child: QrImageView(
                                  data: uid,
                                  size: 100.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text('QR รับเงิน', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.qr_code_scanner, size: 48, color: AppColors.accent),
                                onPressed: _openQRScanner,
                                tooltip: 'สแกน QR',
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text('สแกนจ่าย/รับเงิน', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Transaction History (พื้นหลังสีขาว)
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ประวัติธุรกรรม', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            // แสดงธุรกรรมจำลอง 3 รายการเสมอ
                            Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.arrow_downward, color: Colors.green),
                                  title: const Text('รับเงินจาก UID: userA'),
                                  subtitle: const Text('500 บาท'),
                                  trailing: const Text('10/11/2025'),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.arrow_upward, color: Colors.redAccent),
                                  title: const Text('จ่ายเงินให้ UID: userB'),
                                  subtitle: const Text('200 บาท'),
                                  trailing: const Text('09/11/2025'),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.compare_arrows, color: AppColors.accent),
                                  title: const Text('โอนเงินไป UID: userC'),
                                  subtitle: const Text('100 บาท'),
                                  trailing: const Text('08/11/2025'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // เพิ่มฟอร์มเติมเครดิตเพื่อให้ _isLoading และ _submitCredit ถูกใช้งาน
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('เติมเครดิต', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _creditController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'จำนวนเครดิต',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submitCredit,
                                child: _isLoading
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('บันทึกเครดิต'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
