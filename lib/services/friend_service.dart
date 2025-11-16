import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

class FriendService {
  FriendService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const List<String> _shopCollections = <String>[
    'market_registrations',
    'shop_registrations',
    'restaurant_registrations',
    'pharmacy_registrations',
    'other_registrations',
  ];

  Stream<List<FriendPreview>> watchFriends(String ownerId) {
    final ref = _firestore
        .collection('users')
        .doc(ownerId)
        .collection('friends')
        .orderBy('lastActivity', descending: true);

    return ref.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => FriendPreview.fromSnapshot(doc))
          .toList(),
    );
  }

  Future<UserProfile?> ensureCurrentUserProfile(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    if (snapshot.exists && snapshot.data()?['displayName'] != null) {
      return UserProfile.fromSnapshot(snapshot);
    }

    final data = await _loadShopData(user.uid);
    final normalizedPhone = _normalizePhone(
      (data?['phone'] ?? data?['phoneNumber'] ?? user.phoneNumber ?? '') as String,
    );

    final bool profileCompleted = (data?['isProfileCompleted'] as bool?) ?? false;
    final profile = UserProfile(
      uid: user.uid,
      displayName: _readDisplayName(data, fallback: user.displayName ?? user.email ?? 'ร้านของฉัน'),
      phoneNumber: normalizedPhone,
      photoUrl: _readPhotoUrl(data) ?? user.photoURL,
      serviceType: (data?['serviceType'] as String?) ?? (data?['collection'] as String?),
      isOfficial: (data?['isOfficialAccount'] as bool?) ?? false,
      profileCompleted: profileCompleted,
    );

    await docRef.set(
      <String, dynamic>{
        ...profile.toFirestore(),
        if (profile.phoneNumber != null && profile.phoneNumber!.isNotEmpty)
          'phoneNumber': profile.phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return profile;
  }

  Future<UserProfile?> getProfile(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!snapshot.exists) return null;
    return UserProfile.fromSnapshot(snapshot);
  }

  Future<UserProfile?> findUserByPhone(String rawInput) async {
    final normalized = _normalizePhone(rawInput);
    if (normalized.isEmpty) return null;

    final directQuery = await _firestore
        .collection('users')
        .where('phoneNumber', isEqualTo: normalized)
        .limit(1)
        .get();
    if (directQuery.docs.isNotEmpty) {
      return UserProfile.fromSnapshot(directQuery.docs.first);
    }

    for (final collection in _shopCollections) {
      final query = await _firestore
          .collection(collection)
          .where('phone', isEqualTo: normalized)
          .limit(1)
          .get();
      if (query.docs.isEmpty) continue;
      final doc = query.docs.first;
      final data = doc.data();
      final profile = UserProfile(
        uid: doc.id,
        displayName: _readDisplayName(data, fallback: 'ผู้ใช้ใหม่'),
        phoneNumber: normalized,
        photoUrl: _readPhotoUrl(data),
        serviceType: (data['serviceType'] as String?) ?? collection,
        isOfficial: (data['isOfficialAccount'] as bool?) ?? false,
        profileCompleted: (data['isProfileCompleted'] as bool?) ?? false,
      );

      await _firestore.collection('users').doc(doc.id).set(
            <String, dynamic>{
              ...profile.toFirestore(),
              'phoneNumber': normalized,
              'createdAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
      return profile;
    }
    return null;
  }

  Future<List<UserProfile>> fetchSuggestedProfiles({
    required String ownerId,
    int limit = 12,
  }) async {
    final exclude = <String>{ownerId};
    final existingFriends = await _firestore
        .collection('users')
        .doc(ownerId)
        .collection('friends')
        .get();
    for (final doc in existingFriends.docs) {
      exclude.add(doc.id);
    }

    final perCollectionLimit = (limit * 2).clamp(6, 30);
    final futures = _shopCollections.map(
      (collection) => _firestore
          .collectionGroup(collection)
          .where('isProfileCompleted', isEqualTo: true)
          .limit(perCollectionLimit)
          .get(),
    );

    final snapshots = await Future.wait(futures);
    final suggestions = <UserProfile>[];
    for (var i = 0; i < snapshots.length; i++) {
      final collection = _shopCollections[i];
      for (final doc in snapshots[i].docs) {
        if (exclude.contains(doc.id)) continue;
        final data = doc.data();
        final profile = UserProfile(
          uid: doc.id,
          displayName: _readDisplayName(data, fallback: 'ร้านค้า'),
          phoneNumber: _normalizePhone((data['phone'] ?? data['phoneNumber'] ?? '') as String),
          photoUrl: _readPhotoUrl(data),
          serviceType: (data['serviceType'] as String?) ?? collection,
          isOfficial: (data['isOfficialAccount'] as bool?) ?? false,
          profileCompleted: (data['isProfileCompleted'] as bool?) ?? true,
        );
        suggestions.add(profile);
        if (suggestions.length >= limit) break;
      }
      if (suggestions.length >= limit) break;
    }
    return suggestions;
  }

  Future<void> addFriend({
    required String ownerId,
    required UserProfile friend,
  }) async {
    if (ownerId == friend.uid) {
      throw const FriendException('ไม่สามารถเพิ่มตัวเองเป็นเพื่อนได้');
    }

    final ownerFriendRef =
        _firestore.collection('users').doc(ownerId).collection('friends').doc(friend.uid);
    final already = await ownerFriendRef.get();
    if (already.exists) {
      throw const FriendException('คุณเพิ่มเพื่อนคนนี้ไว้แล้ว');
    }

    final ownerProfile = await getProfile(ownerId);
    if (ownerProfile == null) {
      throw const FriendException('ไม่พบข้อมูลร้านของคุณ');
    }

    final now = FieldValue.serverTimestamp();
    final reverseRef =
        _firestore.collection('users').doc(friend.uid).collection('friends').doc(ownerId);

    final batch = _firestore.batch();
    batch.set(ownerFriendRef, <String, dynamic>{
      ...friend.toFirestore(),
      'uid': friend.uid,
      'lastMessage': 'เพิ่งเพิ่มเป็นเพื่อน',
      'lastActivity': now,
      'unreadCount': 0,
      'isMuted': false,
      'addedAt': now,
    });

    batch.set(reverseRef, <String, dynamic>{
      ...ownerProfile.toFirestore(),
      'uid': ownerId,
      'lastMessage': 'เพิ่งเพิ่มเป็นเพื่อน',
      'lastActivity': now,
      'unreadCount': 0,
      'isMuted': false,
      'addedAt': now,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<Map<String, dynamic>?> _loadShopData(String uid) async {
    for (final collection in _shopCollections) {
      final snapshot = await _firestore.collection(collection).doc(uid).get();
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          return <String, dynamic>{...data, 'collection': collection};
        }
      }
    }
    return null;
  }

  static String _readDisplayName(Map<String, dynamic>? data, {required String fallback}) {
    if (data == null) return fallback;
    final candidates = <String?>[
      data['displayName'] as String?,
      data['shopName'] as String?,
      data['name'] as String?,
    ];
    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return fallback;
  }

  static String? _readPhotoUrl(Map<String, dynamic>? data) {
    if (data == null) return null;
    final candidates = <String?>[
      data['shopImageUrl'] as String?,
      data['imageUrl'] as String?,
      data['logoUrl'] as String?,
      data['profileImageUrl'] as String?,
    ];
    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  static String _normalizePhone(String raw) {
    var clean = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return '';
    if (clean.startsWith('00')) {
      clean = '+${clean.substring(2)}';
    }
    if (clean.startsWith('0') && clean.length == 10) {
      return '+66${clean.substring(1)}';
    }
    if (!clean.startsWith('+') && clean.length >= 9) {
      return '+$clean';
    }
    return clean;
  }
}

class FriendPreview {
  FriendPreview({
    required this.profile,
    this.lastMessage = 'แตะเพื่อเริ่มสนทนา',
    this.unreadCount = 0,
    this.lastActivity,
    this.isMuted = false,
  });

  final UserProfile profile;
  final String lastMessage;
  final int unreadCount;
  final DateTime? lastActivity;
  final bool isMuted;

  factory FriendPreview.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final Timestamp? ts = data['lastActivity'] as Timestamp?;
    return FriendPreview(
      profile: UserProfile.fromMap(data['uid']?.toString() ?? doc.id, data),
      lastMessage: (data['lastMessage'] as String?) ?? 'แตะเพื่อเริ่มสนทนา',
      unreadCount: (data['unreadCount'] as int?) ?? 0,
      lastActivity: ts?.toDate(),
      isMuted: (data['isMuted'] as bool?) ?? false,
    );
  }

  String get lastActivityLabel {
    if (lastActivity == null) return '';
    final now = DateTime.now();
    final diff = now.difference(lastActivity!);
    if (diff.inDays == 0) {
      final hours = lastActivity!.hour.toString().padLeft(2, '0');
      final minutes = lastActivity!.minute.toString().padLeft(2, '0');
      return '$hours:$minutes';
    }
    if (diff.inDays == 1) {
      return 'เมื่อวาน';
    }
    if (diff.inDays < 7) {
      const thaiWeekdays = <int, String>{
        DateTime.monday: 'จ.',
        DateTime.tuesday: 'อ.',
        DateTime.wednesday: 'พ.',
        DateTime.thursday: 'พฤ.',
        DateTime.friday: 'ศ.',
        DateTime.saturday: 'ส.',
        DateTime.sunday: 'อา.',
      };
      return thaiWeekdays[lastActivity!.weekday] ?? '';
    }
    final month = lastActivity!.month.toString().padLeft(2, '0');
    final day = lastActivity!.day.toString().padLeft(2, '0');
    return '$day/$month';
  }
}

class FriendException implements Exception {
  const FriendException(this.message);
  final String message;

  @override
  String toString() => message;
}
