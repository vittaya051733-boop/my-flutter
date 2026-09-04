import 'dart:collection';

import 'network_image_url.dart';

/// Helper methods for resolving shop profile fields that may use
/// different key names or be nested in various structures.
class ShopProfileResolver {
  ShopProfileResolver._();

  static const List<String> _imageKeys = <String>[
    'shopimageurl',
    'shopimage',
    'imageurl',
    'image',
    'logourl',
    'logo',
    'photourl',
    'profileimageurl',
    'profileimage',
    'avatarurl',
    'avatar',
    'coverurl',
    'coverimage',
    'storeimage',
    'thumbnailurl',
  ];

  static const List<String> _nameKeys = <String>[
    'shopname',
    'name',
    'displayname',
    'businessname',
    'storename',
    'brandname',
    'title',
  ];

  static String? resolveImageUrl(Map<String, dynamic>? data) {
    final direct = firstLoadableImageUrl(readProfilePhotoCandidates(data));
    if (direct != null) {
      return direct;
    }
    return firstLoadableImageUrl(<String?>[
      _resolveValueByKeys(data, _imageKeys),
    ]);
  }

  static String? resolveName(Map<String, dynamic>? data) {
    return _resolveValueByKeys(data, _nameKeys);
  }

  static int? resolveAdminMaxImageCount(Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }
    final raw = data['adminMaxImageCount'];
    if (raw is num) {
      final value = raw.toInt();
      return value > 0 ? value.clamp(1, 30) : null;
    }
    final parsed = int.tryParse(raw?.toString() ?? '');
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed.clamp(1, 30);
  }

  static bool? resolveAdminCanUploadVideo(Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }
    final raw = data['adminCanUploadVideo'];
    if (raw is bool) {
      return raw;
    }
    if (raw is num) {
      return raw != 0;
    }
    final normalized = raw?.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
    return null;
  }

  static String? _resolveValueByKeys(
    Map<String, dynamic>? data,
    List<String> candidateKeys,
  ) {
    if (data == null || data.isEmpty) {
      return null;
    }

    final Set<String> normalizedKeys =
        candidateKeys.map((key) => key.toLowerCase()).toSet();
    final ListQueue<Map<String, dynamic>> queue =
        ListQueue<Map<String, dynamic>>();
    queue.add(_stringKeyedMap(data));

    while (queue.isNotEmpty) {
      final Map<String, dynamic> current = queue.removeFirst();
      for (final MapEntry<String, dynamic> entry in current.entries) {
        final String key = entry.key.toLowerCase();
        final dynamic value = entry.value;

        if (normalizedKeys.contains(key) && value is String) {
          final String trimmed = value.trim();
          if (trimmed.isNotEmpty) {
            return trimmed;
          }
        }

        if (value is Map) {
          queue.add(_stringKeyedMap(value));
        } else if (value is Iterable) {
          for (final dynamic nested in value) {
            if (nested is Map) {
              queue.add(_stringKeyedMap(nested));
            }
          }
        }
      }
    }
    return null;
  }

  static Map<String, dynamic> _stringKeyedMap(Map<dynamic, dynamic> source) {
    return source.map((dynamic key, dynamic value) {
      return MapEntry<String, dynamic>(key.toString(), value);
    });
  }
}
