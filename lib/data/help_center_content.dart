class HelpArticle {
  const HelpArticle({
    required this.id,
    required this.categoryKey,
    required this.titleTh,
    required this.titleEn,
    required this.bodyTh,
    this.bodyEn = '',
    this.popular = false,
  });

  final String id;
  final String categoryKey;
  final String titleTh;
  final String titleEn;
  final String bodyTh;
  final String bodyEn;
  final bool popular;
}

class HelpCategory {
  const HelpCategory({
    required this.key,
    required this.labelTh,
    required this.labelEn,
    required this.iconName,
  });

  final String key;
  final String labelTh;
  final String labelEn;
  final String iconName;
}

class HelpCenterContent {
  HelpCenterContent._();

  static const List<HelpCategory> categories = <HelpCategory>[
    HelpCategory(
      key: 'shop_setup',
      labelTh: 'เปิดร้าน / ตั้งค่าร้าน',
      labelEn: 'Shop setup',
      iconName: 'store',
    ),
    HelpCategory(
      key: 'products',
      labelTh: 'สินค้า / การลงขาย',
      labelEn: 'Products',
      iconName: 'inventory',
    ),
    HelpCategory(
      key: 'orders',
      labelTh: 'ออเดอร์ / จัดส่ง',
      labelEn: 'Orders & delivery',
      iconName: 'receipt',
    ),
    HelpCategory(
      key: 'wallet',
      labelTh: 'รายได้ / กระเป๋าเงิน',
      labelEn: 'Earnings & wallet',
      iconName: 'payment',
    ),
    HelpCategory(
      key: 'account',
      labelTh: 'บัญชี / เข้าสู่ระบบ',
      labelEn: 'Account',
      iconName: 'account',
    ),
    HelpCategory(
      key: 'app_bug',
      labelTh: 'แจ้งปัญหาแอป',
      labelEn: 'App issues',
      iconName: 'bug',
    ),
  ];

  static const List<HelpArticle> articles = <HelpArticle>[
    HelpArticle(
      id: 'register_shop',
      categoryKey: 'shop_setup',
      titleTh: 'ลงทะเบียนร้านอย่างไร?',
      titleEn: 'How do I register my shop?',
      bodyTh:
          '1) สมัครบัญชีและยืนยันอีเมล\n2) กรอกข้อมูลร้าน ที่อยู่ และเอกสารที่ระบบขอ\n3) รอแอดมินอนุมัติ — ตรวจสอบสถานะได้ในหน้าตั้งค่า\n4) เมื่ออนุมัติแล้ว เริ่มเพิ่มสินค้าและเปิดรับออเดอร์ได้',
      popular: true,
    ),
    HelpArticle(
      id: 'operating_hours',
      categoryKey: 'shop_setup',
      titleTh: 'ตั้งเวลาเปิด-ปิดร้าน',
      titleEn: 'Set shop operating hours',
      bodyTh:
          'ไปที่ ตั้งค่า → จัดการร้าน → เวลาเปิด-ปิด\nกำหนดวันและเวลาที่ร้านรับออเดอร์\nลูกค้าจะเห็นสถานะเปิด/ปิดตามที่ตั้งไว้',
      popular: true,
    ),
    HelpArticle(
      id: 'add_product',
      categoryKey: 'products',
      titleTh: 'เพิ่มสินค้าอย่างไร?',
      titleEn: 'How do I add a product?',
      bodyTh:
          '1) กดเพิ่มสินค้า อัปโหลดรูปหรือวิดีโอ\n2) กรอกชื่อ ราคา และข้อมูลจำเพาะ (ท็อปปิ้ง สี ขนาด หน่วย)\n3) กดวิเคราะห์ AI เพื่อช่วยกรอกหมวดหมู่ ภาษี หน่วย และขนาดพัสดุ\n4) บันทึก — สินค้าบางประเภทอาจรอแอดมินตรวจสอบ',
      popular: true,
    ),
    HelpArticle(
      id: 'ai_product',
      categoryKey: 'products',
      titleTh: 'AI วิเคราะห์สินค้าทำอะไร?',
      titleEn: 'What does AI product analysis do?',
      bodyTh:
          'AI ช่วยประเมินชื่อสินค้า หมวดหมู่ ภาษี ความถูกกฎหมาย\nหน่วยขาย (ชิ้น/ถุง/แพ็ค/มัด/ลูก/กล่อง) และขนาดพัสดุส่งทั่วประเทศ\nตรวจสอบและแก้ไขก่อนบันทึกเสมอ',
      popular: true,
    ),
    HelpArticle(
      id: 'discount',
      categoryKey: 'products',
      titleTh: 'ตั้งส่วนลดสินค้า',
      titleEn: 'Set product discounts',
      bodyTh:
          'ไปที่ จัดการร้าน → เลือกสินค้า → ตั้งส่วนลด %\nราคาที่ลูกค้าเห็นจะหักส่วนลดอัตโนมัติ\nรายได้ร้านคำนวณจากราคาหลังหักส่วนลด',
    ),
    HelpArticle(
      id: 'manage_orders',
      categoryKey: 'orders',
      titleTh: 'จัดการออเดอร์อย่างไร?',
      titleEn: 'How do I manage orders?',
      bodyTh:
          '1) รับแจ้งเตือนเมื่อมีออเดอร์ใหม่\n2) กดรับออเดอร์และเตรียมสินค้า\n3) อัปเดตสถานะ (เตรียมเสร็จ/ส่งมอบไรเดอร์) ให้ตรงเวลา\n4) ตรวจสอบรายละเอียดและแชทกับลูกค้าได้ในหน้าออเดอร์',
      popular: true,
    ),
    HelpArticle(
      id: 'nationwide_shipping',
      categoryKey: 'orders',
      titleTh: 'ส่งทั่วประเทศตั้งค่าอย่างไร?',
      titleEn: 'Nationwide shipping setup',
      bodyTh:
          'เมื่อเพิ่มสินค้า เปิดตัวเลือกส่งทั่วประเทศและกรอกขนาดพัสดุ\nAI ช่วยประเมินขนาดยาว/กว้าง/สูงได้\nค่าส่งคำนวณตามนโยบายแพลตฟอร์ม',
    ),
    HelpArticle(
      id: 'wallet_earnings',
      categoryKey: 'wallet',
      titleTh: 'ดูรายได้ร้านที่ไหน?',
      titleEn: 'Where are my earnings?',
      bodyTh:
          'ไปที่ กระเป๋าเงิน/รายได้ ในหน้าหลัก\nดูยอดรายได้ ประวัติธุรกรรม และเงื่อนไขการถอน\nรายได้คำนวณตามนโยบายแพลตฟอร์ม (ราคาหลังส่วนลดและค่าบริการ)',
      popular: true,
    ),
    HelpArticle(
      id: 'login_google',
      categoryKey: 'account',
      titleTh: 'เข้าสู่ระบบด้วย Google',
      titleEn: 'Sign in with Google',
      bodyTh:
          'ใช้บัญชี Google ที่ผูกกับอีเมลร้าน\nหากเข้าไม่ได้ ลองออกจากระบบแล้วเข้าใหม่ หรือติดต่อแอดมิน',
    ),
    HelpArticle(
      id: 'contact_admin',
      categoryKey: 'app_bug',
      titleTh: 'ติดต่อแอดมินอย่างไร?',
      titleEn: 'How do I contact admin?',
      bodyTh:
          'ไปที่ ตั้งค่า → ติดต่อแอดมิน\nเลือกหัวข้อที่ตรงกับปัญหา แนบรูปประกอบ\nดูคำตอบได้ที่ ข้อความถึงแอดมิน',
      popular: true,
    ),
    HelpArticle(
      id: 'notifications',
      categoryKey: 'app_bug',
      titleTh: 'ไม่ได้รับแจ้งเตือนออเดอร์',
      titleEn: 'Not receiving order notifications?',
      bodyTh:
          'ตรวจสอบการอนุญาตแจ้งเตือนในระบบ\nและเปิดการแจ้งเตือนของแอป Van Market สำหรับร้านค้า',
    ),
  ];

  static List<HelpArticle> forCategory(String categoryKey) {
    return articles
        .where((article) => article.categoryKey == categoryKey)
        .toList(growable: false);
  }

  static List<HelpArticle> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return articles;
    }
    return articles
        .where((article) {
          final title = article.titleTh.toLowerCase();
          final body = article.bodyTh.toLowerCase();
          return title.contains(normalized) || body.contains(normalized);
        })
        .toList(growable: false);
  }

  static List<HelpArticle> popularArticles() {
    return articles.where((article) => article.popular).toList(growable: false);
  }
}
