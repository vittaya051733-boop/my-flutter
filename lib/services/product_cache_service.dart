import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CachedProduct {
  const CachedProduct({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
        'id': id,
        'data': data,
      };

  factory CachedProduct.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return CachedProduct(
      id: json['id'] as String? ?? '',
      data: rawData is Map<String, dynamic>
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{},
    );
  }
}

class ProductCacheService {
  ProductCacheService._();

  static const String _keyPrefix = 'home_products_cache_';
  static final ProductCacheService instance = ProductCacheService._();

  Future<void> saveProducts(String userId, List<CachedProduct> products) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      'items': products
          .map(
            (product) => {
              'id': product.id,
              'data': _normalizeMap(product.data),
            },
          )
          .toList(),
    });
    await prefs.setString('$_keyPrefix$userId', payload);
  }

  Future<List<CachedProduct>> loadProducts(String userId) async {
    if (userId.isEmpty) return const [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$userId');
    if (raw == null) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final List items = decoded['items'] as List? ?? const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(CachedProduct.fromJson)
          .where((product) => product.id.isNotEmpty)
          .toList();
    } catch (_) {
      await prefs.remove('$_keyPrefix$userId');
      return const [];
    }
  }

  Future<void> clear(String userId) async {
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
    if (value is DocumentReference) {
      return value.path;
    }
    if (value is DateTime) {
      return value.millisecondsSinceEpoch;
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
