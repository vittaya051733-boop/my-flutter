import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Loads a remote product image with fallback URLs and a loading timeout.
class ProductNetworkImage extends StatefulWidget {
  const ProductNetworkImage({
    super.key,
    required this.urls,
    this.fit = BoxFit.cover,
    this.memCacheWidth = 500,
    this.maxWidthDiskCache = 800,
    this.loadingTimeout = const Duration(seconds: 12),
  });

  final List<String> urls;
  final BoxFit fit;
  final int memCacheWidth;
  final int maxWidthDiskCache;
  final Duration loadingTimeout;

  @override
  State<ProductNetworkImage> createState() => _ProductNetworkImageState();
}

class _ProductNetworkImageState extends State<ProductNetworkImage> {
  int _candidateIndex = 0;
  bool _timedOut = false;
  Timer? _timer;

  List<String> get _candidates => widget.urls
      .map((url) => url.trim())
      .where((url) => url.startsWith('http://') || url.startsWith('https://'))
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _armTimeout();
  }

  @override
  void didUpdateWidget(covariant ProductNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urls != widget.urls) {
      _candidateIndex = 0;
      _timedOut = false;
      _armTimeout();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _armTimeout() {
    _timer?.cancel();
    if (_candidates.isEmpty) {
      return;
    }
    _timer = Timer(widget.loadingTimeout, () {
      if (!mounted || _timedOut) {
        return;
      }
      setState(() => _timedOut = true);
    });
  }

  void _tryNextCandidate() {
    _timer?.cancel();
    if (_candidateIndex + 1 >= _candidates.length) {
      return;
    }
    setState(() {
      _candidateIndex += 1;
      _timedOut = false;
    });
    _armTimeout();
  }

  void _onLoaded() {
    _timer?.cancel();
    if (_timedOut && mounted) {
      setState(() => _timedOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_candidates.isEmpty || _timedOut) {
      return _errorBox();
    }

    final url = _candidates[_candidateIndex.clamp(0, _candidates.length - 1)];

    return CachedNetworkImage(
      imageUrl: url,
      fit: widget.fit,
      memCacheWidth: widget.memCacheWidth,
      maxWidthDiskCache: widget.maxWidthDiskCache,
      placeholder: (context, _) => _loadingBox(),
      errorWidget: (context, _, __) {
        if (_candidateIndex + 1 < _candidates.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _tryNextCandidate();
            }
          });
          return _loadingBox();
        }
        return _errorBox();
      },
      imageBuilder: (context, imageProvider) {
        _onLoaded();
        return Image(
          image: imageProvider,
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
        );
      },
    );
  }

  Widget _loadingBox() {
    return Container(
      color: Colors.grey[100],
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _errorBox() {
    return Container(
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image, size: 36, color: Colors.grey),
    );
  }
}
