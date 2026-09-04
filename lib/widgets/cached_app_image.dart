import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/media_cache_service.dart';
import '../utils/app_image_cache.dart';
import '../utils/network_image_url.dart';
import 'web_dom_image.dart';

enum _ImageLoadPhase { loading, ready, failed }

/// Network image with disk cache, URL fallbacks, and download timeout.
class CachedAppImage extends StatefulWidget {
  const CachedAppImage({
    super.key,
    required this.imageUrl,
    this.fallbackUrls = const <String>[],
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth,
  });

  final String? imageUrl;
  final List<String> fallbackUrls;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? memCacheWidth;

  @override
  State<CachedAppImage> createState() => _CachedAppImageState();
}

class _CachedAppImageState extends State<CachedAppImage> {
  int _candidateIndex = 0;
  _ImageLoadPhase _phase = _ImageLoadPhase.loading;
  File? _localFile;
  int _loadGeneration = 0;

  List<String> get _candidates => normalizeImageUrlCandidates(<String?>[
        widget.imageUrl,
        ...widget.fallbackUrls,
      ]);

  @override
  void initState() {
    super.initState();
    unawaited(_loadCurrentCandidate());
  }

  @override
  void didUpdateWidget(CachedAppImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        !listEquals(oldWidget.fallbackUrls, widget.fallbackUrls)) {
      _candidateIndex = 0;
      _localFile = null;
      unawaited(_loadCurrentCandidate());
    }
  }

  Future<void> _loadCurrentCandidate() async {
    final generation = ++_loadGeneration;
    final candidates = _candidates;

    if (_candidateIndex >= candidates.length) {
      if (mounted) {
        setState(() {
          _phase = _ImageLoadPhase.failed;
          _localFile = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _phase = _ImageLoadPhase.loading;
        _localFile = null;
      });
    }

    final url = candidates[_candidateIndex];

    if (!kIsWeb) {
      final cachedPath = await MediaCacheService.instance.getCachedPath(url);
      if (generation != _loadGeneration || !mounted) {
        return;
      }
      if (cachedPath != null) {
        setState(() {
          _localFile = File(cachedPath);
          _phase = _ImageLoadPhase.ready;
        });
        return;
      }

      try {
        final file = await AppImageCacheManager.instance
            .getSingleFile(url)
            .timeout(kAppImageDownloadTimeout);
        if (generation != _loadGeneration || !mounted) {
          return;
        }
        setState(() {
          _localFile = file;
          _phase = _ImageLoadPhase.ready;
        });
        return;
      } on TimeoutException {
        // Try next candidate.
      } catch (_) {
        // Try next candidate.
      }
    }

    if (generation != _loadGeneration || !mounted) {
      return;
    }

    if (kIsWeb) {
      setState(() => _phase = _ImageLoadPhase.ready);
      return;
    }

    _candidateIndex += 1;
    await _loadCurrentCandidate();
  }

  void _onNetworkError() {
    if (_candidateIndex + 1 >= _candidates.length) {
      if (mounted) {
        setState(() => _phase = _ImageLoadPhase.failed);
      }
      return;
    }
    _candidateIndex += 1;
    unawaited(_loadCurrentCandidate());
  }

  Widget _defaultPlaceholder({double? w, double? h}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
        borderRadius: widget.borderRadius,
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _defaultError({double? w, double? h}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: widget.borderRadius,
      ),
      child: const Icon(Icons.broken_image_outlined),
    );
  }

  Widget _wrap(Widget child) {
    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }
    return child;
  }

  Widget _buildForUrl({
    required String url,
    required double? boxWidth,
    required double? boxHeight,
    required Widget placeholder,
    required Widget error,
  }) {
    if (kIsWeb) {
      return buildWebDomImage(
        url: url,
        width: boxWidth,
        height: boxHeight,
        fit: widget.fit,
        borderRadius: widget.borderRadius,
        errorBuilder: (_) => error,
      );
    }

    return CachedNetworkImage(
      key: ValueKey<String>(url),
      imageUrl: url,
      width: boxWidth,
      height: boxHeight,
      fit: widget.fit,
      cacheManager: AppImageCacheManager.instance,
      memCacheWidth:
          widget.memCacheWidth ?? resolveMemCacheWidth(width: boxWidth),
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _onNetworkError();
          }
        });
        return error;
      },
      fadeInDuration: const Duration(milliseconds: 150),
    );
  }

  Widget _buildContent(BoxConstraints constraints) {
    final boxWidth =
        widget.width ??
        (constraints.maxWidth.isFinite ? constraints.maxWidth : null);
    final boxHeight =
        widget.height ??
        (constraints.maxHeight.isFinite ? constraints.maxHeight : null);
    final placeholder =
        widget.placeholder ?? _defaultPlaceholder(w: boxWidth, h: boxHeight);
    final error = widget.errorWidget ?? _defaultError(w: boxWidth, h: boxHeight);

    if (_candidates.isEmpty || _phase == _ImageLoadPhase.failed) {
      return error;
    }

    if (_phase == _ImageLoadPhase.loading) {
      return placeholder;
    }

    if (!kIsWeb && _localFile != null) {
      return Image.file(
        _localFile!,
        width: boxWidth,
        height: boxHeight,
        fit: widget.fit,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _onNetworkError();
            }
          });
          return error;
        },
      );
    }

    final url = _candidates[_candidateIndex.clamp(0, _candidates.length - 1)];
    return _buildForUrl(
      url: url,
      boxWidth: boxWidth,
      boxHeight: boxHeight,
      placeholder: placeholder,
      error: error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasExplicitSize = widget.width != null && widget.height != null;
    if (hasExplicitSize) {
      return _wrap(
        _buildContent(
          BoxConstraints.tightFor(width: widget.width, height: widget.height),
        ),
      );
    }

    return _wrap(
      LayoutBuilder(
        builder: (context, constraints) => _buildContent(constraints),
      ),
    );
  }
}
