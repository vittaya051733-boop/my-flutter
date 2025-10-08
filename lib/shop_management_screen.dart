import 'package:flutter/material.dart';
import 'register_shop_screen.dart';
import 'add_product_screen.dart';
import '../models/product_model.dart';

class ShopManagementScreen extends StatefulWidget {
  const ShopManagementScreen({super.key});

  @override
  _ShopManagementScreenState createState() => _ShopManagementScreenState();
}

class _ShopManagementScreenState extends State<ShopManagementScreen> {
  final List<Product> _products = [];

  void _navigateAndAddProduct(BuildContext context) async {
    final newProduct = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (context) => const AddProductScreen()),
    );

    if (newProduct != null) {
      setState(() {
        _products.add(newProduct);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการร้านค้า'),
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Menu Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                 _buildMenuButton(context, icon: Icons.storefront, label: 'ลงทะเบียนร้าน', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterShopScreen()))),
                 _buildMenuButton(context, icon: Icons.receipt_long, label: 'จัดการออเดอร์', onPressed: () {}),
                 _buildMenuButton(context, icon: Icons.attach_money, label: 'จัดการรายได้', onPressed: () {}),
                 _buildMenuButton(context, icon: Icons.chat, label: 'ช่องแชต', onPressed: () {}),
              ],
            ),
          ),
          
          // Add Product Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('เพิ่มสินค้าใหม่'),
              onPressed: () => _navigateAndAddProduct(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Product List Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('รายการสินค้าของคุณ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),

          // Conditional Product List
          _products.isEmpty
              ? Container() // Show a small empty space when no products
              : Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        elevation: 2,
                        child: ListTile(
                          leading: Image.network(
                            product.imageUrls.first,
                            width: 56, height: 56, fit: BoxFit.cover,
                             errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, size: 56),
                          ),
                          title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('ราคา: ${product.price} บาท | สต็อก: ${product.stock}'),
                          trailing: const Icon(Icons.more_vert),
                          onTap: () {
                            // TODO: Navigate to product detail/edit screen
                          },
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: Colors.orange[800]),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
