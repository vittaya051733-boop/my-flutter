import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'friend_service.dart';

/// Disk cache for the chat friend list (stale-while-revalidate).
class FriendListCacheService {
  FriendListCacheService._();

  static final FriendListCacheService instance = FriendListCacheService._();

  static const String _keyPrefix = 'chat_friends_cache_v1_';

  Future<void> save(String userId, List<FriendPreview> friends) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(<String, dynamic>{
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      'items': friends.map((friend) => friend.toJson()).toList(),
    });
    await prefs.setString('$_keyPrefix$userId', payload);
  }

  Future<List<FriendPreview>> load(String userId) async {
    if (userId.isEmpty) return const <FriendPreview>[];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$userId');
    if (raw == null || raw.isEmpty) {
      return const <FriendPreview>[];
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final items = decoded['items'];
      if (items is! List) {
        return const <FriendPreview>[];
      }
      return items
          .whereType<Map<String, dynamic>>()
          .map(FriendPreview.fromJson)
          .where((friend) => friend.profile.uid.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      await prefs.remove('$_keyPrefix$userId');
      return const <FriendPreview>[];
    }
  }

  Future<void> clear(String userId) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$userId');
  }
}
