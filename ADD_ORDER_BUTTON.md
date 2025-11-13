# คำแนะนำการเพิ่มปุ่มจัดการออเดอร์

## ขั้นตอนที่ 1: แก้ไข lib/home_screen.dart

### 1.1 เพิ่ม import
```dart
import 'order_management_screen_new.dart';
```

### 1.2 เปลี่ยน _tabCount จาก 6 เป็น 7
```dart
static const int _tabCount = 7;  // เดิมเป็น 6
```

### 1.3 เพิ่ม case 2 ใน _buildPage สำหรับ OrderManagement
แก้ไขฟังก์ชัน `_buildPage` ดังนี้:

```dart
Widget _buildPage(int index) {
  switch (index) {
    case 0:
      return _HomeDashboard(...);  // หน้าโฮม
    case 1:
      return ShopManagementScreen(...);  // จัดการร้าน
    case 2:
      return const OrderManagementScreen();  // ⭐ เพิ่มใหม่
    case 3:
      return const ShippingScreen();  // เปลี่ยนจาก case 2
    case 4:
      return const WalletScreen();  // เปลี่ยนจาก case 3
    case 5:
      return const NotificationsScreen();  // เปลี่ยนจาก case 4
    case 6:
      return const SettingsScreen();  // เปลี่ยนจาก case 5
    default:
      return const SizedBox.shrink();
  }
}
```

### 1.4 เพิ่มปุ่มในเมนูล่าง
แก้ไข Row ใน bottomNavigationBar:

```dart
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    _buildNavButton(icon: Icons.home_outlined, index: 0),
    _buildNavButton(icon: Icons.store_outlined, index: 1),
    _buildNavButton(icon: Icons.receipt_long, index: 2),  // ⭐ เพิ่มใหม่ - จัดการออเดอร์
    _buildNavButton(icon: Icons.delivery_dining, index: 3),  // เปลี่ยนจาก 2
    _buildNavButton(icon: Icons.wallet, index: 4),  // เปลี่ยนจาก 3
    _buildNavButton(icon: Icons.notifications_outlined, index: 5),  // เปลี่ยนจาก 4
    _buildNavButton(icon: Icons.settings_outlined, index: 6),  // เปลี่ยนจาก 5
  ],
)
```

## ขั้นตอนที่ 2: ทดสอบ

1. Save ไฟล์ `home_screen.dart`
2. Hot reload แอพ
3. ดูเมนูล่าง จะมีปุ่มใหม่ (ไอคอน receipt_long) ระหว่างปุ่มจัดการร้านและการจัดส่ง
4. กดปุ่มนั้นจะเข้าหน้า OrderManagementScreen

## ไอคอนที่แนะนำสำหรับปุ่มจัดการออเดอร์
- `Icons.receipt_long` - ใบเสร็จยาว (แนะนำ)
- `Icons.shopping_bag` - ถุงช้อปปิ้ง
- `Icons.assignment` - เอกสารงาน
- `Icons.list_alt` - รายการ
