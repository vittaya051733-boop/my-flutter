import 'package:cloud_firestore/cloud_firestore.dart';

/// Single chat message inside chats/{chatId}/messages
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.type,
    this.text,
    this.mediaUrl,
    this.fileName,
    this.fileSize,
    this.mediaContentType,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String senderId;
  final String type; // text, image, video, file
  final String? text;
  final String? mediaUrl;
  final String? fileName;
  final int? fileSize;
  final String? mediaContentType;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  factory ChatMessage.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdTs = data['createdAt'] as Timestamp?;
    final expiresTs = data['expiresAt'] as Timestamp?;
    return ChatMessage(
      id: doc.id,
      senderId: (data['senderId'] ?? '') as String,
      type: (data['type'] ?? 'text') as String,
      text: data['text'] as String?,
      mediaUrl: data['mediaUrl'] as String?,
      fileName: data['fileName'] as String?,
      fileSize: (data['fileSize'] as num?)?.toInt(),
      mediaContentType: data['mediaContentType'] as String?,
      createdAt: createdTs?.toDate(),
      expiresAt: expiresTs?.toDate(),
    );
  }
}
