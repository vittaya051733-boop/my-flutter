import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShopProfileCacheService {
  ShopProfileCacheService._();

  static final ShopProfileCacheService instance = ShopProfileCacheService._();
  static const String _keyPrefix = 'shop_profile_cache_';

  Future<void> saveProfile(String userId, Map<String, dynamic> data) async {
    if (userId.isEmpty || data.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalizeMap(data);
    final payload = jsonEncode({
      'cachedAt': DateTime.now().millisecondsSinceEpoch,
      'data': normalized,
    });
    await prefs.setString('$_keyPrefix$userId', payload);
  }

  Future<Map<String, dynamic>?> loadProfile(String userId) async {
    if (userId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$userId');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(data);
      }
    } catch (_) {
      await prefs.remove('$_keyPrefix$userId');
    }
    return null;
  }

  Future<void> clearProfile(String userId) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$userId');
  }

  Map<String, dynamic> _normalizeMap(Map<String, dynamic> input) {
    return input.map(
      (key, value) => MapEntry(key, _normalizeValue(value)),
    );
  }

  dynamic _normalizeValue(dynamic value) {
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }
    if (value is GeoPoint) {
      return {
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }
    if (value is Map) {
      return value.map(
        (key, nestedValue) => MapEntry(key.toString(), _normalizeValue(nestedValue)),
      );
    }
    if (value is Iterable) {
      return value.map(_normalizeValue).toList();
    }
    return value;
  }
}
