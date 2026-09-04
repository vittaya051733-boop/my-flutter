/// Shared helpers for remote image URLs (products, avatars, shop profile).
bool isLoadableNetworkImageUrl(String? raw) {
  final url = raw?.trim();
  if (url == null || url.isEmpty) {
    return false;
  }
  return url.startsWith('http://') || url.startsWith('https://');
}

List<String> normalizeImageUrlCandidates(
  Iterable<String?> urls, {
  int maxCount = 8,
}) {
  final seen = <String>{};
  final candidates = <String>[];
  for (final raw in urls) {
    if (candidates.length >= maxCount) {
      break;
    }
    final url = raw?.trim();
    if (!isLoadableNetworkImageUrl(url) || !seen.add(url!)) {
      continue;
    }
    candidates.add(url);
  }
  return candidates;
}

String? firstLoadableImageUrl(Iterable<String?> urls) {
  final candidates = normalizeImageUrlCandidates(urls, maxCount: 1);
  return candidates.isEmpty ? null : candidates.first;
}

List<String> readProfilePhotoCandidates(Map<String, dynamic>? data) {
  if (data == null || data.isEmpty) {
    return const <String>[];
  }
  return normalizeImageUrlCandidates(<String?>[
    data['photoUrl']?.toString(),
    data['imageUrl']?.toString(),
    data['shopImageUrl']?.toString(),
    data['avatarUrl']?.toString(),
    data['profileImageUrl']?.toString(),
    data['shopImage']?.toString(),
    data['logoUrl']?.toString(),
    data['thumbnailUrl']?.toString(),
  ]);
}
