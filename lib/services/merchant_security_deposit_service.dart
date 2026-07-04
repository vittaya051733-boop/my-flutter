import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/merchant_security_deposit.dart';

class MerchantSecurityDepositService {
  MerchantSecurityDepositService._();

  static final MerchantSecurityDepositService instance =
      MerchantSecurityDepositService._();

  static const double requiredAmountBaht =
      MerchantSecurityDepositPolicy.requiredAmountBaht;

  Future<bool> isDepositPaid(String uid) async {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      return false;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(trimmedUid)
        .get();
    return snapshot.data()?['merchantSecurityDepositPaid'] == true;
  }

  Future<bool> needsDepositGate(String uid) async {
    if (await isDepositPaid(uid)) {
      return false;
    }
    if (await _hasAnyProducts(uid)) {
      return false;
    }
    return true;
  }

  Future<void> markPaid({
    required String uid,
    required double amount,
  }) async {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(trimmedUid).set(
      <String, dynamic>{
        'merchantSecurityDepositPaid': true,
        'merchantSecurityDepositPaidAt': FieldValue.serverTimestamp(),
        'merchantSecurityDepositAmount': amount,
      },
      SetOptions(merge: true),
    );
  }

  Future<bool> _hasAnyProducts(String uid) async {
    final products = await FirebaseFirestore.instance
        .collection('products')
        .where('ownerUid', isEqualTo: uid)
        .limit(1)
        .get();
    if (products.docs.isNotEmpty) {
      return true;
    }

    final pendingReviews = await FirebaseFirestore.instance
        .collection('product_admin_reviews')
        .where('ownerUid', isEqualTo: uid)
        .limit(1)
        .get();
    return pendingReviews.docs.isNotEmpty;
  }
}
