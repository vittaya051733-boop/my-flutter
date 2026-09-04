// Resolves product image URLs for merchant UI (van1).
//
// Prefer full [imageUrls] over [thumbnailUrls] — thumbnails may be missing or
// stale while originals remain valid (same approach as van2 catalog).
import 'network_image_url.dart';
export 'network_image_url.dart' show isLoadableNetworkImageUrl;

const int kProductMaxImages = 10;

List<String> _readUrlList(Object? raw) {
  if (raw is! List) {
    return const <String>[];
  }
  return raw
      .map((entry) => entry.toString().trim())
      .where(isLoadableNetworkImageUrl)
      .toList(growable: false);
}

List<String> readProductImageUrls(
  Map<String, dynamic> data, {
  int maxCount = kProductMaxImages,
}) {
  final seen = <String>{};
  final urls = <String>[];

  void addUrl(String? raw) {
    if (urls.length >= maxCount) {
      return;
    }
    final url = raw?.trim();
    if (!isLoadableNetworkImageUrl(url) || !seen.add(url!)) {
      return;
    }
    urls.add(url);
  }

  final originals = _readUrlList(data['imageUrls']);
  final thumbnails = _readUrlList(data['thumbnailUrls']);

  if (originals.isNotEmpty) {
    for (final url in originals) {
      addUrl(url);
    }
  } else {
    for (final url in thumbnails) {
      addUrl(url);
    }
  }

  for (final key in <String>['imageUrl', 'photoUrl', 'productImage']) {
    addUrl(data[key]?.toString());
  }

  final variants = data['variants'];
  if (variants is List) {
    for (final entry in variants) {
      if (entry is! Map) {
        continue;
      }
      addUrl(entry['imageUrl']?.toString());
      addUrl(entry['thumbnailUrl']?.toString());
    }
  }

  return urls;
}

/// Primary display URL — full image when available.
String? readProductImageUrl(Map<String, dynamic> data) {
  final urls = readProductImageUrls(data, maxCount: 1);
  return urls.isEmpty ? null : urls.first;
}

/// Smaller preview when available; falls back to [readProductImageUrl].
String? readProductThumbnailUrl(Map<String, dynamic> data) {
  final thumbnails = _readUrlList(data['thumbnailUrls']);
  if (thumbnails.isNotEmpty) {
    return thumbnails.first;
  }
  return readProductImageUrl(data);
}

/// Ordered candidates for [ProductNetworkImage] (original → thumbnail → legacy).
List<String> readProductImageUrlCandidates(Map<String, dynamic> data) {
  final seen = <String>{};
  final candidates = <String>[];

  void add(String? raw) {
    final url = raw?.trim();
    if (!isLoadableNetworkImageUrl(url) || !seen.add(url!)) {
      return;
    }
    candidates.add(url);
  }

  for (final url in readProductImageUrls(data)) {
    add(url);
  }
  for (final url in _readUrlList(data['thumbnailUrls'])) {
    add(url);
  }
  for (final key in <String>['imageUrl', 'photoUrl', 'productImage']) {
    add(data[key]?.toString());
  }

  return candidates;
}
