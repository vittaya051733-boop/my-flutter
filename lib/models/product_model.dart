
class Product {
  final String name;
  final String description;
  final double price;
  final int stock;
  final List<String> colors;
  final List<String> sizes;
  final double? weight;
  final String unit;
  // In a real app, these would be file paths or URLs
  final List<String> imageUrls; 
  final String? videoUrl;

  Product({
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.colors,
    required this.sizes,
    this.weight,
    required this.unit,
    this.imageUrls = const [],
    this.videoUrl,
  });
}
