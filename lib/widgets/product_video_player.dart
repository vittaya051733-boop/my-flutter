import 'dart:async';
import 'dart:io';

import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../services/media_cache_service.dart';
import '../services/video_source_helper.dart';
import 'cached_app_image.dart';

class ProductVideoPlayer extends StatefulWidget {
  const ProductVideoPlayer({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
  });

  final String videoUrl;
  final String? thumbnailUrl;

  @override
  State<ProductVideoPlayer> createState() => _ProductVideoPlayerState();
}

class _ProductVideoPlayerState extends State<ProductVideoPlayer> {
  final Key _visibilityKey = UniqueKey();
  _BetterPlayerPoolHandle? _poolHandle;
  BetterPlayerController? _controller;
  bool _hasError = false;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isVisible = false;
  bool _isInitializingController = false;
  int _thumbnailRequestId = 0;
  String? _thumbnailSource;
  bool _thumbnailIsFile = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(ProductVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoUrl != oldWidget.videoUrl) {
      unawaited(_releaseController());
      _loadThumbnail();
    }
    if (widget.thumbnailUrl != oldWidget.thumbnailUrl) {
      _loadThumbnail();
    }
  }

  Future<void> _ensureControllerInitialized() async {
    if (_poolHandle != null || _isInitializingController || !_isVisible) {
      _controller?.play();
      return;
    }
    _isInitializingController = true;
    try {
      final resolvedUrl = await VideoSourceHelper.resolveMediaUrl(widget.videoUrl);
      if (!mounted || !_isVisible) {
        return;
      }
      final dataSource = VideoSourceHelper.buildDataSource(resolvedUrl);
      final handle = await _BetterPlayerControllerPool.acquire(widget.videoUrl, dataSource);
      if (!mounted || !_isVisible) {
        await handle.release(_handleBetterPlayerEvent);
        return;
      }
      handle.controller.addEventsListener(_handleBetterPlayerEvent);
      setState(() {
        _poolHandle = handle;
        _controller = handle.controller;
        _hasError = false;
        _isBuffering = true;
      });
      handle.controller.play();
    } catch (error) {
      debugPrint('ProductVideoPlayer: init error -> $error');
      setState(() => _hasError = true);
    } finally {
      _isInitializingController = false;
    }
  }

  Future<void> _loadThumbnail() async {
    final requestId = ++_thumbnailRequestId;
    final url = widget.thumbnailUrl;
    if (url != null && url.isNotEmpty) {
      final cachedPath = await MediaCacheService.instance.getCachedPath(url);
      if (!mounted || requestId != _thumbnailRequestId) {
        return;
      }
      setState(() {
        _thumbnailSource = cachedPath ?? url;
        _thumbnailIsFile = cachedPath != null || !VideoSourceHelper.isNetworkUrl(url);
      });
      return;
    }

    await _loadOrCreateFallbackThumbnail(requestId);
  }

  Future<void> _loadOrCreateFallbackThumbnail(int requestId) async {
    final fallbackKey = _fallbackCacheKey;
    final cached = await MediaCacheService.instance.getCachedPath(fallbackKey);
    if (!mounted || requestId != _thumbnailRequestId) {
      return;
    }
    if (cached != null) {
      setState(() {
        _thumbnailSource = cached;
        _thumbnailIsFile = true;
      });
      return;
    }

    try {
      final resolvedVideo = await VideoSourceHelper.resolveMediaUrl(widget.videoUrl);
      final tempPath = await VideoThumbnail.thumbnailFile(
        video: resolvedVideo,
        imageFormat: ImageFormat.PNG,
        quality: 80,
      );
      if (!mounted || requestId != _thumbnailRequestId || tempPath == null) {
        if (tempPath != null) {
          final tempFile = File(tempPath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
        return;
      }

      final tempFile = File(tempPath);
      File? cachedFile;
      try {
        cachedFile = await MediaCacheService.instance.cacheUploadedFile(
          source: tempFile,
          url: fallbackKey,
          bucket: MediaCacheBucket.videoThumbnail,
        );
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }

      final localPath = cachedFile?.path;
      if (!mounted || requestId != _thumbnailRequestId) {
        return;
      }

      if (localPath != null) {
        setState(() {
          _thumbnailSource = localPath;
          _thumbnailIsFile = true;
        });
      }
    } catch (error) {
      debugPrint('ProductVideoPlayer: Failed to generate fallback thumbnail: $error');
    }
  }

  String get _fallbackCacheKey => 'generated_video_thumb::${widget.videoUrl}';

  void _handleBetterPlayerEvent(BetterPlayerEvent event) {
    if (!mounted) return;
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.exception:
        setState(() => _hasError = true);
        unawaited(_releaseController());
        break;
      case BetterPlayerEventType.initialized:
        setState(() => _isInitialized = true);
        break;
      case BetterPlayerEventType.play:
        setState(() {
          _isPlaying = true;
          _isBuffering = false;
        });
        break;
      case BetterPlayerEventType.bufferingStart:
        setState(() => _isBuffering = true);
        break;
      case BetterPlayerEventType.bufferingEnd:
        setState(() => _isBuffering = false);
        break;
      case BetterPlayerEventType.finished:
      case BetterPlayerEventType.pause:
        setState(() => _isBuffering = false);
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    unawaited(_releaseController());
    super.dispose();
  }

  Future<void> _releaseController() async {
    final handle = _poolHandle;
    if (handle == null) return;
    _poolHandle = null;
    await handle.release(_handleBetterPlayerEvent);
    if (mounted) {
      setState(() {
        _controller = null;
        _isInitialized = false;
        _isPlaying = false;
        _isBuffering = false;
      });
    }
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    final mostlyVisible = info.visibleFraction >= 0.6;
    final hidden = info.visibleFraction == 0;

    if (mostlyVisible) {
      if (!_isVisible) {
        _isVisible = true;
        _ensureControllerInitialized();
      } else {
        _controller?.play();
      }
    } else {
      if (_isVisible) {
        _isVisible = false;
        _controller?.pause();
      }
      if (hidden) {
        unawaited(_releaseController());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 8),
            Text('ไม่สามารถเล่นวิดีโอได้', style: TextStyle(color: Colors.red)),
          ],
        ),
      );
    }

    final controller = _controller;
    final hasThumbnail = _thumbnailSource != null && _thumbnailSource!.isNotEmpty;
    final showPlaceholder = hasThumbnail && (!_isInitialized || !_isPlaying || _isBuffering);

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _handleVisibilityChanged,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null)
            BetterPlayer(controller: controller)
          else
            const SizedBox.shrink(),
          if (hasThumbnail)
            IgnorePointer(
              ignoring: true,
              child: AnimatedOpacity(
                opacity: showPlaceholder ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: _buildPlaceholder(),
              ),
            ),
          if (controller == null && _isVisible)
            const _InlineLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    final source = _thumbnailSource;
    if (source == null || source.isEmpty) {
      return const DecoratedBox(
        decoration: BoxDecoration(color: Colors.black),
      );
    }

    final Widget child;
    if (_thumbnailIsFile) {
      child = Image.file(
        File(source),
        fit: BoxFit.cover,
      );
    } else {
      child = CachedAppImage(
        imageUrl: source,
        fit: BoxFit.cover,
        errorWidget: const DecoratedBox(
          decoration: BoxDecoration(color: Colors.black),
        ),
      );
    }

    return SizedBox.expand(child: child);
  }
}

class _InlineLoadingOverlay extends StatelessWidget {
  const _InlineLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

typedef _BetterPlayerEventListener = void Function(BetterPlayerEvent event);

class _BetterPlayerPoolHandle {
  _BetterPlayerPoolHandle(this._cacheKey, this.controller);

  final String _cacheKey;
  final BetterPlayerController controller;

  Future<void> release(_BetterPlayerEventListener listener) async {
    controller.removeEventsListener(listener);
    await _BetterPlayerControllerPool.release(_cacheKey, controller);
  }
}

class _CachedControllerEntry {
  _CachedControllerEntry(this.controller) : insertedAt = DateTime.now();

  final BetterPlayerController controller;
  final DateTime insertedAt;
}

class _BetterPlayerControllerPool {
  static const Duration _maxIdleAge = Duration(minutes: 2);
  static const int _maxEntries = 4;
  static final Map<String, _CachedControllerEntry> _idle = <String, _CachedControllerEntry>{};
  static const BetterPlayerConfiguration _config = BetterPlayerConfiguration(
    autoPlay: false,
    looping: true,
    fit: BoxFit.cover,
    allowedScreenSleep: false,
    handleLifecycle: true,
    controlsConfiguration: BetterPlayerControlsConfiguration(
      showControls: false,
      showControlsOnInitialize: false,
      enablePlayPause: false,
      enableFullscreen: false,
      enableMute: false,
      enableProgressBar: false,
      enableProgressBarDrag: false,
      enableProgressText: false,
      enableSkips: false,
      enableOverflowMenu: false,
      enablePlaybackSpeed: false,
      enableSubtitles: false,
      enableQualities: false,
      enableAudioTracks: false,
      enableRetry: false,
      enablePip: false,
      loadingWidget: SizedBox.shrink(),
    ),
  );

  static Future<_BetterPlayerPoolHandle> acquire(
    String cacheKey,
    BetterPlayerDataSource dataSource,
  ) async {
    _evictExpired();
    final cached = _idle.remove(cacheKey);
    if (cached != null) {
      return _BetterPlayerPoolHandle(cacheKey, cached.controller);
    }
    final controller = BetterPlayerController(_config, betterPlayerDataSource: dataSource);
    return _BetterPlayerPoolHandle(cacheKey, controller);
  }

  static Future<void> release(String cacheKey, BetterPlayerController controller) async {
    controller.pause();
    if (_idle.length >= _maxEntries) {
      final oldestKey = _idle.entries
          .reduce((a, b) => a.value.insertedAt.isBefore(b.value.insertedAt) ? a : b)
          .key;
      final removed = _idle.remove(oldestKey);
      removed?.controller.dispose();
    }
    _idle[cacheKey] = _CachedControllerEntry(controller);
  }

  static void _evictExpired() {
    final now = DateTime.now();
    final expiredKeys = _idle.entries
        .where((entry) => now.difference(entry.value.insertedAt) > _maxIdleAge)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in expiredKeys) {
      final removed = _idle.remove(key);
      removed?.controller.dispose();
    }
  }
}
