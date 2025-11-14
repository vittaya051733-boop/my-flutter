import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'shop_registration_screen.dart';
import 'welcome_screen.dart';
import 'utils/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoAcceptOrders = false;
    Future<DocumentSnapshot?> _loadShopData(String userId) async {
      final collections = [
        'market_registrations',
        'shop_registrations',
        'restaurant_registrations',
        'pharmacy_registrations',
        'other_registrations',
      ];
    
      for (final collection in collections) {
        final doc = await FirebaseFirestore.instance.collection(collection).doc(userId).get();
        if (doc.exists) {
          return doc;
        }
      }
      return null;
    }

  bool _pauseNewOrders = false;
  bool _notifyNewOrders = true;
  bool _notifyLowStock = true;
  bool _emailDailyReports = false;
  bool _twoFactorEnabled = false;
  String _defaultPayoutAccount = 'ธนาคารกสิกรไทย ••3120';

  void _showBottomSheet({required String title, required Widget child}) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  void _showPayoutDetails() {
    _showBottomSheet(
      title: 'บัญชีรับเงินหลัก',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('บัญชีปัจจุบัน: $_defaultPayoutAccount'),
          const SizedBox(height: 12),
          const Text('➡️ สามารถเพิ่มบัญชีสำรอง หรือผูกกับ PromptPay เพื่อรับการโอนภายในวันเดียวกัน'),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check),
            label: const Text('รับทราบ'),
          ),
        ],
      ),
    );
  }

  void _showOperatingHours() {
    _showBottomSheet(
      title: 'ตั้งค่าเวลาเปิด-ปิดร้าน',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('ตัวอย่าง'),
          SizedBox(height: 8),
          Text('• จันทร์-ศุกร์ 08:00 - 20:00 น.'),
          Text('• เสาร์-อาทิตย์ 09:00 - 18:00 น.'),
          SizedBox(height: 12),
          Text('สามารถเพิ่มช่วงเวลาพิเศษ เช่น หยุดยาว หรือ Flash Sale ได้'),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 1.5,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเปลี่ยนรหัสผ่านได้สำหรับบัญชีนี้ (อาจเป็น Social Login)')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ส่งลิงก์เปลี่ยนรหัสผ่านไปที่ ${user.email} แล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmAndSignOut(User user) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการออกจากระบบ'),
        content: const Text('คุณต้องการออกจากระบบหรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('ยืนยัน')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final providers = user.providerData.map((p) => p.providerId).toSet();
      if (providers.contains('google.com')) {
        await GoogleSignIn().signOut();
        if (!context.mounted) return;
      }
      if (providers.contains('facebook.com')) {
        await FacebookAuth.instance.logOut();
        if (!context.mounted) return;
      }
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถออกจากระบบได้: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าและบัญชี'),
        // This removes the back button since it's a main tab screen.
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (user != null)
                    _buildSection(
                      title: 'บัญชีร้านค้า',
                      children: [
                        FutureBuilder<DocumentSnapshot?>(
                          future: _loadShopData(user.uid),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            String? shopImageUrl;
                            String? shopName;
                            String? shopType;
                            String? phone;
                            String? email;
                            String? description;
                            String? bookBankImageUrl;
                            double? lat;
                            double? lng;
                            DocumentSnapshot? shopDoc = snapshot.data;

                            if (shopDoc != null && shopDoc.exists) {
                              final data = shopDoc.data() as Map<String, dynamic>?;
                              shopImageUrl = data?['shopImageUrl'] as String?;
                              shopName = data?['name'] as String?;
                              shopType = data?['serviceType'] as String?;
                              phone = data?['phone']?.toString();
                              email = data?['email']?.toString();
                              description = data?['description']?.toString();
                              bookBankImageUrl = data?['bookBankImageUrl']?.toString();
                              final loc = data?['location'];
                              if (loc is Map) {
                                lat = (loc['latitude'] as num?)?.toDouble();
                                lng = (loc['longitude'] as num?)?.toDouble();
                              }
                            }

                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                                  child: Column(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          if (shopDoc != null && shopDoc.exists) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ShopRegistrationScreen(shopData: shopDoc),
                                              ),
                                            ).then((_) => setState(() {}));
                                          }
                                        },
                                        child: Stack(
                                          children: [
                                            CircleAvatar(
                                              radius: 42,
                                              backgroundColor: AppColors.accent,
                                              backgroundImage: shopImageUrl != null && shopImageUrl.isNotEmpty
                                                  ? NetworkImage(shopImageUrl)
                                                  : null,
                                              child: shopImageUrl == null || shopImageUrl.isEmpty
                                                  ? const Icon(Icons.storefront, size: 52, color: Colors.white)
                                                  : null,
                                            ),
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.accent,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.white, width: 2),
                                                ),
                                                child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        shopName ?? user.displayName ?? 'ร้านค้า',
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        shopType ?? user.email ?? user.phoneNumber ?? 'ไม่ได้ระบุข้อมูล',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 0),
                                // สรุปข้อมูลร้าน
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      if (description != null && description.isNotEmpty)
                                        ListTile(
                                          dense: true,
                                          leading: const Icon(Icons.notes_outlined),
                                          title: Text(description),
                                        ),
                                      if (phone != null && phone.isNotEmpty) const Divider(height: 0),
                                      if (phone != null && phone.isNotEmpty)
                                        ListTile(
                                          dense: true,
                                          leading: const Icon(Icons.phone_outlined),
                                          title: Text(phone),
                                        ),
                                      if (email != null && email.isNotEmpty) const Divider(height: 0),
                                      if (email != null && email.isNotEmpty)
                                        ListTile(
                                          dense: true,
                                          leading: const Icon(Icons.email_outlined),
                                          title: Text(email),
                                        ),
                                      if (lat != null && lng != null) const Divider(height: 0),
                                      if (lat != null && lng != null)
                                        ListTile(
                                          dense: true,
                                          leading: const Icon(Icons.location_on_outlined),
                                          title: Text('Lat: ${lat!.toStringAsFixed(6)}  Lng: ${lng!.toStringAsFixed(6)}'),
                                        ),
                                      if (bookBankImageUrl != null && bookBankImageUrl.isNotEmpty) const Divider(height: 0),
                                      if (bookBankImageUrl != null && bookBankImageUrl.isNotEmpty)
                                        ListTile(
                                          dense: true,
                                          leading: ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Image.network(
                                              bookBankImageUrl!,
                                              width: 44,
                                              height: 44,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          title: const Text('รูปสมุดบัญชี'),
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (_) => Dialog(
                                                child: InteractiveViewer(
                                                  child: Image.network(bookBankImageUrl!),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 0),
                                ListTile(
                                  leading: const Icon(Icons.edit_outlined),
                                  title: const Text('แก้ไขข้อมูลการลงทะเบียนร้าน'),
                                  subtitle: const Text('อัปเดตโลโก้ร้าน ที่อยู่ เบอร์โทร หมวดหมู่ และรายละเอียดทั้งหมด'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    if (shopDoc != null && shopDoc.exists) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ShopRegistrationScreen(shopData: shopDoc),
                                        ),
                                      ).then((_) => setState(() {}));
                                    } else {
                                      // ถ้ายังไม่มีข้อมูล ให้ไปหน้าลงทะเบียนใหม่
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const ShopRegistrationScreen(),
                                        ),
                                      ).then((_) => setState(() {}));
                                    }
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                        if (user.providerData.any((p) => p.providerId == 'password')) ...[
                          const Divider(height: 0),
                          ListTile(
                            leading: const Icon(Icons.security_outlined),
                            title: const Text('เปลี่ยนรหัสผ่าน'),
                            subtitle: const Text('แนะนำให้เปลี่ยนรหัสผ่านเป็นประจำเพื่อความปลอดภัย'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _showChangePasswordDialog,
                          ),
                        ],
                      ],
                    ),
                  _buildSection(
                    title: 'การดำเนินงานร้าน',
                    children: [
                      SwitchListTile(
                        value: _autoAcceptOrders,
                        onChanged: (value) => setState(() => _autoAcceptOrders = value),
                        title: const Text('รับออเดอร์อัตโนมัติ'),
                        subtitle: const Text('เมื่อมีคำสั่งซื้อใหม่ ระบบจะรับทันทีโดยไม่ต้องกดยืนยัน'),
                      ),
                      const Divider(height: 0),
                      SwitchListTile(
                        value: _pauseNewOrders,
                        onChanged: (value) => setState(() => _pauseNewOrders = value),
                        title: const Text('หยุดรับออเดอร์ใหม่ชั่วคราว'),
                        subtitle: const Text('ใช้เมื่อวัตถุดิบไม่เพียงพอ หรืออยู่ระหว่างพักร้าน'),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.schedule_outlined),
                        title: const Text('ตั้งเวลาเปิด-ปิดร้าน'),
                        subtitle: const Text('ตั้งเวลาปกติ วันหยุดนักขัตฤกษ์ หรือ Flash Sale'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showOperatingHours,
                      ),
                    ],
                  ),
                  _buildSection(
                    title: 'การแจ้งเตือนและรายงาน',
                    children: [
                      SwitchListTile(
                        value: _notifyNewOrders,
                        onChanged: (value) => setState(() => _notifyNewOrders = value),
                        title: const Text('แจ้งเตือนออเดอร์ใหม่'),
                        subtitle: const Text('ส่ง Push Notification ทุกครั้งที่มีคำสั่งซื้อเข้ามา'),
                      ),
                      const Divider(height: 0),
                      SwitchListTile(
                        value: _notifyLowStock,
                        onChanged: (value) => setState(() => _notifyLowStock = value),
                        title: const Text('เตือนสต๊อกใกล้หมด'),
                        subtitle: const Text('แจ้งเตือนเมื่อสินค้าเหลือ น้อยกว่า 5 ชิ้น'),
                      ),
                      const Divider(height: 0),
                      SwitchListTile(
                        value: _emailDailyReports,
                        onChanged: (value) => setState(() => _emailDailyReports = value),
                        title: const Text('สรุปรายงานยอดขายรายวันทางอีเมล'),
                        subtitle: const Text('สรุปยอดขาย ยอดเงินโอน และสินค้าเด่นในแต่ละวัน'),
                      ),
                    ],
                  ),
                  _buildSection(
                    title: 'การเงินและบัญชีรับเงิน',
                    children: [
                      ListTile(
                        leading: const Icon(Icons.account_balance_wallet_outlined),
                        title: const Text('บัญชีรับเงินหลัก'),
                        subtitle: Text('$_defaultPayoutAccount · โอนทุกวันทำการ'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showPayoutDetails,
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.analytics_outlined),
                        title: const Text('สรุปยอดและใบแจ้งหนี้'),
                        subtitle: const Text('ดาวน์โหลดใบแจ้งหนี้ย้อนหลังสูงสุด 12 เดือน'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () {},
                      ),
                    ],
                  ),
                  _buildSection(
                    title: 'ความปลอดภัย',
                    children: [
                      SwitchListTile(
                        value: _twoFactorEnabled,
                        onChanged: (value) => setState(() => _twoFactorEnabled = value),
                        title: const Text('เปิดการยืนยันตัวตน 2 ขั้นตอน'),
                        subtitle: const Text('ส่ง OTP เมื่อเข้าสู่ระบบจากอุปกรณ์ใหม่'),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.devices_other_outlined),
                        title: const Text('อุปกรณ์ที่เข้าสู่ระบบอยู่'),
                        subtitle: const Text('ตรวจสอบและยกเลิกอุปกรณ์ที่ไม่น่าไว้วางใจ'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {},
                      ),
                    ],
                  ),
                  _buildSection(
                    title: 'ศูนย์ช่วยเหลือและนโยบาย',
                    children: [
                      const ListTile(
                        leading: Icon(Icons.help_outline),
                        title: Text('ศูนย์ช่วยเหลือ Van Market'),
                        subtitle: Text('อ่านคู่มือการใช้งานและคำถามที่พบบ่อย'),
                        trailing: Icon(Icons.open_in_new),
                      ),
                      const Divider(height: 0),
                      const ListTile(
                        leading: Icon(Icons.policy_outlined),
                        title: Text('นโยบายความเป็นส่วนตัว'),
                        subtitle: Text('อัปเดตครั้งล่าสุด: 12 ตุลาคม 2025'),
                        trailing: Icon(Icons.open_in_new),
                      ),
                      const Divider(height: 0),
                      const ListTile(
                        leading: Icon(Icons.description_outlined),
                        title: Text('ข้อกำหนดการใช้บริการ'),
                        trailing: Icon(Icons.open_in_new),
                      ),
                      const Divider(height: 0),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Align(
                          alignment: Alignment.center,
                          child: TextButton(
                            onPressed: user == null ? null : () => _confirmAndSignOut(user),
                            child: Text(
                              'ออกจากระบบ',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
