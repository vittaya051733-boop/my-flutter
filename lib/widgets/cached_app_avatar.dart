import 'package:flutter/material.dart';

import '../utils/network_image_url.dart';
import 'cached_app_image.dart';

/// Circular profile avatar with disk/memory image cache.
class CachedAppAvatar extends StatelessWidget {
  const CachedAppAvatar({
    super.key,
    this.imageUrl,
    this.fallbackUrls = const <String>[],
    this.radius = 20,
    this.backgroundColor = const Color(0xFFE0E0E0),
    this.fallback,
  });

  final String? imageUrl;
  final List<String> fallbackUrls;
  final double radius;
  final Color backgroundColor;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final candidates = normalizeImageUrlCandidates(<String?>[
      imageUrl,
      ...fallbackUrls,
    ]);

    if (candidates.isEmpty) {
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
            imageUrl: candidates.first,
            fallbackUrls: candidates.length > 1
                ? candidates.sublist(1)
                : const <String>[],
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
