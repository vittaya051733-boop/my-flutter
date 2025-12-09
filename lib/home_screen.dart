import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'wallet_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'shipping_screen.dart';
import 'shop_management_screen.dart';
import 'order_management_screen_new.dart';
import 'driver_scanner_screen.dart';
import 'utils/app_colors.dart';
import 'chat_screen.dart';
import 'widgets/product_video_player.dart';
import 'services/product_cache_service.dart';
import 'services/video_prefetch_service.dart';
import 'utils/shop_profile_resolver.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
      int _notificationCount = 3; // ตัวอย่างจำนวนแจ้งเตือนใหม่
      List<String> _notificationDetails = [
        'มีออเดอร์ใหม่เข้ามา',
        'ลูกค้าส่งข้อความ',
        'ระบบแจ้งเตือนโปรโมชั่น',
      ];
    String? _activeNotification;
    void showOverlayNotification(String message) {
      setState(() {
        _activeNotification = message;
      });
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _activeNotification == message) {
          setState(() => _activeNotification = null);
        }
      });
    }
  static const int _tabCount = 9;

  late final TabController _tabController;
  int _currentIndex = 0;
  late final List<Widget?> _pages = List<Widget?>.filled(_tabCount, null, growable: false);
  String? _shopImageUrl;
  String? _shopName;
  Set<String> _homeProductIds = <String>{};
  Future<List<CachedProduct>>? _homeProductsFuture;
  List<CachedProduct> _localCachedProducts = const [];
  bool _isShopOpen = true;
  DocumentReference<Map<String, dynamic>>? _shopDocRef;
  String? _currentUserId;
  int _unreadChatCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _pages[0] = _buildPage(0);
    _tabController.addListener(_handleTabChange);
    _loadShopDetails();
    _listenUnreadChats();

    // บังคับให้ System Navigation Bar เป็นสีขาวเมื่อเข้า Home
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.white,
      systemNavigationBarContrastEnforced: false,
    ));
  }

  Future<void> _loadShopDetails() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _currentUserId = user.uid;
      _hydrateCachedProducts(user.uid);

      final collectionsToCheck = await _collectionsToCheck(user);
      if (collectionsToCheck.isEmpty) return;

      final futures = collectionsToCheck.map((collectionName) async {
        final docRef = FirebaseFirestore.instance.collection(collectionName).doc(user.uid);
        final snapshot = await docRef.get();
        return MapEntry(docRef, snapshot);
      }).toList();

      final results = await Future.wait(futures);
      for (final entry in results) {
        final snapshot = entry.value;
        if (!snapshot.exists) continue;
        final data = snapshot.data();
        if (data == null) continue;

        final String? imageUrl = ShopProfileResolver.resolveImageUrl(data);
        final String? name = ShopProfileResolver.resolveName(data);
        final bool isOpen = data['isOpen'] as bool? ?? true;
        final Set<String> homeIds = ((data['homeProductIds'] as List?) ?? const [])
            .whereType<String>()
            .toSet();

        if (!mounted) return;
        setState(() {
          _shopDocRef = entry.key;
          if (imageUrl != null && imageUrl.isNotEmpty) {
            _shopImageUrl = imageUrl;
          }
          if (name != null && name.isNotEmpty) {
            _shopName = name;
          }
          _isShopOpen = isOpen;
          _homeProductIds = homeIds;
          _pages[0] = _buildPage(0);
        });
        _updateHomeProductsCache();

        if (imageUrl != null && imageUrl.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              precacheImage(CachedNetworkImageProvider(imageUrl), context);
            }
          });
        }
        break;
      }
    } catch (e) {
      debugPrint('Failed to load shop details: $e');
    }
  }

  void _listenUnreadChats() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseFirestore.instance
        .collection('chatRooms')
        .where('participants', arrayContains: user.uid)
        .snapshots()
        .listen((snapshot) {
      int totalUnread = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final unreadMap = data['unreadCounts'] as Map<String, dynamic>?;
        if (unreadMap != null) {
          final userCount = unreadMap[user.uid];
          if (userCount is int) {
            totalUnread += userCount;
          } else if (userCount is num) {
            totalUnread += userCount.toInt();
          }
        }
      }
      if (mounted) {
        setState(() => _unreadChatCount = totalUnread);
      }
    });
  }

  Future<void> _hydrateCachedProducts(String userId) async {
    final cached = await ProductCacheService.instance.loadProducts(userId);
    if (!mounted || cached.isEmpty) return;
    setState(() {
      _localCachedProducts = cached;
      _pages[0] = _buildPage(0);
    });
  }

  Future<List<CachedProduct>> _fetchHomeProducts(String userId, Set<String> ids) async {
    if (ids.isEmpty) {
      return const <CachedProduct>[];
    }

    final orderedIds = ids.toList();
    final Map<String, int> ordering = {
      for (var i = 0; i < orderedIds.length; i++) orderedIds[i]: i,
    };
    const int chunkSize = 10;
    final productsCollection = FirebaseFirestore.instance.collection('products');
    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];

    for (var start = 0; start < orderedIds.length; start += chunkSize) {
      final end = (start + chunkSize) > orderedIds.length ? orderedIds.length : start + chunkSize;
      futures.add(
        productsCollection
          .where(FieldPath.documentId, whereIn: orderedIds.sublist(start, end))
          .get(),
      );
    }

    final snapshots = await Future.wait(futures);
    final docs = snapshots.expand((snap) => snap.docs).toList();
    docs.sort((a, b) {
      final orderA = ordering[a.id] ?? 0;
      final orderB = ordering[b.id] ?? 0;
      return orderA.compareTo(orderB);
    });
    final products = docs
        .map((doc) => CachedProduct(id: doc.id, data: doc.data()))
        .toList(growable: false);
    await ProductCacheService.instance.saveProducts(userId, products);
    if (mounted) {
      setState(() {
        _localCachedProducts = products;
        _pages[0] = _buildPage(0);
      });
    }
    return products;
  }

  void _updateHomeProductsCache() {
    final userId = _currentUserId;
    if (!mounted) return;
    if (userId == null || _homeProductIds.isEmpty) {
      if (userId != null && _homeProductIds.isEmpty) {
        unawaited(ProductCacheService.instance.clear(userId));
      }
      setState(() {
        _homeProductsFuture = null;
        _localCachedProducts = const [];
      });
      return;
    }
    setState(() {
      _homeProductsFuture = _fetchHomeProducts(userId, _homeProductIds);
      _pages[0] = _buildPage(0);
    });
  }

  Future<List<String>> _collectionsToCheck(User user) async {
    final List<String> collections = [];
    try {
      final contractDoc = await FirebaseFirestore.instance.collection('contracts').doc(user.uid).get();
      final String? serviceType = contractDoc.data()?['serviceType'] as String?;
      if (serviceType != null && serviceType.trim().isNotEmpty) {
        final resolved = _collectionForServiceType(serviceType);
        collections.add(resolved);
      }
    } catch (e) {
      debugPrint('Failed to read service type: $e');
    }

    const fallbackCollections = [
      'market_registrations',
      'shop_registrations',
      'restaurant_registrations',
      'pharmacy_registrations',
      'other_registrations',
    ];

    for (final name in fallbackCollections) {
      if (!collections.contains(name)) {
        collections.add(name);
      }
    }

    return collections;
  }

  String _collectionForServiceType(String serviceType) {
    switch (serviceType.trim()) {
      case 'ตลาด':
        return 'market_registrations';
      case 'ร้านค้า':
        return 'shop_registrations';
      case 'ร้านอาหาร':
        return 'restaurant_registrations';
      case 'ร้านขายยา':
        return 'pharmacy_registrations';
      default:
        return 'other_registrations';
    }
  }

  Future<void> _saveShopOpenStatus(bool isOpen) async {
    try {
      final docRef = await _getOrFindShopDocRef();
      if (docRef == null) return;
      await docRef.update({'isOpen': isOpen});
      debugPrint('Updated isOpen=$isOpen for ${docRef.path}');
    } catch (e) {
      debugPrint('Failed to save shop open status: $e');
    }
  }

  Future<void> _saveHomeProductIds(Set<String> ids) async {
    try {
      final docRef = await _getOrFindShopDocRef();
      if (docRef == null) return;
      await docRef.update({'homeProductIds': ids.toList()});
      debugPrint('Saved homeProductIds (${ids.length}) to ${docRef.path}');
    } catch (e) {
      debugPrint('Failed to save home product ids: $e');
    }
  }

  Future<DocumentReference<Map<String, dynamic>>?> _getOrFindShopDocRef() async {
    if (_shopDocRef != null) return _shopDocRef;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final collections = await _collectionsToCheck(user);
    for (final name in collections) {
      final docRef = FirebaseFirestore.instance.collection(name).doc(user.uid);
      final snapshot = await docRef.get();
      if (snapshot.exists) {
        _shopDocRef = docRef;
        return _shopDocRef;
      }
    }
    return null;
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    final int newIndex = _tabController.index;
    if (newIndex != _currentIndex) {
      setState(() {
        _currentIndex = newIndex;
        _pages[newIndex] ??= _buildPage(newIndex);
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return _HomeDashboard(
          onProfileTap: () => _switchToTab(5),
          shopImageUrl: _shopImageUrl,
          shopName: _shopName,
          homeProductIds: _homeProductIds,
          homeProductsFuture: _homeProductsFuture,
          cachedProducts: _localCachedProducts,
          isShopOpen: _isShopOpen,
          onToggleShopStatus: (value) async {
            setState(() {
              _isShopOpen = value;
              _pages[0] = _buildPage(0);
            });
            
            // บันทึกสถานะลง Firestore
            await _saveShopOpenStatus(value);
            
            final messenger = ScaffoldMessenger.of(context);
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              SnackBar(
                content: Text(value ? 'ร้านเปิดให้บริการแล้ว' : 'ร้านถูกปิดชั่วคราว'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        );
      case 1:
        return ShopManagementScreen(
          initialHomeProductIds: _homeProductIds,
          onHomeProductIdsChanged: (ids) {
            setState(() {
              _homeProductIds = ids;
              _pages[0] = _buildPage(0); // สร้างหน้าโฮมขึ้นมาใหม่
            });
            _updateHomeProductsCache();
            _saveHomeProductIds(ids);
          },
        );
      case 2:
        return const OrderManagementScreen();
      case 3:
        return const DriverScannerScreen();
      case 4:
        return const ShippingScreen();
      case 5:
        return const WalletScreen();
      case 6:
        return const NotificationsScreen();
      case 7:
        return const ChatScreen();
      case 8:
        return const SettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  void _switchToTab(int index) {
    if (index == _currentIndex) return;
    if (_pages[index] == null) {
      setState(() => _pages[index] = _buildPage(index));
    }
    _tabController.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.white,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Stack(
        children: [
          Scaffold(
            body: IndexedStack(
              index: _currentIndex,
              children: _pages.map((page) => page ?? const SizedBox.shrink()).toList(),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              minimum: EdgeInsets.zero,
              child: ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SizedBox(
                    height: 65,
                    child: Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildNavButton(icon: Icons.home_outlined, index: 0),
                            _buildNavButton(icon: Icons.store_outlined, index: 1),
                            _buildNavButton(icon: Icons.receipt_long, index: 2),
                            // Hidden QR scanner button (index 3) – feature paused for shop app UX
                            _buildNavButton(icon: Icons.delivery_dining, index: 4),
                            _buildNavButton(icon: Icons.wallet, index: 5),
                            _buildNavButton(icon: Icons.notifications_outlined, index: 6),
                            _buildNavButton(
                              icon: Icons.chat_bubble_outline,
                              index: 7,
                              badgeCount: _unreadChatCount,
                            ),
                            _buildNavButton(icon: Icons.settings_outlined, index: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_activeNotification != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _activeNotification ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => setState(() => _activeNotification = null),
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

  Widget _buildNavButton({
    required IconData icon,
    required int index,
    int badgeCount = 0,
  }) {
    final bool isSelected = _currentIndex == index;
    final Color circleColor = isSelected ? AppColors.accentLight : const Color(0xFFE6E6E6);
    final Color iconColor = isSelected ? AppColors.accent : AppColors.neutralIcon;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: () {
          _switchToTab(index);
          if (index == 6 && _notificationCount > 0) {
            setState(() {
              _notificationCount = 0;
            });
            _showNotificationDetails(context);
          }
        },
        borderRadius: BorderRadius.circular(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.accent.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                if (index == 6 && _notificationCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        _notificationCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (badgeCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

  }

  void _showNotificationDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('รายละเอียดการแจ้งเตือน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._notificationDetails.map((msg) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.notifications, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(msg, style: const TextStyle(fontSize: 15))),
                  ],
                ),
              )),
              if (_notificationDetails.isEmpty)
                const Text('ไม่มีการแจ้งเตือนใหม่', style: TextStyle(fontSize: 15)),
            ],
          ),
        );
      },
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.onProfileTap,
    required this.isShopOpen,
    required this.onToggleShopStatus,
    required this.cachedProducts,
    this.shopImageUrl,
    this.shopName,
    this.homeProductIds,
    this.homeProductsFuture,
  });

  final VoidCallback onProfileTap;
  final bool isShopOpen;
  final ValueChanged<bool> onToggleShopStatus;
  final String? shopImageUrl;
  final String? shopName;
  final Set<String>? homeProductIds;
  final Future<List<CachedProduct>>? homeProductsFuture;
  final List<CachedProduct> cachedProducts;


  void _showProductGallery(BuildContext context, Map<String, dynamic> data) {
    final List<String> allImages = _extractImages(data, preferThumbnails: false);
    // Always show the selected imageUrl (from grid) as the first image
    final selectedImageUrl = allImages.isNotEmpty ? allImages.first : null;
    final List<String> imageUrls = selectedImageUrl != null
      ? [selectedImageUrl, ...allImages.where((url) => url != selectedImageUrl)]
      : allImages;
    final videoUrl = data['videoUrl'] as String?;
    final name = (data['name'] ?? '').toString();
    final price = (data['price'] ?? '').toString();
    final stock = data['stock']?.toString() ?? '0';
    final description = (data['description'] ?? '').toString();
    final videoThumbnailUrl = (data['videoThumbnailUrl'] ?? '').toString().trim();

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: _ProductGalleryContent(
          images: imageUrls,
          videoUrl: videoUrl,
          videoThumbnailUrl: videoThumbnailUrl.isNotEmpty ? videoThumbnailUrl : null,
          name: name,
          price: price,
          stock: stock,
          description: description,
        ),
      ),
    );
  }

  List<String> _extractImages(Map<String, dynamic> data, {bool preferThumbnails = false}) {
    List<String> readList(String key) => (data[key] as List?)
            ?.whereType<String>()
            .where((url) => url.trim().isNotEmpty)
            .toList() ??
        const [];

    final thumbnails = readList('thumbnailUrls');
    final originals = readList('imageUrls');

    if (preferThumbnails && thumbnails.isNotEmpty) {
      return thumbnails;
    }
    if (!preferThumbnails && originals.isNotEmpty) {
      return originals;
    }
    return thumbnails.isNotEmpty ? thumbnails : originals;
  }

  void _prefetchProductVideos(List<CachedProduct> docs, int selectedIndex) {
    if (selectedIndex < 0 || selectedIndex >= docs.length) {
      return;
    }

    final Set<String> urls = <String>{};
    final String? current = (docs[selectedIndex].data['videoUrl'] as String?)?.trim();
    if (current != null && current.isNotEmpty) {
      urls.add(current);
    }

    int offset = 1;
    int neighborCount = 0;
    while (neighborCount < 5 && (selectedIndex - offset >= 0 || selectedIndex + offset < docs.length)) {
      final prevIndex = selectedIndex - offset;
      if (prevIndex >= 0) {
        final prevUrl = (docs[prevIndex].data['videoUrl'] as String?)?.trim();
        if (prevUrl != null && prevUrl.isNotEmpty && urls.add(prevUrl)) {
          neighborCount++;
        }
      }

      final nextIndex = selectedIndex + offset;
      if (nextIndex < docs.length) {
        final nextUrl = (docs[nextIndex].data['videoUrl'] as String?)?.trim();
        if (nextUrl != null && nextUrl.isNotEmpty && urls.add(nextUrl)) {
          neighborCount++;
        }
      }

      offset++;
    }

    if (urls.isNotEmpty) {
      VideoPrefetchService.instance.preloadVideos(urls);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider? avatarImage = (shopImageUrl != null && shopImageUrl!.isNotEmpty)
      ? CachedNetworkImageProvider(shopImageUrl!)
        : null;
    final String displayName = (shopName != null && shopName!.isNotEmpty)
        ? shopName!
        : '-';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.accent,
        elevation: 0,
        surfaceTintColor: AppColors.accent,
        leadingWidth: 150,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
          child: _ShopStatusToggle(
            isOpen: isShopOpen,
            onToggle: onToggleShopStatus,
          ),
        ),
        title: Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: onProfileTap,
              child: SizedBox(
                width: 68,
                height: 68,
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.accent,
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? const Icon(Icons.account_circle, color: Colors.white, size: 42)
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
      body: !isShopOpen
          ? Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[300]!, width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.store_mall_directory_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 24),
                    Text(
                      'ร้านปิดชั่วคราว',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ขออภัยค่ะ ร้านค้าปิดทำการในขณะนี้\nกรุณากลับมาใหม่ภายหลัง',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
                    ),
                  ],
                ),
              ),
            )
          : homeProductIds == null || homeProductIds!.isEmpty
              ? const Center(child: Text('ยังไม่มีสินค้าที่เลือกแสดงบนหน้าโฮม', style: TextStyle(fontSize: 18)))
              : FutureBuilder<List<CachedProduct>>(
                  future: homeProductsFuture,
                  builder: (context, snapshot) {
                    final List<CachedProduct> docs = snapshot.data ?? cachedProducts;
                    final bool showLoading =
                        snapshot.connectionState == ConnectionState.waiting && docs.isEmpty;

                    if (showLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError && docs.isEmpty) {
                      return Center(
                        child: Text(
                          'เกิดข้อผิดพลาดในการโหลดสินค้า: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    if (docs.isEmpty) {
                      return const Center(child: Text('ไม่พบสินค้าที่เลือก', style: TextStyle(fontSize: 18)));
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data;
                        final List<String> thumbnailImages = _extractImages(data, preferThumbnails: true);
                        final String? imageUrl = thumbnailImages.isNotEmpty ? thumbnailImages.first : null;
                        final name = (data['name'] ?? '').toString();
                        final price = (data['price'] ?? '').toString();
                        final stock = data['stock']?.toString() ?? '0';
                        final description = (data['description'] ?? '').toString();

                        return GestureDetector(
                          onTap: () {
                            _prefetchProductVideos(docs, index);
                            // จัดลำดับภาพนิ่งให้เป็นภาพแรกเสมอ
                            final List<String> allImages = _extractImages(data, preferThumbnails: false);
                            // กรอง videoUrl ออกจาก imageUrls
                            final videoUrl = data['videoUrl'] as String?;
                            final filteredImages = videoUrl != null
                                ? allImages.where((url) => url != videoUrl).toList()
                                : allImages;
                            final selectedImageUrl = imageUrl;
                            final List<String> galleryImages = selectedImageUrl != null
                              ? [selectedImageUrl, ...filteredImages.where((url) => url != selectedImageUrl)]
                              : filteredImages;
                            final modalData = Map<String, dynamic>.from(data);
                            modalData['imageUrls'] = galleryImages;
                            _showProductGallery(context, modalData);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: imageUrl != null
                                        ? Stack(
                                            children: [
                                              Positioned.fill(
                                                child: CachedNetworkImage(
                                                  imageUrl: imageUrl,
                                                  fit: BoxFit.cover,
                                                  memCacheWidth: 500, // Optimize memory usage
                                                  maxWidthDiskCache: 800, // Optimize disk storage
                                                  placeholder: (context, url) => Container(
                                                    color: Colors.grey[100],
                                                    alignment: Alignment.center,
                                                    child: const SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    ),
                                                  ),
                                                  errorWidget: (context, url, error) => Container(
                                                    color: Colors.grey[200],
                                                    alignment: Alignment.center,
                                                    child: const Icon(Icons.broken_image, size: 36, color: Colors.grey),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Container(
                                            color: Colors.grey[200],
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.image, size: 40, color: Colors.grey),
                                          ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Color(0xCC000000),
                                            Color(0x66000000),
                                            Color(0x00000000),
                                          ],
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              shadows: [Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 2)],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'ราคา: $price บาท',
                                            style: const TextStyle(fontSize: 13, color: Colors.white70),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'สต๊อก: $stock',
                                            style: const TextStyle(fontSize: 13, color: Colors.white70),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (description.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              description,
                                              style: const TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class _ProductGalleryContent extends StatefulWidget {
  const _ProductGalleryContent({
    required this.images,
    required this.name,
    required this.price,
    required this.stock,
    required this.description,
    this.videoUrl,
    this.videoThumbnailUrl,
    Key? key,
  }) : super(key: key);

  final List<String> images;
  final String? videoUrl;
  final String? videoThumbnailUrl;
  final String name;
  final String price;
  final String stock;
  final String description;

  @override
  State<_ProductGalleryContent> createState() => _ProductGalleryContentState();
}

class _ProductGalleryContentState extends State<_ProductGalleryContent> {

  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      VideoPrefetchService.instance.preloadVideo(widget.videoUrl!);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasImages = widget.images.isNotEmpty;
    final theme = Theme.of(context);
    final hasVideo = widget.videoUrl != null && widget.videoUrl!.isNotEmpty;
    final totalPages = hasImages ? widget.images.length + (hasVideo ? 1 : 0) : (hasVideo ? 1 : 0);

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.85,
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.name.isNotEmpty ? widget.name : 'รายละเอียดสินค้า',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'ปิด',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: totalPages > 0
                ? PageView.builder(
                    controller: _pageController,
                    itemCount: totalPages,
                    onPageChanged: (index) => setState(() => _currentIndex = index),
                    itemBuilder: (context, index) {
                      // Always show images first, video last
                      if (hasImages && index < widget.images.length) {
                        final url = widget.images[index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            memCacheWidth: 800, // Optimize memory usage
                            maxWidthDiskCache: 1000, // Optimize disk storage
                            placeholder: (context, _) => const Center(child: CircularProgressIndicator()),
                            errorWidget: (context, _, __) => Container(
                              color: Colors.grey[200],
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                            ),
                          ),
                        );
                      } else if (hasVideo && index == totalPages - 1) {
                        // Last page: show video
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ProductVideoPlayer(
                            videoUrl: widget.videoUrl!,
                            thumbnailUrl: widget.videoThumbnailUrl,
                          ),
                        );
                      } else {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                        );
                      }
                    },
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                  ),
          ),
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalPages, (index) {
                  final isActive = index == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 12 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.accent : Colors.grey[400],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }),
              ),
            ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ราคา: ${widget.price} บาท', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('สต๊อก: ${widget.stock}', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                  if (widget.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('คำอธิบาย', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.description, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _ShopStatusToggle extends StatefulWidget {
  const _ShopStatusToggle({
    required this.isOpen,
    required this.onToggle,
  });

  final bool isOpen;
  final ValueChanged<bool> onToggle;

  @override
  State<_ShopStatusToggle> createState() => _ShopStatusToggleState();
}

class _ShopStatusToggleState extends State<_ShopStatusToggle> {
  static const double _toggleWidth = 160;
  static const double _padding = 4;

  double? _dragFraction;
  double _dragBaseFraction = 0;
  late bool _localOpen;

  double get _currentFraction => _dragFraction ?? (_localOpen ? 0.0 : 1.0);

  @override
  void didUpdateWidget(covariant _ShopStatusToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen != widget.isOpen && _dragFraction == null) {
      _localOpen = widget.isOpen;
      _dragBaseFraction = _localOpen ? 0.0 : 1.0;
    }
  }

  @override
  void initState() {
    super.initState();
    _localOpen = widget.isOpen;
    _dragBaseFraction = _localOpen ? 0.0 : 1.0;
  }

  void _handleTap() {
    final next = !_localOpen;
    widget.onToggle(next);
    setState(() {
      _localOpen = next;
      _dragBaseFraction = next ? 0.0 : 1.0;
      _dragFraction = null;
    });
  }

  void _handleDragStart(DragStartDetails details) {
    _dragBaseFraction = _currentFraction;
    _dragFraction = _dragBaseFraction;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final availableWidth = _toggleWidth - (_padding * 2);
    if (availableWidth <= 0) return;
    final delta = (details.primaryDelta ?? 0) / availableWidth;
    setState(() {
      final current = _dragFraction ?? _dragBaseFraction;
      final next = (current + delta).clamp(0.0, 1.0);
      _dragFraction = next;
      _dragBaseFraction = next;
    });
  }

  void _handleDragEnd([DragEndDetails? details]) {
    final fraction = _currentFraction;
    final velocity = details?.velocity.pixelsPerSecond.dx ?? 0;
    final shouldOpen = velocity.abs() > 200
        ? velocity < 0
        : fraction < 0.5;
    widget.onToggle(shouldOpen);
    setState(() {
      _localOpen = shouldOpen;
      _dragBaseFraction = shouldOpen ? 0.0 : 1.0;
      _dragFraction = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fraction = _currentFraction;
  final bool highlightOpen = _localOpen;
    final alignment = Alignment(fraction * 2 - 1, 0);

    return Tooltip(
      message: highlightOpen ? 'เลื่อนเพื่อปิดร้าน' : 'เลื่อนเพื่อเปิดร้าน',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onHorizontalDragStart: _handleDragStart,
        onHorizontalDragUpdate: _handleDragUpdate,
        onHorizontalDragEnd: _handleDragEnd,
        onHorizontalDragCancel: () => setState(() => _dragFraction = null),
        child: Container(
          width: _toggleWidth,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white70),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _padding, vertical: 4),
                child: AnimatedAlign(
                  alignment: alignment,
                  duration: Duration(milliseconds: _dragFraction != null ? 0 : 220),
                  curve: Curves.easeOut,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: highlightOpen ? Colors.green : AppColors.accent,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        'เปิดร้าน',
                        style: TextStyle(
                          color: highlightOpen ? Colors.white : Colors.grey[700],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'ปิดร้าน',
                        style: TextStyle(
                          color: highlightOpen ? Colors.grey[700] : Colors.white,
                          fontWeight: FontWeight.w700,
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
    );
  }
}
