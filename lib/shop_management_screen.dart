import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_product_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';
import 'utils/app_colors.dart';

class ShopManagementScreen extends StatefulWidget {
  final Set<String>? initialHomeProductIds;
  final Function(Set<String>)? onHomeProductIdsChanged;
  const ShopManagementScreen({super.key, this.initialHomeProductIds, this.onHomeProductIdsChanged});

  @override
  State<ShopManagementScreen> createState() => _ShopManagementScreenState();
}

class _ShopManagementScreenState extends State<ShopManagementScreen> {
  final Set<String> _homeProductIds = {};
  static const int _pageSize = 15;
  final ScrollController _scrollController = ScrollController();
  final Set<String> _deletingProductIds = {};
  final List<Product> _products = [];
  bool _isLoading = false;
  bool _isFirstLoad = true;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

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

  Future<void> _fetchProducts() async {
    if (_isLoading) return;

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
    _lastDocument = null;
    _isFirstLoad = true;
    _hasMore = true;
    await _fetchProducts();
  }

  void _navigateToAddProduct(BuildContext context, {Product? product}) async {
    final bool? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddProductScreen(productToEdit: product)),
    );
    if (result == true) {
      _refresh();
    }
  }

  void _deleteProduct(Product product) async {
    if (product.id == null || _deletingProductIds.contains(product.id!)) return;

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
      await FirebaseFirestore.instance.collection('products').doc(product.id!).delete();
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
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

  Widget _buildProductList() {
    if (_isFirstLoad) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_products.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => _navigateToAddProduct(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.all(16),
              ),
              child: const Icon(Icons.add, size: 28),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('ยังไม่มีสินค้าในร้านของคุณ', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
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
      itemCount: _products.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _products.length) {
          return _hasMore
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ))
              : const SizedBox.shrink();
        }
        final product = _products[index];
        final isDeleting = product.id != null && _deletingProductIds.contains(product.id!);
        final isHome = product.id != null && _homeProductIds.contains(product.id!);
        return InkWell(
          onTap: isDeleting ? null : () => _navigateToAddProduct(context, product: product),
          child: Container(
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
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: product.imageUrls.isNotEmpty
                      ? Image.network(
                          product.imageUrls.first,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[200],
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image, size: 32, color: Colors.grey),
                          ),
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
                Positioned(
                  top: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: isDeleting || product.id == null ? null : () {
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
                Positioned(
                  top: 8,
                  right: 8,
                  child: isDeleting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                          onPressed: () => _deleteProduct(product),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }  
}