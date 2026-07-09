import 'package:flutter/material.dart';

import 'cached_app_image.dart';

/// Circular profile avatar with disk/memory image cache.
class CachedAppAvatar extends StatelessWidget {
  const CachedAppAvatar({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.backgroundColor = const Color(0xFFE0E0E0),
    this.fallback,
  });

  final String? imageUrl;
  final double radius;
  final Color backgroundColor;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: fallback,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: CachedAppImage(
            imageUrl: url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(radius),
            placeholder: ColoredBox(
              color: backgroundColor,
              child: Center(
                child: fallback ??
                    Icon(Icons.person, size: radius, color: Colors.white),
              ),
            ),
            errorWidget: Center(
              child: fallback ??
                  Icon(Icons.person, size: radius, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
