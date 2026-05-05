import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../models/shop_operations_settings.dart';

class ShopOperationsService {
  ShopOperationsService._();

  static final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('shop_operations');

  static DocumentReference<Map<String, dynamic>> _doc(String shopId) => _collection.doc(shopId);

  static Future<ShopOperationsSettings> fetchSettings(String shopId) async {
    try {
      final snapshot = await _doc(shopId).get();
      if (!snapshot.exists) {
        final defaults = ShopOperationsSettings.defaults();
        await _doc(shopId).set({
          ...defaults.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return defaults;
      }
      return ShopOperationsSettings.fromSnapshot(snapshot);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return ShopOperationsSettings.defaults();
      }
      rethrow;
    }
  }

  static Stream<ShopOperationsSettings> streamSettings(String shopId) {
    return _doc(shopId)
        .snapshots()
        .map(ShopOperationsSettings.fromSnapshot)
        .handleError((Object error, StackTrace stackTrace) {
          if (error is FirebaseException && error.code == 'permission-denied') {
            throw _ShopOperationsPermissionFallback();
          }
          throw error;
        })
        .transform(
          StreamTransformer<ShopOperationsSettings, ShopOperationsSettings>.fromHandlers(
            handleError: (Object error, StackTrace stackTrace, EventSink<ShopOperationsSettings> sink) {
              if (error is _ShopOperationsPermissionFallback) {
                sink.add(ShopOperationsSettings.defaults());
                return;
              }
              sink.addError(error, stackTrace);
            },
          ),
        );
  }

  static Future<void> updateSettings(String shopId, Map<String, dynamic> data) {
    return _doc(shopId).set(
      <String, dynamic>{
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

class _ShopOperationsPermissionFallback implements Exception {}
