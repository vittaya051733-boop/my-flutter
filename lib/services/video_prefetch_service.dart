import 'dart:async';

import 'package:better_player/better_player.dart';
import 'package:flutter/foundation.dart';

import 'video_source_helper.dart';

/// Preloads the first ~30 seconds of network videos for smoother playback.
class VideoPrefetchService {
  VideoPrefetchService._();

  static final VideoPrefetchService instance = VideoPrefetchService._();

  static const BetterPlayerConfiguration _prefetchConfig =
      BetterPlayerConfiguration(
    autoPlay: false,
    autoDispose: false,
    handleLifecycle: false,
  );

  final Set<String> _inFlight = <String>{};
  final Set<String> _completed = <String>{};

  /// Start preloading a single video URL.
  void preloadVideo(String? url) {
    if (url == null) return;
    final normalized = url.trim();
    if (normalized.isEmpty ||
        _inFlight.contains(normalized) ||
        _completed.contains(normalized)) {
      return;
    }
    _inFlight.add(normalized);
    unawaited(_prefetch(normalized));
  }

  /// Start preloading multiple URLs sequentially.
  void preloadVideos(Iterable<String?> urls) {
    for (final url in urls) {
      preloadVideo(url);
    }
  }

  Future<void> _prefetch(String url) async {
    BetterPlayerController? controller;
    try {
      final resolvedUrl = await VideoSourceHelper.resolveMediaUrl(url);
      if (!VideoSourceHelper.isNetworkUrl(resolvedUrl)) {
        _completed.add(url);
        return;
      }

      final dataSource = VideoSourceHelper.buildDataSource(resolvedUrl);
      controller = BetterPlayerController(
        _prefetchConfig,
        betterPlayerDataSource: dataSource,
      );
      await controller.preCache(dataSource);
      _completed.add(url);
    } catch (error, stack) {
      debugPrint('VideoPrefetchService: Failed to prefetch $url -> $error\n$stack');
    } finally {
      controller?.dispose(forceDispose: true);
      _inFlight.remove(url);
    }
  }
}
