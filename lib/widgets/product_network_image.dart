import 'package:flutter/material.dart';

import 'cached_app_image.dart';

/// Loads a remote product image with fallback URLs and download timeout.
class ProductNetworkImage extends StatelessWidget {
  const ProductNetworkImage({
    super.key,
    required this.urls,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth = 500,
  });

  final List<String> urls;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int memCacheWidth;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return _errorBox();
    }

    return CachedAppImage(
      key: ValueKey<String>(urls.first),
      imageUrl: urls.first,
      fallbackUrls: urls.length > 1 ? urls.sublist(1) : const <String>[],
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      errorWidget: _errorBox(),
    );
  }

  Widget _errorBox() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image, size: 36, color: Colors.grey),
    );
  }
}
