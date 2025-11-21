import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/order_model.dart';
import 'utils/app_colors.dart';
import 'test_order_helper.dart';
import 'order_qr_screen.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  String? _shopId;

  @override
  void initState() {
    super.initState();
    _loadShopId();
    // ไม่ต้องเริ่ม timer ตั้งแต่ต้น ให้ StreamBuilder จัดการ
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadShopId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _shopId = user.uid;
      });
    }
  }

  Future<void> _createTestOrder() async {
    try {
      final orderId = await createTestOrder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ สร้างออเดอร์ทดสอบสำเร็จ: ${orderId.substring(0, 8)}...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shopId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการออเดอร์'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        actions: [
          // ปุ่มสร้างออเดอร์ทดสอบ
          IconButton(
            onPressed: _createTestOrder,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'สร้างออเดอร์ทดสอบ',
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('shopId', isEqualTo: _shopId)
            .where('status', whereIn: ['pending', 'accepted', 'preparing', 'ready', 'delivering'])
            // ลบ orderBy ออกชั่วคราว เพราะต้องสร้าง composite index ก่อน
            // .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // Debug: แสดง error ถ้ามี
          if (snapshot.hasError) {
            print('❌ Firestore Error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('ลองใหม่'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Debug: แสดงจำนวนเอกสาร
          print('📦 Orders found: ${snapshot.data?.docs.length ?? 0}');
          print('🔑 Current shopId: $_shopId');

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('ไม่มีออเดอร์ใหม่', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('Shop ID: $_shopId', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            );
          }

          final orders = snapshot.data!.docs
              .map((doc) => DetailedOrder.fromSnapshot(doc as DocumentSnapshot<Map<String, dynamic>>))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // เรียงใน Dart แทน

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              return _buildOrderCard(orders[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(DetailedOrder order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderHeader(order),
            const Divider(height: 24),
            _buildOrderItems(order),
            const SizedBox(height: 16),
            _buildOrderStatus(order),
            if (order.status == 'accepted' || order.status == 'preparing')
              _buildPreparingTimer(order),
            const SizedBox(height: 16),
            _buildActionButtons(order),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader(DetailedOrder order) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ออเดอร์ #${order.orderId.substring(0, 8)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                order.customerName,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              Text(
                order.customerPhone,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '฿${order.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
            Text(
              _formatTime(order.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderItems(DetailedOrder order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'รายการสินค้า:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...order.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Text('• ${item.productName}', style: const TextStyle(fontSize: 14)),
                  const Spacer(),
                  Text('x${item.quantity}', style: const TextStyle(fontSize: 14)),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildOrderStatus(DetailedOrder order) {
    Color statusColor;
    String statusText;

    switch (order.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'รออนุมัติ';
        break;
      case 'accepted':
        statusColor = Colors.green;
        statusText = 'รับออเดอร์แล้ว';
        break;
      case 'preparing':
        statusColor = Colors.blue;
        statusText = 'กำลังเตรียม';
        break;
      case 'ready':
        statusColor = Colors.purple;
        statusText = 'พร้อมส่ง';
        break;
      case 'delivering':
        statusColor = Colors.indigo;
        statusText = 'กำลังจัดส่ง';
        break;
      default:
        statusColor = Colors.grey;
        statusText = order.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor, width: 1.5),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: statusColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPreparingTimer(DetailedOrder order) {
    if (order.preparingStartTime == null) return const SizedBox.shrink();
    
    // ใช้ StatefulBuilder เพื่อ rebuild เฉพาะ widget นี้
    return _CountdownTimerWidget(order: order);
  }
}

/// Widget แยกสำหรับ Timer เพื่อไม่ให้ rebuild ทั้งหน้า
class _CountdownTimerWidget extends StatefulWidget {
  final DetailedOrder order;
  
  const _CountdownTimerWidget({required this.order});
  
  @override
  State<_CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<_CountdownTimerWidget> {
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    // Timer เฉพาะ widget นี้
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.order.preparingStartTime == null) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final elapsed = now.difference(widget.order.preparingStartTime!);
    final remaining = Duration(milliseconds: widget.order.preparingDuration) - elapsed;

    if (remaining.isNegative) {
      final overtime = elapsed - Duration(milliseconds: widget.order.preparingDuration);
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'เกินเวลา ${_formatDuration(overtime)} (ค่าปรับ: ฿${widget.order.penalty.toStringAsFixed(2)})',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Color timerColor = Colors.green;
    if (remaining.inMinutes < 3) {
      timerColor = Colors.red;
    } else if (remaining.inMinutes < 5) {
      timerColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: timerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: timerColor, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.timer, color: timerColor, size: 20),
          const SizedBox(width: 8),
          Text(
            'เหลือเวลา: ${_formatDuration(remaining)}',
            style: TextStyle(
              color: timerColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// ย้าย _buildActionButtons กลับไปที่ _OrderManagementScreenState
extension on _OrderManagementScreenState {
  Widget _buildActionButtons(DetailedOrder order) {
    switch (order.status) {
      case 'pending':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _acceptOrder(order),
                icon: const Icon(Icons.check_circle),
                label: const Text('รับออเดอร์'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _rejectOrder(order),
                icon: const Icon(Icons.cancel),
                label: const Text('ปฏิเสธ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        );
      case 'accepted':
      case 'preparing':
        return ElevatedButton.icon(
          onPressed: () => _markAsReady(order),
          icon: const Icon(Icons.done_all),
          label: const Text('เตรียมสินค้าเสร็จสิ้น'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
          ),
        );
      case 'ready':
        return Column(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderQRScreen(order: order),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code),
              label: const Text('แสดง QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'รอพนักงานขนส่งมารับสินค้า',
              style: TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        );
      case 'delivering':
        return const Text(
          'กำลังจัดส่งสินค้า',
          style: TextStyle(fontSize: 14, color: Colors.blue, fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _acceptOrder(DetailedOrder order) async {
    try {
      final now = DateTime.now();
      final updatedOrder = order.copyWith(
        status: 'preparing',
        acceptedAt: now,
        preparingStartTime: now,
        notifications: {
          'firstWarning': NotificationStatus(sent: false, timeInMinutes: 5),
          'secondWarning': NotificationStatus(sent: false, timeInMinutes: 7.5),
          'finalWarning': NotificationStatus(sent: false, timeInMinutes: 10),
        },
      );

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.orderId)
          .update(updatedOrder.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('รับออเดอร์เรียบร้อยแล้ว! เริ่มจับเวลา 10 นาที'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectOrder(DetailedOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการปฏิเสธออเดอร์'),
        content: const Text('คุณแน่ใจหรือไม่ว่าต้องการปฏิเสธออเดอร์นี้?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ปฏิเสธ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(order.orderId)
            .update({'status': 'cancelled', 'updatedAt': Timestamp.now()});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ปฏิเสธออเดอร์แล้ว')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _markAsReady(DetailedOrder order) async {
    try {
      final now = DateTime.now();
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.orderId)
          .update({
        'status': 'ready',
        'readyAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เตรียมสินค้าเสร็จสิ้น! รอพนักงานขนส่งมารับ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
