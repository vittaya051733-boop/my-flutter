import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/order_model.dart';
import 'models/user_profile.dart';
import 'models/shop_operations_settings.dart';
import 'utils/app_colors.dart';
import 'utils/rider_call_launcher.dart';
import 'test_order_helper.dart';
import 'order_qr_screen.dart';
import 'chat_room_screen.dart';
import 'services/shop_operations_service.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key, this.focusOrderId});

  final String? focusOrderId;

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  String? _shopId;
  ShopOperationsSettings _operationsSettings =
      ShopOperationsSettings.defaults();
  StreamSubscription<ShopOperationsSettings>? _operationsSubscription;
  final Set<String> _autoAcceptingOrders = <String>{};

  bool _shouldHideUnverifiedPromptPayOrder(Map<String, dynamic> data) {
    final paymentMethod = (data['paymentMethod'] as String?)?.trim() ?? '';
    final paymentStatus = (data['paymentStatus'] as String?)?.trim() ?? '';

    return paymentMethod == 'promptpay_qr' &&
        paymentStatus.isNotEmpty &&
        paymentStatus != 'verified';
  }

  bool _isAwaitingShopDecision(DetailedOrder order) {
    return order.status == 'accepted' &&
        order.preparingStartTime == null &&
        (order.driverId?.trim().isNotEmpty ?? false);
  }

  bool _hasRiderAcceptedOrder(Map<String, dynamic> data) {
    final status = (data['status'] as String?)?.trim() ?? '';
    final driverId = (data['driverId'] as String?)?.trim() ?? '';
    return driverId.isNotEmpty &&
        <String>{
          'accepted',
          'preparing',
          'ready',
          'delivering',
        }.contains(status);
  }

  bool _hasShopRejected(Map<String, dynamic> data) {
    final shopDecisionStatus =
        (data['shopDecisionStatus'] as String?)?.trim() ?? '';
    return shopDecisionStatus == 'rejected' || data['shopRejectedAt'] != null;
  }

  bool _isShopOrderForCurrentUser(Map<String, dynamic> data) {
    final shopId = (data['shopId'] as String?)?.trim();
    final shopOwnerId = (data['shopOwnerId'] as String?)?.trim();
    return shopId == _shopId || shopOwnerId == _shopId;
  }

  @override
  void initState() {
    super.initState();
    _loadShopId();
    // ไม่ต้องเริ่ม timer ตั้งแต่ต้น ให้ StreamBuilder จัดการ
  }

  @override
  void dispose() {
    _operationsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadShopId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _shopId = user.uid;
      });
      _listenOperationsSettings(user.uid);
    }
  }

  void _listenOperationsSettings(String shopId) {
    _operationsSubscription?.cancel();
    _operationsSubscription = ShopOperationsService.streamSettings(shopId)
        .listen((settings) {
          if (!mounted) return;
          setState(() => _operationsSettings = settings);
        });
  }

  Future<void> _createTestOrder() async {
    try {
      final orderId = await createTestOrder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ สร้างออเดอร์ทดสอบสำเร็จ: ${orderId.substring(0, 8)}...',
            ),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
            .where('shopOwnerId', isEqualTo: _shopId)
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
                  const Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ไม่มีออเดอร์ใหม่',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Shop ID: $_shopId',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final orders =
              snapshot.data!.docs
                  .where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _isShopOrderForCurrentUser(data) &&
                        !_shouldHideUnverifiedPromptPayOrder(data) &&
                        !_hasShopRejected(data) &&
                        _hasRiderAcceptedOrder(data);
                  })
                  .map(
                    (doc) => DetailedOrder.fromSnapshot(
                      doc as DocumentSnapshot<Map<String, dynamic>>,
                    ),
                  )
                  .toList()
                ..sort(
                  (a, b) => b.createdAt.compareTo(a.createdAt),
                ); // เรียงใน Dart แทน

          final focusOrderId = widget.focusOrderId;
          if (focusOrderId != null && focusOrderId.isNotEmpty) {
            orders.sort((a, b) {
              final aFocused = a.orderId == focusOrderId ? 1 : 0;
              final bFocused = b.orderId == focusOrderId ? 1 : 0;
              if (aFocused != bFocused) {
                return bFocused.compareTo(aFocused);
              }
              return b.createdAt.compareTo(a.createdAt);
            });
          }

          _maybeAutoAcceptAwaitingShopDecisionOrders(orders);

          final hasPauseBanner = _operationsSettings.pauseNewOrders;
          final itemCount = orders.length + (hasPauseBanner ? 1 : 0);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (hasPauseBanner) {
                if (index == 0) {
                  return _buildPauseBanner();
                }
                return _buildOrderCard(orders[index - 1]);
              }
              return _buildOrderCard(orders[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(DetailedOrder order) {
    final isFocused =
        widget.focusOrderId != null && widget.focusOrderId == order.orderId;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isFocused
            ? const BorderSide(color: AppColors.accent, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderHeader(order),
            const Divider(height: 24),
            _buildOrderItems(order),
            const SizedBox(height: 16),
            _buildAmountSummary(order),
            const SizedBox(height: 16),
            _buildOrderStatus(order),
            if (order.status == 'accepted' || order.status == 'preparing')
              _buildPreparingTimer(order),
            const SizedBox(height: 12),
            _buildOrderContactActions(order),
            const SizedBox(height: 12),
            _buildQrActions(order),
            const SizedBox(height: 16),
            _buildActionButtons(order),
          ],
        ),
      ),
    );
  }

  Widget _buildPauseBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.pause_circle_filled, color: Colors.orange, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'ร้านหยุดรับออเดอร์อยู่',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'เปิดรับออเดอร์อีกครั้งได้ที่เมนูตั้งค่า > การดำเนินงานร้าน',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _maybeAutoAcceptAwaitingShopDecisionOrders(List<DetailedOrder> orders) {
    if (!_operationsSettings.autoAcceptOrders ||
        _operationsSettings.pauseNewOrders) {
      return;
    }
    for (final order in orders) {
      if (!_isAwaitingShopDecision(order) ||
          _autoAcceptingOrders.contains(order.orderId)) {
        continue;
      }
      _autoAcceptingOrders.add(order.orderId);
      _acceptOrder(order, silent: true)
          .then((_) {
            if (!mounted) return;
            final shortId = order.orderId.length > 6
                ? order.orderId.substring(0, 6)
                : order.orderId;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('รับออเดอร์ #$shortId อัตโนมัติแล้ว'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          })
          .catchError((error) {
            debugPrint('Auto accept failed for ${order.orderId}: $error');
          })
          .whenComplete(() => _autoAcceptingOrders.remove(order.orderId));
    }
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
        ...order.items.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OrderItemImage(imageUrl: item.imageUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName.isNotEmpty ? item.productName : '-',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (item.toppings?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 3),
                        Text(
                          'ท็อปปิ้ง: ${item.toppings!.trim()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 3),
                      Text(
                        'ราคาต่อชิ้น ฿${item.price.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'x${item.quantity}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '฿${(item.price * item.quantity).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountSummary(DetailedOrder order) {
    final productSubtotal = _productSubtotal(order);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        children: [
          _AmountRow(label: 'ค่าสินค้า', value: productSubtotal),
          const SizedBox(height: 6),
          _AmountRow(label: 'ค่าส่ง', value: order.shippingFee),
          const Divider(height: 18),
          _AmountRow(label: 'ยอดรวม', value: order.totalAmount, isTotal: true),
        ],
      ),
    );
  }

  double _productSubtotal(DetailedOrder order) {
    final itemTotal = order.items.fold<double>(
      0,
      (runningTotal, item) => runningTotal + (item.price * item.quantity),
    );
    if (itemTotal > 0) return itemTotal;
    final fromGrandTotal = order.totalAmount - order.shippingFee;
    return fromGrandTotal > 0 ? fromGrandTotal : order.totalAmount;
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
        if (order.preparingStartTime == null) {
          statusColor = Colors.orange;
          statusText = 'ไรเดอร์รับงานแล้ว รอร้านยืนยัน';
        } else {
          statusColor = Colors.green;
          statusText = 'รับออเดอร์แล้ว';
        }
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
    final remaining =
        Duration(milliseconds: widget.order.preparingDuration) - elapsed;

    if (remaining.isNegative) {
      final overtime =
          elapsed - Duration(milliseconds: widget.order.preparingDuration);
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

class _OrderItemImage extends StatelessWidget {
  const _OrderItemImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 58,
        height: 58,
        color: const Color(0xFFE2E8F0),
        child: url == null || url.isEmpty
            ? const Icon(Icons.fastfood_outlined, color: Color(0xFF94A3B8))
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.fastfood_outlined,
                  color: Color(0xFF94A3B8),
                ),
              ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final double value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 15 : 14,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              color: isTotal ? Colors.black : const Color(0xFF92400E),
            ),
          ),
        ),
        Text(
          '฿${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: FontWeight.w800,
            color: isTotal ? AppColors.accent : const Color(0xFF92400E),
          ),
        ),
      ],
    );
  }
}

// ย้าย _buildActionButtons กลับไปที่ _OrderManagementScreenState
extension on _OrderManagementScreenState {
  Future<_RiderContactState> _loadRiderContactState(DetailedOrder order) async {
    final riderId = order.driverId?.trim();
    if (riderId == null || riderId.isEmpty) {
      return const _RiderContactState(profile: null, phone: null);
    }

    UserProfile? profile;
    Map<String, dynamic>? riderData;
    try {
      final riderDoc = await FirebaseFirestore.instance
          .collection('riders')
          .doc(riderId)
          .get();
      if (riderDoc.exists) {
        riderData = riderDoc.data();
        profile = UserProfile.fromMap(riderId, riderData);
      }
    } catch (_) {
      // Fallback profile is used when riders lookup fails.
    }

    profile ??= UserProfile(
      uid: riderId,
      displayName: (order.driverName?.trim().isNotEmpty ?? false)
          ? order.driverName!.trim()
          : 'ไรเดอร์',
      phoneNumber: null,
    );

    final phoneCandidates = <String?>[
      profile.phoneNumber,
      riderData?['phoneNumber'] as String?,
      riderData?['phone'] as String?,
      riderData?['contactPhone'] as String?,
      riderData?['mobile'] as String?,
    ];

    String? resolvedPhone;
    for (final candidate in phoneCandidates) {
      final text = candidate?.trim();
      if (text != null && text.isNotEmpty) {
        resolvedPhone = text;
        break;
      }
    }

    return _RiderContactState(profile: profile, phone: resolvedPhone);
  }

  Widget _buildOrderContactActions(DetailedOrder order) {
    return FutureBuilder<_RiderContactState>(
      future: _loadRiderContactState(order),
      builder: (context, snapshot) {
        final state = snapshot.data;
        final hasRider = order.driverId?.trim().isNotEmpty ?? false;
        final canChat = hasRider && state?.profile != null;
        final canCall = hasRider || (state?.phone?.trim().isNotEmpty ?? false);
        final riderName = state?.profile?.displayName.trim().isNotEmpty == true
            ? state!.profile!.displayName.trim()
            : (order.driverName?.trim().isNotEmpty == true
                  ? order.driverName!.trim()
                  : 'ไรเดอร์');
        final riderPhone = state?.phone?.trim().isNotEmpty == true
            ? state!.phone!.trim()
            : (order.driverPhone?.trim().isNotEmpty == true
                  ? order.driverPhone!.trim()
                  : '-');

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.delivery_dining_rounded,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'รายละเอียดไรเดอร์',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('ชื่อ: $riderName'),
                        Text('เบอร์โทร: $riderPhone'),
                        if (order.driverId?.trim().isNotEmpty == true)
                          Text(
                            'รหัสไรเดอร์: ${order.driverId!.trim()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: !canChat
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ChatRoomScreen(
                                    friendProfile: state!.profile!,
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('แชทไรเดอร์'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: !canCall
                          ? null
                          : () => RiderCallLauncher.startVoiceCall(
                              context: context,
                              riderProfile: state?.profile,
                              fallbackPhone: state?.phone,
                            ),
                      icon: const Icon(Icons.phone_in_talk_outlined),
                      label: Text(canCall ? 'โทรไรเดอร์' : 'โทรไรเดอร์ไม่ได้'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQrActions(DetailedOrder order) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderQRScreen(order: order),
                ),
              );
            },
            icon: const Icon(Icons.qr_code_2_rounded),
            label: const Text('แสดง QR'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
              minimumSize: const Size(double.infinity, 46),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => printOrderQr(context, order),
            icon: const Icon(Icons.print_outlined),
            label: const Text('พิมพ์ QR'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendOrderAppNotification({
    required String targetApp,
    required String? recipientUid,
    required String orderId,
    required String title,
    required String body,
    required String action,
  }) async {
    final toUid = recipientUid?.trim();
    if (toUid == null || toUid.isEmpty) {
      return;
    }

    await FirebaseFirestore.instance.collection('app_notifications').add({
      'targetApp': targetApp,
      'recipientUid': toUid,
      'orderId': orderId,
      'title': title,
      'body': body,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'source': 'van1_shop',
      'action': action,
    });
  }

  Widget _buildActionButtons(DetailedOrder order) {
    if (_isAwaitingShopDecision(order)) {
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
    }

    switch (order.status) {
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
        return const Text(
          'รอพนักงานขนส่งมารับสินค้า',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        );
      case 'delivering':
        return const Text(
          'กำลังจัดส่งสินค้า',
          style: TextStyle(
            fontSize: 14,
            color: Colors.blue,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _acceptOrder(DetailedOrder order, {bool silent = false}) async {
    try {
      final now = DateTime.now();
      final preparationMinutes = (order.preparingDuration / 60000)
          .ceil()
          .clamp(1, 240)
          .toDouble();
      final updatedOrder = order.copyWith(
        status: 'preparing',
        acceptedAt: now,
        preparingStartTime: now,
        notifications: {
          'firstWarning': NotificationStatus(
            sent: false,
            timeInMinutes: preparationMinutes * 0.5,
          ),
          'secondWarning': NotificationStatus(
            sent: false,
            timeInMinutes: preparationMinutes * 0.75,
          ),
          'finalWarning': NotificationStatus(
            sent: false,
            timeInMinutes: preparationMinutes,
          ),
        },
      );

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.orderId)
          .update({
            ...updatedOrder.toMap(),
            'shopDecisionStatus': 'accepted',
            'shopAcceptedAt': Timestamp.fromDate(now),
            'shopRejectedAt': FieldValue.delete(),
            'shopRejectedBy': FieldValue.delete(),
            'customerShopChoice': FieldValue.delete(),
            'customerShopWaitUntil': FieldValue.delete(),
            'customerShopWaitRequestedAt': FieldValue.delete(),
          });

      await _sendOrderAppNotification(
        targetApp: 'van3',
        recipientUid: order.driverId,
        orderId: order.orderId,
        title: 'ร้านรับออเดอร์แล้ว',
        body:
            'ออเดอร์ #${order.orderId.substring(0, 8)} ร้านเริ่มเตรียมสินค้าแล้ว',
        action: 'shop_accepted_order',
      );

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'รับออเดอร์เรียบร้อยแล้ว! เริ่มจับเวลาตามเวลาที่ตั้งไว้',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
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
            .update({
              'status': order.status == 'accepted' ? 'accepted' : 'pending',
              'shopDecisionStatus': 'rejected',
              'shopRejectedAt': FieldValue.serverTimestamp(),
              'shopRejectedBy': FirebaseAuth.instance.currentUser?.uid,
              'cancelReason': 'shop_rejected_waiting_customer_decision',
              'updatedAt': FieldValue.serverTimestamp(),
            });

        await _sendOrderAppNotification(
          targetApp: 'van3',
          recipientUid: order.driverId,
          orderId: order.orderId,
          title: 'ร้านปฏิเสธออเดอร์',
          body:
              'ออเดอร์ #${order.orderId.substring(0, 8)} รอลูกค้าเลือกรอหรือแคนเซิล',
          action: 'shop_rejected_order',
        );

        await _sendOrderAppNotification(
          targetApp: 'van2',
          recipientUid: order.customerId,
          orderId: order.orderId,
          title: 'ร้านค้าปฏิเสธออเดอร์',
          body: 'เลือกรออีก 15 นาทีหรือแคนเซิลออเดอร์ได้ในการ์ดออเดอร์',
          action: 'shop_rejected_order',
        );

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('ปฏิเสธออเดอร์แล้ว')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red,
            ),
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

      await _sendOrderAppNotification(
        targetApp: 'van3',
        recipientUid: order.driverId,
        orderId: order.orderId,
        title: 'ร้านเตรียมสินค้าเสร็จแล้ว',
        body:
            'ออเดอร์ #${order.orderId.substring(0, 8)} พร้อมให้ไรเดอร์รับสินค้า',
        action: 'shop_ready_for_pickup',
      );

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
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _RiderContactState {
  const _RiderContactState({required this.profile, required this.phone});

  final UserProfile? profile;
  final String? phone;
}
