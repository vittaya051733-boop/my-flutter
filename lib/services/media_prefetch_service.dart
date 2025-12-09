import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class MediaPrefetchService {
  MediaPrefetchService._();

  static final MediaPrefetchService instance = MediaPrefetchService._();

  final BaseCacheManager _cacheManager = DefaultCacheManager();

  Future<void> prefetchImages(Iterable<String> urls) async {
    for (final url in urls) {
      if (url.isEmpty) continue;
      unawaited(_prefetch(url));
    }
  }

  Future<void> _prefetch(String url) async {
    final cached = await _cacheManager.getFileFromCache(url);
    if (cached != null) {
      return;
    }
    try {
      await _cacheManager.downloadFile(url);
    } catch (_) {
      // best effort only
    }
  }
}
