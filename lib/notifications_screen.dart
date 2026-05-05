import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'models/order_model.dart';
import 'services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const String _targetApp = 'van1';
  User? _currentUser;
  final NotificationService _notificationService = NotificationService();

  bool _shouldHideUnverifiedPromptPayOrder(Map<String, dynamic> data) {
    final paymentMethod = (data['paymentMethod'] as String?)?.trim() ?? '';
    final paymentStatus = (data['paymentStatus'] as String?)?.trim() ?? '';

    return paymentMethod == 'promptpay_qr' &&
        paymentStatus.isNotEmpty &&
        paymentStatus != 'verified';
  }

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  Future<void> _markAppNotificationRead(String id) async {
    await _notificationService.markAppNotificationRead(id);
  }

  bool _isAwaitingShopDecisionData(Map<String, dynamic> data) {
    final status = (data['status'] as String?)?.trim() ?? '';
    return status == 'pending' ||
        (status == 'accepted' && data['preparingStartTime'] == null);
  }

  bool _isShopOrderForCurrentUser(Map<String, dynamic> data) {
    final shopId = (data['shopId'] as String?)?.trim();
    final shopOwnerId = (data['shopOwnerId'] as String?)?.trim();
    return shopId == _currentUser?.uid || shopOwnerId == _currentUser?.uid;
  }

  Future<void> _acceptOrderFromNotification({
    required DetailedOrder order,
    String? notificationId,
  }) async {
    try {
      await _notificationService.acceptShopOrder(
        order,
        notificationId: notificationId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('รับออเดอร์เรียบร้อยแล้ว')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _rejectOrderFromNotification({
    required DetailedOrder order,
    String? notificationId,
  }) async {
    try {
      await _notificationService.rejectShopOrder(
        order,
        notificationId: notificationId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ปฏิเสธออเดอร์แล้ว')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('การแจ้งเตือน'),
        automaticallyImplyLeading: false,
      ),
      body: _currentUser == null
          ? const Center(child: Text('กรุณาเข้าสู่ระบบเพื่อดูการแจ้งเตือน'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                  );
                }
                final orders =
                    (snapshot.data?.docs ??
                            <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                        .where((doc) {
                          final data = doc.data();
                          return _isShopOrderForCurrentUser(data) &&
                              !_shouldHideUnverifiedPromptPayOrder(data) &&
                              _isAwaitingShopDecisionData(data);
                        })
                        .toList(growable: false);

                orders.sort((a, b) {
                  final aTime =
                      (a.data()['timestamp'] as Timestamp?)
                          ?.millisecondsSinceEpoch ??
                      0;
                  final bTime =
                      (b.data()['timestamp'] as Timestamp?)
                          ?.millisecondsSinceEpoch ??
                      0;
                  return bTime.compareTo(aTime);
                });

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('app_notifications')
                      .where('targetApp', isEqualTo: _targetApp)
                      .where('recipientUid', isEqualTo: _currentUser!.uid)
                      .where('read', isEqualTo: false)
                      .snapshots(),
                  builder: (context, notifSnapshot) {
                    final notifs =
                        (notifSnapshot.data?.docs ??
                                <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                            .toList(growable: false);

                    notifs.sort((a, b) {
                      final aTime =
                          (a.data()['createdAt'] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          0;
                      final bTime =
                          (b.data()['createdAt'] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          0;
                      return bTime.compareTo(aTime);
                    });

                    if (orders.isEmpty && notifs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'ยังไม่มีการแจ้งเตือน',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.all(8),
                      children: [
                        for (final n in notifs) _buildNotificationCard(n),
                        for (final order in orders) _buildOrderCard(order),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildOrderCard(QueryDocumentSnapshot<Map<String, dynamic>> order) {
    final data = order.data();
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final formattedDate = timestamp != null
        ? DateFormat('d MMM y, HH:mm', 'th').format(timestamp)
        : 'ไม่มีข้อมูลเวลา';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ออเดอร์ใหม่ #${order.id.substring(0, 6)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('เวลา: $formattedDate'),
            Text('จำนวน: ${data['products']?.length ?? 0} รายการ'),
            Text(
              'ยอดรวม: ${data['totalPrice']?.toStringAsFixed(2) ?? 'N/A'} บาท',
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    final actionableOrder = await _notificationService
                        .loadActionableShopOrder(order.id);
                    if (!mounted || actionableOrder == null) return;
                    await _rejectOrderFromNotification(order: actionableOrder);
                  },
                  child: Text(
                    'ปฏิเสธ',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final actionableOrder = await _notificationService
                        .loadActionableShopOrder(order.id);
                    if (!mounted || actionableOrder == null) return;
                    await _acceptOrderFromNotification(order: actionableOrder);
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('รับออเดอร์'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    QueryDocumentSnapshot<Map<String, dynamic>> notificationDoc,
  ) {
    final data = notificationDoc.data();
    final action = (data['action'] as String?)?.trim();
    final orderId = (data['orderId'] as String?)?.trim() ?? '';

    if (action == 'order_accepted' && orderId.isNotEmpty) {
      return FutureBuilder<DetailedOrder?>(
        future: _notificationService.loadActionableShopOrder(orderId),
        builder: (context, snapshot) {
          final order = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (order == null) {
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.campaign_outlined,
                  color: Colors.orange,
                ),
                title: Text((data['title'] as String?) ?? 'แจ้งเตือน'),
                subtitle: Text((data['body'] as String?) ?? '-'),
                trailing: IconButton(
                  icon: const Icon(Icons.done),
                  onPressed: () => _markAppNotificationRead(notificationDoc.id),
                ),
              ),
            );
          }

          return _buildActionableNotificationOrderCard(
            order: order,
            notificationId: notificationDoc.id,
            title: (data['title'] as String?)?.trim(),
            body: (data['body'] as String?)?.trim(),
          );
        },
      );
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.campaign_outlined, color: Colors.orange),
        title: Text((data['title'] as String?) ?? 'แจ้งเตือน'),
        subtitle: Text((data['body'] as String?) ?? '-'),
        trailing: IconButton(
          icon: const Icon(Icons.done),
          onPressed: () => _markAppNotificationRead(notificationDoc.id),
        ),
      ),
    );
  }

  Widget _buildActionableNotificationOrderCard({
    required DetailedOrder order,
    required String notificationId,
    String? title,
    String? body,
  }) {
    final shortOrderId = order.orderId.substring(
      0,
      order.orderId.length >= 8 ? 8 : order.orderId.length,
    );

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title?.isNotEmpty == true ? title! : 'มีออเดอร์รอร้านยืนยัน',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (body?.isNotEmpty == true) ...<Widget>[
              const SizedBox(height: 8),
              Text(body!),
            ],
            const SizedBox(height: 12),
            Text('ออเดอร์ #$shortOrderId'),
            Text(
              'ลูกค้า: ${order.customerName.isNotEmpty ? order.customerName : '-'}',
            ),
            Text(
              'เบอร์ลูกค้า: ${order.customerPhone.isNotEmpty ? order.customerPhone : '-'}',
            ),
            Text(
              'จุดส่ง: ${order.customerAddress.isNotEmpty ? order.customerAddress : '-'}',
            ),
            Text('จำนวนสินค้า: ${order.totalItems} รายการ'),
            Text('ยอดรวม: ฿${order.totalAmount.toStringAsFixed(2)}'),
            if (order.items.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              const Text(
                'รายการสินค้า',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ...order.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${item.productName} x${item.quantity}'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _rejectOrderFromNotification(
                    order: order,
                    notificationId: notificationId,
                  ),
                  child: Text(
                    'ปฏิเสธ',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _acceptOrderFromNotification(
                    order: order,
                    notificationId: notificationId,
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('รับออเดอร์'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
