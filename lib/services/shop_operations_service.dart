import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shop_operations_settings.dart';

class ShopOperationsService {
  ShopOperationsService._();

  static final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('shop_operations');

  static DocumentReference<Map<String, dynamic>> _doc(String shopId) => _collection.doc(shopId);

  static Future<ShopOperationsSettings> fetchSettings(String shopId) async {
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
  }

  static Stream<ShopOperationsSettings> streamSettings(String shopId) {
    return _doc(shopId).snapshots().map(ShopOperationsSettings.fromSnapshot);
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
