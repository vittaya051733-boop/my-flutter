import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// On-device cache for product/avatar images in van1 merchant app.
class AppImageCacheManager extends CacheManager {
  AppImageCacheManager._()
      : super(
          Config(
            'van1_merchant_images_v1',
            stalePeriod: const Duration(days: 30),
            maxNrOfCacheObjects: 2000,
          ),
        );

  static final AppImageCacheManager instance = AppImageCacheManager._();
}

const Duration kAppImageDownloadTimeout = Duration(seconds: 12);

int? resolveMemCacheWidth({double? width, int maxPx = 512}) {
  if (width == null || !width.isFinite || width <= 0) {
    return maxPx;
  }
  return (width * 2).round().clamp(64, maxPx);
}
