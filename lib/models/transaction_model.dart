import 'package:cloud_firestore/cloud_firestore.dart';
class TransactionModel {
  final String id;
  final String fromUid;
  final String toUid;
  final double amount;
  final String type; // receive, pay, transfer
  final DateTime timestamp;

  TransactionModel({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.amount,
    required this.type,
    required this.timestamp,
  });

  factory TransactionModel.fromMap(String id, Map<String, dynamic> map) {
    return TransactionModel(
      id: id,
      fromUid: map['fromUid'] ?? '',
      toUid: map['toUid'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      type: map['type'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fromUid': fromUid,
      'toUid': toUid,
      'amount': amount,
      'type': type,
      'timestamp': timestamp,
    };
  }
}
