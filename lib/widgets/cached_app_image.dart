import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/media_cache_service.dart';
import '../utils/app_image_cache.dart';
import '../utils/network_image_url.dart';
import 'web_dom_image.dart';

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
  File? _localUploadFile;
  bool _localUploadFailed = false;
  bool _advancing = false;

  List<String> get _candidates => normalizeImageUrlCandidates(<String?>[
        widget.imageUrl,
        ...widget.fallbackUrls,
      ]);

  String? get _currentUrl {
    final candidates = _candidates;
    if (candidates.isEmpty) {
      return null;
    }
    return candidates[_candidateIndex.clamp(0, candidates.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    unawaited(_resolveLocalUpload());
  }

  @override
  void didUpdateWidget(CachedAppImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        !listEquals(oldWidget.fallbackUrls, widget.fallbackUrls)) {
      _candidateIndex = 0;
      _localUploadFile = null;
      _localUploadFailed = false;
      _advancing = false;
      unawaited(_resolveLocalUpload());
    }
  }

  Future<void> _resolveLocalUpload() async {
    if (kIsWeb) {
      return;
    }
    final url = _currentUrl;
    if (url == null) {
      return;
    }
    try {
      final cachedPath = await MediaCacheService.instance.getCachedPath(url);
      if (!mounted || cachedPath == null || _currentUrl != url) {
        return;
      }
      setState(() {
        _localUploadFile = File(cachedPath);
        _localUploadFailed = false;
      });
    } catch (_) {
      // CachedNetworkImage still loads from the network.
    }
  }

  void _advanceCandidate() {
    if (_advancing || !mounted) {
      return;
    }
    final next = _candidateIndex + 1;
    if (next >= _candidates.length) {
      return;
    }
    _advancing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _candidateIndex = next;
        _localUploadFile = null;
        _localUploadFailed = false;
        _advancing = false;
      });
      unawaited(_resolveLocalUpload());
    });
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

  Widget _buildNetworkImage({
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
        errorBuilder: (_) {
          _advanceCandidate();
          return error;
        },
      );
    }

    return Image.network(
      key: ValueKey<String>('net-$url'),
      url,
      width: boxWidth,
      height: boxHeight,
      fit: widget.fit,
      cacheWidth: widget.memCacheWidth ?? resolveMemCacheWidth(width: boxWidth),
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return placeholder;
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }
        return placeholder;
      },
      errorBuilder: (_, errorDetails, ___) {
        debugPrint('Image load failed: $url ($errorDetails)');
        _advanceCandidate();
        return error;
      },
    );
  }

  Widget _buildContent(BoxConstraints constraints) {
    final boxWidth = widget.width ??
        (constraints.maxWidth.isFinite ? constraints.maxWidth : null);
    final boxHeight = widget.height ??
        (constraints.maxHeight.isFinite ? constraints.maxHeight : null);
    final placeholder =
        widget.placeholder ?? _defaultPlaceholder(w: boxWidth, h: boxHeight);
    final error = widget.errorWidget ?? _defaultError(w: boxWidth, h: boxHeight);
    final url = _currentUrl;

    if (url == null) {
      return error;
    }

    if (!kIsWeb && _localUploadFile != null && !_localUploadFailed) {
      return Image.file(
        _localUploadFile!,
        width: boxWidth,
        height: boxHeight,
        fit: widget.fit,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _localUploadFailed = true);
            }
          });
          return _buildNetworkImage(
            url: url,
            boxWidth: boxWidth,
            boxHeight: boxHeight,
            placeholder: placeholder,
            error: error,
          );
        },
      );
    }

    return _buildNetworkImage(
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
