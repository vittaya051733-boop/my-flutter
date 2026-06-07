class AdminSupportTopic {
  const AdminSupportTopic({
    required this.key,
    required this.label,
  });

  final String key;
  final String label;

  static const String customKey = 'custom';
}

class AdminSupportConfig {
  const AdminSupportConfig({
    required this.sourceApp,
    required this.sourceLabel,
    required this.topics,
  });

  final String sourceApp;
  final String sourceLabel;
  final List<AdminSupportTopic> topics;
}

/// UID แอดมินสำหรับโทรในแอป (fallback ถ้า ticket ยังไม่มี assignedAdminUid)
const String kAdminSupportCalleeUid = '';

const AdminSupportConfig kVan1AdminSupportConfig = AdminSupportConfig(
  sourceApp: 'van1',
  sourceLabel: 'ร้านค้า',
  topics: <AdminSupportTopic>[
    AdminSupportTopic(
      key: 'shop_approval',
      label: 'การอนุมัติร้าน / เอกสารร้าน',
    ),
    AdminSupportTopic(
      key: 'product_listing',
      label: 'สินค้า / การลงขาย / AI ตรวจสินค้า',
    ),
    AdminSupportTopic(
      key: 'order_management',
      label: 'ปัญหาออเดอร์จากลูกค้า',
    ),
    AdminSupportTopic(
      key: 'payout_wallet',
      label: 'กระเป๋าเงิน / การโอน / เครดิต',
    ),
    AdminSupportTopic(
      key: 'printer_shipping',
      label: 'เครื่องพิมพ์ / การจัดส่ง / สต็อก',
    ),
    AdminSupportTopic(
      key: 'account_login',
      label: 'บัญชีร้าน / เข้าสู่ระบบ',
    ),
    AdminSupportTopic(
      key: 'app_bug',
      label: 'แจ้งข้อผิดพลาดแอป',
    ),
    AdminSupportTopic(
      key: AdminSupportTopic.customKey,
      label: 'อื่นๆ (พิมพ์หัวข้อเอง)',
    ),
  ],
);
