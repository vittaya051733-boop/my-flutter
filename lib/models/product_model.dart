import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String? id; // Add ID field
  final String name;
  final String description;
  final String? toppings;
  final String? productCategory;
  final bool isFreshProduct;
  final bool isProcessed;
  final String? taxStatus;
  final double price;
  final int stock;
  final List<String> imageUrls;
  final List<String> thumbnailUrls;
  final List<String> colors;
  final List<String> sizes;
  final String unit;
  final double? weight;
  final String? videoUrl;
  final String? videoThumbnailUrl;

  Product({
    this.id, // Add to constructor
    required this.name,
    required this.description,
    this.toppings,
    this.productCategory,
    this.isFreshProduct = false,
    this.isProcessed = false,
    this.taxStatus,
    required this.price,
    required this.stock,
    required this.imageUrls,
    required this.thumbnailUrls,
    required this.colors,
    required this.sizes,
    required this.unit,
    this.weight,
    this.videoUrl,
    this.videoThumbnailUrl,
  });

  // Method to convert a Product instance to a map.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'toppings': toppings,
      'productCategory': productCategory,
      'isFreshProduct': isFreshProduct,
      'isProcessed': isProcessed,
      'taxStatus': taxStatus,
      'price': price,
      'stock': stock,
      'imageUrls': imageUrls,
      'thumbnailUrls': thumbnailUrls,
      'colors': colors,
      'sizes': sizes,
      'unit': unit,
      'weight': weight,
      'videoUrl': videoUrl,
      'videoThumbnailUrl': videoThumbnailUrl,
      'createdAt': FieldValue.serverTimestamp(), // Automatically add a timestamp
    };
  }

  // Factory constructor to create a Product from a Firestore document.
  factory Product.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data()!;
    double? parsedWeight;
    final weightValue = map['weight'];
    if (weightValue is num) {
      parsedWeight = weightValue.toDouble();
    } else if (weightValue is String) {
      parsedWeight = double.tryParse(weightValue);
    }
    return Product(
      id: doc.id, // Assign document ID
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      toppings: map['toppings'] as String?,
      productCategory: map['productCategory'] as String?,
      isFreshProduct: (map['isFreshProduct'] as bool?) ?? false,
      isProcessed: (map['isProcessed'] as bool?) ?? false,
      taxStatus: map['taxStatus'] as String?,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      thumbnailUrls: List<String>.from(
        (map['thumbnailUrls'] ?? map['imageUrls']) ?? [],
      ),
      colors: List<String>.from(map['colors'] ?? []),
      sizes: List<String>.from(map['sizes'] ?? []),
      unit: map['unit'] ?? '',
      weight: parsedWeight,
      videoUrl: map['videoUrl'] as String?,
      videoThumbnailUrl: map['videoThumbnailUrl'] as String?,
    );
  }
}