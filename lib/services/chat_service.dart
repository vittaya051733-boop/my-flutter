import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

import '../models/chat_message.dart';
import '../models/user_profile.dart';
import '../storage_helper.dart';
import '../utils/upload_image_compressor.dart';
import 'chat_warmup_cache.dart';

class ChatService {
  ChatService();

  static const String _userCollection = 'users';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = StorageHelper.instance;

  String chatIdFor(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return 'chat_${sorted.join('_')}';
  }

  Stream<List<ChatMessage>> watchMessages(String chatId, {int limit = 50}) {
    final ref = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    return Stream<List<ChatMessage>>.multi((controller) {
      final cached = ChatWarmupCache.instance.peekMessages(chatId);
      if (cached != null && cached.isNotEmpty) {
        controller.add(cached);
      }

      late StreamSubscription<QuerySnapshot<Map<String, dynamic>>> subscription;
      subscription = ref.snapshots().listen(
        (snapshot) {
          final messages = snapshot.docs
              .map((doc) => ChatMessage.fromSnapshot(doc))
              .toList();
          if (messages.isNotEmpty) {
            ChatWarmupCache.instance.putMessages(chatId, messages);
          }
          controller.add(messages);
        },
        onError: controller.addError,
        onDone: controller.close,
        cancelOnError: false,
      );

      controller.onCancel = () => subscription.cancel();
    });
  }

  Future<List<ChatMessage>> prefetchMessages(
    String chatId, {
    int limit = 50,
  }) async {
    final cached = ChatWarmupCache.instance.peekMessages(chatId);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    try {
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final messages = snapshot.docs
          .map((doc) => ChatMessage.fromSnapshot(doc))
          .toList();
      if (messages.isNotEmpty) {
        ChatWarmupCache.instance.putMessages(chatId, messages);
      }
      return messages;
    } catch (_) {
      // ห้องแชทอาจยังไม่ถูกสร้าง (permission-denied) — คืนค่าว่างไปก่อน
      return const <ChatMessage>[];
    }
  }

  Future<void> ensureChatAvailable({
    required UserProfile sender,
    required UserProfile target,
  }) async {
    final chatId = chatIdFor(sender.uid, target.uid);
    final chatDoc = _firestore.collection('chats').doc(chatId);
    await _ensureChatDocument(chatDoc, sender: sender, target: target);
  }

  Future<void> sendTextMessage({
    required UserProfile sender,
    required UserProfile target,
    required String text,
  }) async {
    await _assertMessagingAllowed(sender.uid, target.uid);

    final chatId = chatIdFor(sender.uid, target.uid);
    final chatDoc = _firestore.collection('chats').doc(chatId);
    await _ensureChatDocument(chatDoc, sender: sender, target: target);

    final now = DateTime.now();
    final messageRef = chatDoc.collection('messages').doc();
    final expiresAt = Timestamp.fromDate(now.add(const Duration(days: 30)));

    await messageRef.set({
      'senderId': sender.uid,
      'senderName': sender.displayName,
      'receiverId': target.uid,
      'type': 'text',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt,
    });

    await _updateChatSummary(
      chatDoc,
      lastMessage: text,
      lastMessageType: 'text',
      sender: sender,
      target: target,
    );
  }

  Future<void> sendMediaMessage({
    required UserProfile sender,
    required UserProfile target,
    File? file,
    Uint8List? fileBytes,
    required String messageType,
    required String fileName,
    String? contentType,
  }) async {
    await _assertMessagingAllowed(sender.uid, target.uid);

    final chatId = chatIdFor(sender.uid, target.uid);
    final chatDoc = _firestore.collection('chats').doc(chatId);
    await _ensureChatDocument(chatDoc, sender: sender, target: target);

    var uploadBytes = await _resolveUploadBytes(file: file, fileBytes: fileBytes);
    if (uploadBytes.isEmpty) {
      throw const ChatServiceException('ไม่พบไฟล์สำหรับอัปโหลด');
    }

    var uploadFileName = p.basename(fileName);
    var uploadContentType = contentType ?? _guessMimeType(fileName);

    if (messageType == 'image') {
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/chat_img_${DateTime.now().microsecondsSinceEpoch}',
      );
      await tempFile.writeAsBytes(uploadBytes, flush: true);
      try {
        final compressed = await UploadImageCompressor.compressForUpload(tempFile);
        uploadBytes = await compressed.file.readAsBytes();
        uploadFileName = compressed.fileName;
        uploadContentType = compressed.contentType;
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    }

    final storageRef = _storage.ref().child(
      'chat_uploads/$chatId/${DateTime.now().millisecondsSinceEpoch}_$uploadFileName',
    );
    final metadata = SettableMetadata(contentType: uploadContentType);
    await storageRef.putData(uploadBytes, metadata);
    final downloadUrl = await storageRef.getDownloadURL();

    final summaryText = _summaryForType(messageType, uploadFileName);
    final expiresAt = Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)));
    final messageRef = chatDoc.collection('messages').doc();
    await messageRef.set({
      'senderId': sender.uid,
      'senderName': sender.displayName,
      'receiverId': target.uid,
      'type': messageType,
      'text': summaryText,
      'mediaUrl': downloadUrl,
      'fileName': uploadFileName,
      'fileSize': uploadBytes.length,
      'mediaContentType': metadata.contentType,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt,
    });

    await _updateChatSummary(
      chatDoc,
      lastMessage: summaryText,
      lastMessageType: messageType,
      sender: sender,
      target: target,
    );
  }

  Future<Uint8List> _resolveUploadBytes({
    File? file,
    Uint8List? fileBytes,
  }) async {
    if (file != null && await file.exists()) {
      return file.readAsBytes();
    }
    if (fileBytes != null && fileBytes.isNotEmpty) {
      return fileBytes;
    }
    return Uint8List(0);
  }

  Future<void> _assertMessagingAllowed(String senderId, String targetId) async {
    final blocked = await _firestore
        .collection(_userCollection)
        .doc(senderId)
        .collection('blocked')
        .doc(targetId)
        .get();
    if (blocked.exists) {
      throw const ChatServiceException('คุณบล็อกผู้ใช้นี้แล้ว ไม่สามารถส่งข้อความได้');
    }
  }

  Future<void> logCallEvent({
    required UserProfile initiator,
    required UserProfile target,
    required bool isVideo,
    required bool answered,
    Duration? duration,
    bool declined = false,
  }) async {
    final chatId = chatIdFor(initiator.uid, target.uid);
    final chatDoc = _firestore.collection('chats').doc(chatId);
    await _ensureChatDocument(chatDoc, sender: initiator, target: target);

    final String statusText;
    if (declined) {
      statusText = 'ยกเลิกสาย';
    } else if (!answered) {
      statusText = 'ไม่ได้รับสาย';
    } else {
      statusText = 'สนทนา ${_formatDuration(duration)}';
    }
    final base = isVideo ? 'วิดีโอคอล' : 'โทรด้วยเสียง';
    final description = '$base • $statusText';
    final messageRef = chatDoc.collection('messages').doc();
    await messageRef.set({
      'senderId': initiator.uid,
      'senderName': initiator.displayName,
      'receiverId': target.uid,
      'type': 'call',
      'callType': isVideo ? 'video' : 'voice',
      'direction': 'outgoing',
      'callStatus': answered ? 'answered' : (declined ? 'declined' : 'missed'),
      if (duration != null && answered) 'callDuration': duration.inSeconds,
      'text': description,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _updateChatSummary(
      chatDoc,
      lastMessage: description,
      lastMessageType: 'call',
      sender: initiator,
      target: target,
    );
  }

  Future<void> markChatAsRead({
    required UserProfile owner,
    required UserProfile friend,
  }) async {
    final chatDoc = _firestore.collection('chats').doc(chatIdFor(owner.uid, friend.uid));
    final ownerFriendRef = _firestore
        .collection(_userCollection)
        .doc(owner.uid)
        .collection('friends')
        .doc(friend.uid);

    final batch = _firestore.batch();
    batch.set(
      chatDoc,
      {
        'unreadCounts.${owner.uid}': 0,
        'lastReadAt.${owner.uid}': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      ownerFriendRef,
      {
        'uid': friend.uid,
        ...friend.toFirestore(),
        'unreadCount': 0,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> purgeExpiredMessages(String chatId) async {
    final now = Timestamp.fromDate(DateTime.now());
    final ref = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('expiresAt', isLessThanOrEqualTo: now)
        .limit(50);
    final snapshot = await ref.get();
    if (snapshot.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> _ensureChatDocument(
    DocumentReference<Map<String, dynamic>> chatDoc, {
    required UserProfile sender,
    required UserProfile target,
  }) async {
    await chatDoc.set({
      'participants': [sender.uid, target.uid],
      'participantProfiles': {
        sender.uid: sender.toFirestore(),
        target.uid: target.toFirestore(),
      },
      'participantNames': {
        sender.uid: sender.displayName,
        target.uid: target.displayName,
      },
      'unreadCounts': {
        sender.uid: 0,
        target.uid: 0,
      },
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _updateChatSummary(
    DocumentReference<Map<String, dynamic>> chatDoc, {
    required String lastMessage,
    required String lastMessageType,
    required UserProfile sender,
    required UserProfile target,
  }) async {
    final senderFriendRef = _firestore
        .collection(_userCollection)
        .doc(sender.uid)
        .collection('friends')
        .doc(target.uid);
    final targetFriendRef = _firestore
        .collection(_userCollection)
        .doc(target.uid)
        .collection('friends')
        .doc(sender.uid);

    final senderBatch = _firestore.batch();
    senderBatch.set(
      chatDoc,
      {
        'lastMessage': lastMessage,
        'lastMessageType': lastMessageType,
        'lastMessageSender': sender.uid,
        'lastSenderId': sender.uid,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCounts.${sender.uid}': 0,
        'unreadCounts.${target.uid}': FieldValue.increment(1),
        'lastReadAt.${sender.uid}': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    senderBatch.set(
      senderFriendRef,
      {
        'uid': target.uid,
        ...target.toFirestore(),
        'lastMessage': lastMessage,
        'lastActivity': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      },
      SetOptions(merge: true),
    );
    await senderBatch.commit();

    // The recipient preview is supplementary. A cross-user preview write can
    // be rejected by stricter rules or an older deployed ruleset; that must
    // not make an already-sent message look like it failed.
    try {
      await targetFriendRef.set(
        {
          'uid': sender.uid,
          ...sender.toFirestore(),
          'lastMessage': lastMessage,
          'lastActivity': FieldValue.serverTimestamp(),
          'unreadCount': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException {
      // The chat document still carries the recipient unread count.
    }
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }

  String _summaryForType(String type, String fileName) {
    switch (type) {
      case 'image':
        return 'ส่งรูปภาพ';
      case 'video':
        return 'ส่งวิดีโอ';
      case 'file':
        return 'ส่งไฟล์: $fileName';
      case 'call':
        return fileName;
      default:
        return fileName;
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '00:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class ChatServiceException implements Exception {
  const ChatServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
