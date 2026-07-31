import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'merchant_pricing_policy.dart';
import 'services/merchant_wallet_service.dart';
import 'utils/settlement_payout_support.dart';
import 'wallet_top_up_dialog.dart';
import 'wallet_withdraw_dialog.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const Color _dashboardOrangeTop = Color(0xFFFF9F1C);
  static const Color _dashboardOrangeMid = Color(0xFFFF6B00);
  static const Color _dashboardOrangeBottom = Color(0xFFFF5A00);
  static const Color _dashboardCream = Color(0xFFFFF0DF);
  static const Color _dashboardText = Color(0xFF2D2D2D);

  double _currentCredit = 0;
  String? _uid;
  MerchantWalletSnapshot? _walletSnapshot;

  @override
  void initState() {
    super.initState();
    _fetchCurrentCredit();
  }

  DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  String _formatTimestamp(Object? value) {
    final dt = _toDateTime(value);
    if (dt == null) return '';
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }

  DateTime? _orderDeliveredAt(Map<String, dynamic> data) {
    return _toDateTime(data['deliveredAt']) ??
        _toDateTime(data['deliveryCompletedAt']) ??
        _toDateTime(data['updatedAt']) ??
        _toDateTime(data['createdAt']);
  }

  bool _isDeliveredToday(Map<String, dynamic> data) {
    final deliveredAt = _orderDeliveredAt(data);
    if (deliveredAt == null) return false;
    final now = DateTime.now();
    return deliveredAt.year == now.year &&
        deliveredAt.month == now.month &&
        deliveredAt.day == now.day;
  }

  double _readProductRevenue(Map<String, dynamic> data) {
    return MerchantPricingPolicy.readMerchantProductRevenue(data);
  }

  Future<void> _fetchCurrentCredit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) setState(() => _uid = user.uid);

    final snapshot =
        await MerchantWalletService.instance.loadSnapshot(user.uid);
    if (!mounted) return;
    setState(() {
      _walletSnapshot = snapshot;
      _currentCredit = snapshot.totalCredit;
    });
  }

  Future<void> _refreshWalletSnapshot(String uid) async {
    final snapshot = await MerchantWalletService.instance.loadSnapshot(uid);
    if (!mounted) return;
    setState(() {
      _walletSnapshot = snapshot;
      _currentCredit = snapshot.totalCredit;
    });
  }

  Future<void> _promptTopUpAmount() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (context) => const WalletTopUpDialog(),
      ),
    );

    if (!mounted) return;
    if (result == true) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _refreshWalletSnapshot(uid);
      } else {
        await _fetchCurrentCredit();
      }
    }
  }

  Future<void> _onWithdrawPressed(MerchantWalletSnapshot snapshot) async {
    if (!snapshot.canWithdraw) {
      _showSnack('ยังไม่มียอด Omise ที่ถอนได้');
      return;
    }
    if (snapshot.withdrawableCredit <= 0) {
      _showSnack('ไม่มียอดที่ถอนได้');
      return;
    }

    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const WalletWithdrawDialog(actorType: 'merchant'),
    );

    if (!mounted || result == null) {
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _refreshWalletSnapshot(uid);
    }
    _showSnack(
      'ส่งคำขอถอน ${result.toStringAsFixed(2)} บาท — กำลังโอนเข้าบัญชี',
    );
  }

  Widget _buildWalletBalanceCard(MerchantWalletSnapshot snapshot, String uid) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 24,
        horizontal: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 32,
                    ),
                    SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'ยอดเครดิตคงเหลือ',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: FilledButton(
                  onPressed: _promptTopUpAmount,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _dashboardOrangeMid,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('เติมเครดิต'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${snapshot.totalCredit.toStringAsFixed(2)} บาท',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (!snapshot.canWithdraw) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ล็อกไว้ ${snapshot.lockedCredit.toStringAsFixed(2)} บาท',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'เครดิตที่เติมและยอด Omise ที่ยังไม่พร้อมถอน '
                    'จะถอนได้เมื่อยกเลิกสัญญาร้านแล้วเท่านั้น',
                    style: TextStyle(
                      color: _dashboardCream,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  if (snapshot.securityDepositAmount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'ค่าประกัน ${snapshot.securityDepositAmount.toStringAsFixed(0)} บาท',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'ถอนได้ทันที (Omise) ${snapshot.withdrawableCredit.toStringAsFixed(2)} บาท',
              style: const TextStyle(
                color: _dashboardCream,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: snapshot.canWithdraw && snapshot.withdrawableCredit > 0
                  ? () => _onWithdrawPressed(snapshot)
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: snapshot.canWithdraw && snapshot.withdrawableCredit > 0
                      ? Colors.white
                      : Colors.white38,
                ),
              ),
              child: Text(
                snapshot.canWithdraw && snapshot.withdrawableCredit > 0
                    ? 'ถอนเงิน'
                    : 'ถอนเงิน (ยังไม่มียอด Omise)',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'UID: ',
                style: TextStyle(color: Colors.white70),
              ),
              Expanded(
                child: SelectableText(
                  uid.length > 10
                      ? '${uid.substring(0, 6)}...${uid.substring(uid.length - 4)}'
                      : uid,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.copy,
                  color: Colors.white,
                ),
                tooltip: 'คัดลอก UID เต็ม',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: uid));
                  _showSnack('คัดลอก UID เรียบร้อย');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildTodayIncomeCard(String uid) {
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('shopOwnerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        var deliveredTodayCount = 0;
        var productRevenueToday = 0.0;

        final docs =
            snapshot.data?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        for (final doc in docs) {
          final data = doc.data();
          final status = data['status']?.toString().trim();
          if (status != 'delivered' || !_isDeliveredToday(data)) continue;
          deliveredTodayCount += 1;
          productRevenueToday += _readProductRevenue(data);
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.query_stats_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'รายได้สินค้าในวันนี้',
                      style: TextStyle(
                        color: _dashboardCream,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${productRevenueToday.toStringAsFixed(2)} บาท',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ส่งสำเร็จวันนี้ $deliveredTodayCount ออเดอร์',
                      style: const TextStyle(
                        color: _dashboardCream,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreditsHistory(String uid) {
    if (uid.isEmpty) return const Text('กรุณาเข้าสู่ระบบเพื่อดูประวัติ');

    final creditStream = FirebaseFirestore.instance
        .collection('credits')
        .where('uid', isEqualTo: uid)
        .snapshots();
    final orderStream = FirebaseFirestore.instance
        .collection('orders')
        .where('shopOwnerId', isEqualTo: uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: creditStream,
      builder: (context, creditSnapshot) {
        if (creditSnapshot.connectionState == ConnectionState.waiting &&
            !creditSnapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (creditSnapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('โหลดประวัติเครดิตไม่สำเร็จ'),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: orderStream,
          builder: (context, orderSnapshot) {
            if (orderSnapshot.connectionState == ConnectionState.waiting &&
                !orderSnapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (orderSnapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('โหลดประวัติออเดอร์ไม่สำเร็จ'),
              );
            }

            final items = <_WalletHistoryItem>[];
            final creditDocs =
                creditSnapshot.data?.docs ??
                const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            for (final doc in creditDocs) {
              final data = doc.data();
              final amount = _toDouble(data['amount']) ?? 0;
              final provider = data['provider']
                  ?.toString()
                  .trim()
                  .toLowerCase();
              final status = data['status']?.toString().trim().toLowerCase();
              final paymentGroupId = data['paymentGroupId']?.toString().trim();
              final slipFeedbackId = data['slipFeedbackId']?.toString().trim();
              final isTopUp = amount >= 0;

              var title = isTopUp ? 'เติมเครดิต' : 'หักเครดิต';
              if (provider == 'slipok' && status == 'verified') {
                title = 'เติมเครดิต (ตรวจสลิป)';
              } else if (provider != null && provider.isNotEmpty) {
                title = '$title ($provider)';
              }

              final subtitleParts = <String>[];
              if (paymentGroupId != null && paymentGroupId.isNotEmpty) {
                subtitleParts.add('รหัส: $paymentGroupId');
              }
              if (slipFeedbackId != null && slipFeedbackId.isNotEmpty) {
                subtitleParts.add('SlipOK: $slipFeedbackId');
              }

              items.add(
                _WalletHistoryItem(
                  title: title,
                  subtitle: subtitleParts.isEmpty
                      ? null
                      : subtitleParts.join(' • '),
                  amount: amount,
                  happenedAt: _toDateTime(data['timestamp']),
                  icon: isTopUp
                      ? Icons.add_circle_outline
                      : Icons.remove_circle_outline,
                  color: isTopUp ? Colors.green : Colors.redAccent,
                ),
              );
            }

            final orderDocs =
                orderSnapshot.data?.docs ??
                const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            for (final doc in orderDocs) {
              final data = doc.data();
              final status = data['status']?.toString().trim();
              if (status != 'delivered') continue;
              final productRevenue = _readProductRevenue(data);
              if (productRevenue <= 0) continue;
              final payoutInfo = readShopPayoutInfo(data);
              final payoutStatus = payoutInfo?.displayStatus ?? 'รอชำระ';
              final orderCode = data['orderCode']?.toString().trim();
              items.add(
                _WalletHistoryItem(
                  title: 'รายได้ค่าสินค้า',
                  subtitle: orderCode == null || orderCode.isEmpty
                      ? 'ออเดอร์ส่งสำเร็จ • $payoutStatus'
                      : 'ออเดอร์: $orderCode • $payoutStatus',
                  amount: productRevenue,
                  happenedAt: _orderDeliveredAt(data),
                  icon: Icons.shopping_bag_outlined,
                  color: _dashboardOrangeMid,
                  payoutStatus: payoutStatus,
                ),
              );
            }

            items.sort((a, b) {
              final at = a.happenedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bt = b.happenedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bt.compareTo(at);
            });

            final visibleItems = items.take(50).toList();
            if (visibleItems.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('ยังไม่มีรายการ'),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = visibleItems[index];
                final isPositive = item.amount >= 0;
                return ListTile(
                  leading: Icon(item.icon, color: item.color),
                  title: Text(item.title),
                  subtitle: item.subtitle == null ? null : Text(item.subtitle!),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item.amount.toStringAsFixed(2)} บาท',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPositive ? Colors.green : Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimestamp(item.happenedAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      if (item.payoutStatus != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.payoutStatus!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: item.payoutStatus == 'จ่ายแล้ว'
                                ? Colors.green.shade700
                                : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? _uid ?? '';
    final snapshot = _walletSnapshot;

    return Scaffold(
      backgroundColor: _dashboardOrangeMid,
      appBar: AppBar(
        title: const Text('กระเป๋าเงิน'),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_dashboardOrangeTop, _dashboardOrangeMid],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _dashboardOrangeTop,
              _dashboardOrangeMid,
              _dashboardOrangeBottom,
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (uid.isNotEmpty)
                        StreamBuilder<MerchantWalletSnapshot>(
                          stream: MerchantWalletService.instance
                              .watchSnapshot(uid),
                          builder: (context, walletSnapshot) {
                            final wallet = walletSnapshot.data ??
                                snapshot ??
                                MerchantWalletSnapshot(
                                  totalCredit: _currentCredit,
                                  withdrawableCredit: 0,
                                  lockedCredit: _currentCredit,
                                  canWithdraw: false,
                                  isContractCancelled: false,
                                  securityDepositAmount: 0,
                                );
                            return _buildWalletBalanceCard(wallet, uid);
                          },
                        )
                      else
                        _buildWalletBalanceCard(
                          snapshot ??
                              const MerchantWalletSnapshot(
                                totalCredit: 0,
                                withdrawableCredit: 0,
                                lockedCredit: 0,
                                canWithdraw: false,
                                isContractCancelled: false,
                                securityDepositAmount: 0,
                              ),
                          uid,
                        ),
                      const SizedBox(height: 12),
                      _buildTodayIncomeCard(uid),
                      const SizedBox(height: 24),
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ประวัติเติมเครดิตและรายได้ร้าน',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _dashboardText,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildCreditsHistory(uid),
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
      ),
    );
  }

}

class _WalletHistoryItem {
  const _WalletHistoryItem({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    this.subtitle,
    this.happenedAt,
    this.payoutStatus,
  });

  final String title;
  final String? subtitle;
  final double amount;
  final DateTime? happenedAt;
  final IconData icon;
  final Color color;
  final String? payoutStatus;
}
