import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_product_screen.dart';
import 'merchant_security_deposit_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';
import 'services/media_cache_service.dart';
import 'services/merchant_security_deposit_service.dart';
import 'services/product_cache_service.dart';
import 'storage_helper.dart';
import 'utils/app_colors.dart';
import 'utils/product_image_url.dart';
import 'widgets/product_network_image.dart';
import 'wallet_top_up_dialog.dart';
class ShopManagementScreen extends StatefulWidget {
  final Set<String>? initialHomeProductIds;
  final Function(Set<String>)? onHomeProductIdsChanged;
  final VoidCallback? onHomeProductsChanged;
  const ShopManagementScreen({
    super.key,
    this.initialHomeProductIds,
    this.onHomeProductIdsChanged,
    this.onHomeProductsChanged,
  });

  @override
  State<ShopManagementScreen> createState() => _ShopManagementScreenState();
}

class _ShopManagementScreenState extends State<ShopManagementScreen> {
  final Set<String> _homeProductIds = {};
  static const int _pageSize = 15;
  final ScrollController _scrollController = ScrollController();
  final Set<String> _deletingProductIds = {};
  final Set<String> _updatingDiscountProductIds = {};
  final List<Product> _products = [];
  final List<Product> _pendingReviewProducts = [];
  bool _isLoading = false;
  bool _isFirstLoad = true;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  bool get _areAllProductsSelected {
    final productIds = _publishedProducts
        .where((p) => p.id != null)
        .map((p) => p.id!)
        .toSet();
    if (productIds.isEmpty) return false;
    return productIds.every(_homeProductIds.contains);
  }

  List<Product> get _publishedProducts =>
      _products.where((product) => !product.isPendingAdminReview).toList();

  List<Product> get _displayProducts => [
        ..._pendingReviewProducts,
        ..._products,
      ];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _scrollController.addListener(_onScroll);
    if (widget.initialHomeProductIds != null) {
      _homeProductIds.addAll(widget.initialHomeProductIds!);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchProducts();
    }
  }

  Future<void> _fetchPendingReviews() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await FirebaseFirestore.instance
            .collection('product_admin_reviews')
            .where('ownerUid', isEqualTo: user.uid)
            .where('adminReviewStatus', isEqualTo: 'pending')
            .orderBy('submittedAt', descending: true)
            .get();
      } catch (_) {
        snapshot = await FirebaseFirestore.instance
            .collection('product_admin_reviews')
            .where('ownerUid', isEqualTo: user.uid)
            .where('adminReviewStatus', isEqualTo: 'pending')
            .get();
      }

      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final aSubmitted = a.data()['submittedAt'];
        final bSubmitted = b.data()['submittedAt'];
        if (aSubmitted is Timestamp && bSubmitted is Timestamp) {
          return bSubmitted.compareTo(aSubmitted);
        }
        return 0;
      });

      _pendingReviewProducts
        ..clear()
        ..addAll(docs.map(Product.fromAdminReviewSnapshot));
    } catch (e, stack) {
      debugPrint('ShopManagementScreen pending reviews error: $e');
      debugPrint('Stack: $stack');
    }
  }

  Future<void> _fetchProducts() async {
    if (_isLoading || (!_hasMore && !_isFirstLoad)) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _hasMore = false;
          _isFirstLoad = false;
        });
        return;
      }

      if (_isFirstLoad) {
        await _fetchPendingReviews();
      }

      Query query = FirebaseFirestore.instance
          .collection('products')
          .where('ownerUid', isEqualTo: user.uid);

      // To ensure consistent ordering for pagination, we should order by a field.
      // 'createdAt' is a good candidate if it exists.
      query = query.orderBy('createdAt', descending: true);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final querySnapshot = await query.limit(_pageSize).get();

      if (querySnapshot.docs.length < _pageSize) {
        _hasMore = false;
      }

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        final newProducts = querySnapshot.docs.map((doc) => Product.fromSnapshot(doc as QueryDocumentSnapshot<Map<String, dynamic>>)).toList();
        _products.addAll(newProducts);
      }
    } catch (e, stack) {
      debugPrint('ShopManagementScreen Firestore error: $e');
      debugPrint('Stack: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')),
        );
      }
    }

    setState(() {
      _isLoading = false;
      _isFirstLoad = false;
    });
  }

  Future<void> _refresh() async {
    _products.clear();
    _pendingReviewProducts.clear();
    _lastDocument = null;
    _isFirstLoad = true;
    _hasMore = true;
    await _fetchProducts();
  }

  Future<bool> _ensureCanAddFirstProduct() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }

    final depositService = MerchantSecurityDepositService.instance;
    if (!await depositService.needsDepositGate(user.uid)) {
      return true;
    }

    final agreed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => const MerchantSecurityDepositScreen(),
      ),
    );
    if (agreed != true || !mounted) {
      return false;
    }

    final topUpOk = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const WalletTopUpDialog(
        initialAmount: MerchantSecurityDepositService.requiredAmountBaht,
        minimumAmount: MerchantSecurityDepositService.requiredAmountBaht,
        isSecurityDeposit: true,
      ),
    );
    if (topUpOk != true || !mounted) {
      return false;
    }

    final paid = await depositService.isDepositPaid(user.uid);
    if (!paid && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ยังไม่สามารถเริ่มอัปโหลดได้ — กรุณาชำระค่าประกันให้ครบ'),
        ),
      );
    }
    return paid;
  }

  void _navigateToAddProduct(BuildContext context, {Product? product}) async {
    if (product == null) {
      final allowed = await _ensureCanAddFirstProduct();
      if (!allowed || !context.mounted) {
        return;
      }
    }

    final bool? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddProductScreen(productToEdit: product)),
    );
    if (result == true) {
      _refresh();
    }
  }

  void _deleteProduct(Product product) async {
    if (product.isPendingAdminReview ||
        product.id == null ||
        _deletingProductIds.contains(product.id!)) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('คุณต้องการลบสินค้า "${product.name}" ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ลบ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _deletingProductIds.add(product.id!);
    });

    try {
      final bool removedFromHome = _homeProductIds.remove(product.id!);
      if (removedFromHome) {
        widget.onHomeProductIdsChanged?.call(_homeProductIds);
      }
      await _deleteProductMedia(product);
      await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id!)
          .collection('specifications')
          .doc('main')
          .delete()
          .catchError((_) => null);
      await FirebaseFirestore.instance.collection('products').doc(product.id!).delete();
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        await ProductCacheService.instance.removeProduct(currentUserId, product.id!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบสินค้าเรียบร้อยแล้ว')));
        setState(() {
          _products.removeWhere((p) => p.id == product.id);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการลบ: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingProductIds.remove(product.id!);
        });
      }
    }
  }

  Future<void> _deleteProductMedia(Product product) async {
    final mediaUrls = <String>{
      ...product.imageUrls.where((url) => url.trim().isNotEmpty),
      ...product.thumbnailUrls.where((url) => url.trim().isNotEmpty),
      if ((product.videoUrl ?? '').trim().isNotEmpty) product.videoUrl!.trim(),
      if ((product.videoThumbnailUrl ?? '').trim().isNotEmpty) product.videoThumbnailUrl!.trim(),
    };

    for (final url in mediaUrls) {
      await _deleteStorageFile(url);
      await MediaCacheService.instance.remove(url);
    }
  }

  String _formatDiscountPercent(double value) {
    if (value <= 0) {
      return '0';
    }
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  double? _parseDiscountInput(String raw) {
    final normalized = raw
        .trim()
        .replaceAll('%', '')
        .replaceAll(',', '')
        .replaceAll(' ', '');
    if (normalized.isEmpty) {
      return 0;
    }
    final parsed = double.tryParse(normalized);
    if (parsed == null) {
      return null;
    }
    if (parsed <= 0) {
      return 0;
    }
    if (parsed > 100) {
      return 100;
    }
    return parsed;
  }

  Future<void> _editProductDiscount(Product product) async {
    if (product.isPendingAdminReview ||
        product.id == null ||
        _updatingDiscountProductIds.contains(product.id!)) {
      return;
    }

    final saved = await showDialog<double?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _DiscountPercentDialog(
        productName: product.name,
        initialPercent: product.discountPercent,
        parseInput: _parseDiscountInput,
        formatPercent: _formatDiscountPercent,
      ),
    );

    if (saved == null || !mounted) {
      return;
    }
    await _saveProductDiscount(product, saved);
  }

  Future<void> _saveProductDiscount(Product product, double discountPercent) async {
    if (product.id == null) {
      return;
    }

    setState(() {
      _updatingDiscountProductIds.add(product.id!);
    });

    try {
      await FirebaseFirestore.instance.collection('products').doc(product.id!).update(
        <String, dynamic>{
          'discountPercent': discountPercent,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        final refreshedDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(product.id!)
            .get();
        final refreshedData = refreshedDoc.data();
        if (refreshedData != null) {
          await ProductCacheService.instance.upsertProduct(
            currentUserId,
            CachedProduct(id: product.id!, data: refreshedData),
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        final index = _products.indexWhere((item) => item.id == product.id);
        if (index >= 0) {
          _products[index] = product.copyWith(discountPercent: discountPercent);
        }
      });

      widget.onHomeProductsChanged?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            discountPercent > 0
                ? 'ตั้งส่วนลด ${_formatDiscountPercent(discountPercent)}% สำหรับ "${product.name}" แล้ว'
                : 'ยกเลิกส่วนลดสำหรับ "${product.name}" แล้ว',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกส่วนลดไม่สำเร็จ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingDiscountProductIds.remove(product.id!);
        });
      }
    }
  }

  Widget _buildPendingReviewBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8F00),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Text(
        'รออนุมัติ',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  void _showPendingReviewInfo(Product product) {
    final reason = (product.aiLegalAnalysisReason ?? '').trim();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(product.name),
        content: Text(
          reason.isNotEmpty
              ? 'สินค้านี้อยู่ระหว่างรอแอดมินอนุมัติ\n\n$reason'
              : 'สินค้านี้อยู่ระหว่างรอแอดมินอนุมัติ จะขึ้นขายหลังได้รับการอนุมัติ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountPercentBadge(double discountPercent) {
    if (discountPercent <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'ลด ${_formatDiscountPercent(discountPercent)}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildProductActionButton({
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      shadowColor: Colors.black45,
      child: InkWell(
        onTap: onPressed,
        enableFeedback: false,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, color: iconColor, size: 26),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteStorageFile(String url) async {
    try {
      final ref = StorageHelper.instance.refFromURL(url);
      await ref.delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        return;
      }
      debugPrint('Failed to delete storage file $url: ${e.message ?? e.code}');
    } catch (e) {
      debugPrint('Failed to delete storage file $url: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: _publishedProducts.isEmpty ? null : _toggleSelectAllHomeProducts,
          tooltip: _areAllProductsSelected ? 'ยกเลิกเลือกทั้งหมด' : 'เลือกสินค้าทั้งหมด',
          icon: Icon(
            _areAllProductsSelected ? Icons.radio_button_unchecked : Icons.task_alt,
            color: Colors.white,
          ),
        ),
        title: const Text('จัดการร้านค้า'),
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.accent,
        surfaceTintColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.white,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.accent,
          child: Column(
            children: [
              Expanded(child: _buildProductList()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddProduct(context),
        tooltip: 'เพิ่มสินค้า',
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

    /// Toggle the ready-for-sale status for every currently loaded product at once.
    void _toggleSelectAllHomeProducts() {
      final productIds = _publishedProducts
          .where((p) => p.id != null)
          .map((p) => p.id!)
          .toSet();
      if (productIds.isEmpty) return;

      final shouldSelectAll = !_areAllProductsSelected;
      setState(() {
        if (shouldSelectAll) {
          _homeProductIds.addAll(productIds);
        } else {
          _homeProductIds.removeAll(productIds);
        }
      });

      widget.onHomeProductIdsChanged?.call(_homeProductIds);

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(shouldSelectAll ? 'เลือกสถานะพร้อมขายสำหรับสินค้าทั้งหมดแล้ว' : 'ยกเลิกสถานะพร้อมขายสำหรับสินค้าทั้งหมดแล้ว'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

  Widget _buildProductList() {
    if (_isFirstLoad) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_displayProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('ยังไม่มีสินค้าในร้านของคุณ', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              'แตะปุ่ม + มุมขวาล่างเพื่อเพิ่มสินค้า',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _displayProducts.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _displayProducts.length) {
          return _hasMore
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ))
              : const SizedBox.shrink();
        }
        final product = _displayProducts[index];
        final isPendingReview = product.isPendingAdminReview;
        final isDeleting = !isPendingReview &&
            product.id != null &&
            _deletingProductIds.contains(product.id!);
        final isUpdatingDiscount = !isPendingReview &&
            product.id != null &&
            _updatingDiscountProductIds.contains(product.id!);
        final isBusy = isDeleting || isUpdatingDiscount;
        final isHome = !isPendingReview &&
            product.id != null &&
            _homeProductIds.contains(product.id!);
        final previewCandidates = readProductImageUrlCandidates({
          'imageUrls': product.imageUrls,
          'thumbnailUrls': product.thumbnailUrls,
        });
        return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: isPendingReview
                    ? const Color(0xFFFF8F00)
                    : Colors.grey[300]!,
                width: isPendingReview ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                GestureDetector(
                  onTap: isBusy
                      ? null
                      : () {
                          if (isPendingReview) {
                            _showPendingReviewInfo(product);
                          } else {
                            _navigateToAddProduct(context, product: product);
                          }
                        },
                  child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: previewCandidates.isNotEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            return ProductNetworkImage(
                              urls: previewCandidates,
                              fit: BoxFit.cover,
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              memCacheWidth: 500,
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[200],
                          alignment: Alignment.center,
                          child: const Icon(Icons.image, size: 40, color: Colors.grey),
                        ),
                ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
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
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.white,
                            shadows: [Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 2)],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ราคา: ${product.price} บาท',
                          style: const TextStyle(fontSize: 14, color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'สต็อก: ${product.stock}',
                          style: const TextStyle(fontSize: 13, color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (product.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            product.description,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (isPendingReview)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildPendingReviewBadge(),
                  )
                else
                  Positioned(
                    top: 8,
                    left: 8,
                    child: GestureDetector(
                      onTap: isBusy || product.id == null ? null : () {
                        setState(() {
                          if (isHome) {
                            _homeProductIds.remove(product.id!);
                          } else {
                            _homeProductIds.add(product.id!);
                          }
                          if (widget.onHomeProductIdsChanged != null) {
                            widget.onHomeProductIdsChanged!(_homeProductIds);
                          }
                        });
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isHome ? AppColors.accent : Colors.grey,
                          border: Border.all(color: Colors.white, width: 2)),
                        child: const Icon(Icons.check, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                if (!isPendingReview && product.discountPercent > 0)
                  Positioned(
                    top: 44,
                    left: 8,
                    child: _buildDiscountPercentBadge(product.discountPercent),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: isPendingReview
                      ? const SizedBox.shrink()
                      : isBusy
                      ? const SizedBox(
                          width: 148,
                          height: 44,
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildProductActionButton(
                                icon: Icons.percent_rounded,
                                backgroundColor: const Color(0xFFE65100),
                                iconColor: Colors.white,
                                tooltip: product.discountPercent > 0
                                    ? 'แก้ไขส่วนลด (${_formatDiscountPercent(product.discountPercent)}%)'
                                    : 'ตั้งส่วนลด',
                                onPressed: () => _editProductDiscount(product),
                              ),
                              const SizedBox(width: 6),
                              _buildProductActionButton(
                                icon: Icons.edit_rounded,
                                backgroundColor: const Color(0xFF1565C0),
                                iconColor: Colors.white,
                                tooltip: 'แก้ไขสินค้า',
                                onPressed: () =>
                                    _navigateToAddProduct(context, product: product),
                              ),
                              const SizedBox(width: 6),
                              _buildProductActionButton(
                                icon: Icons.delete_rounded,
                                backgroundColor: const Color(0xFFD32F2F),
                                iconColor: Colors.white,
                                tooltip: 'ลบสินค้า',
                                onPressed: () => _deleteProduct(product),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
        );
      },
    );
  }
}

class _DiscountPercentDialog extends StatefulWidget {
  const _DiscountPercentDialog({
    required this.productName,
    required this.initialPercent,
    required this.parseInput,
    required this.formatPercent,
  });

  final String productName;
  final double initialPercent;
  final double? Function(String raw) parseInput;
  final String Function(double value) formatPercent;

  @override
  State<_DiscountPercentDialog> createState() => _DiscountPercentDialogState();
}

class _DiscountPercentDialogState extends State<_DiscountPercentDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialPercent > 0
          ? widget.formatPercent(widget.initialPercent)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = widget.parseInput(_controller.text);
    if (parsed == null) {
      setState(() {
        _errorText = 'กรุณาใส่ตัวเลข 0-100 เท่านั้น';
      });
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('ส่วนลด — ${widget.productName}'),
      content: SingleChildScrollView(
        child: TextField(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'ส่วนลด (%)',
            hintText: 'เช่น 10 (เว้นว่าง = ไม่ลด)',
            border: const OutlineInputBorder(),
            suffixText: '%',
            errorText: _errorText,
          ),
          onChanged: (_) {
            if (_errorText != null) {
              setState(() => _errorText = null);
            }
          },
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}