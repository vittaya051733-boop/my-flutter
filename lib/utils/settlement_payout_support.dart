import '../merchant_pricing_policy.dart';

class SettlementPayoutInfo {
  const SettlementPayoutInfo({
    required this.amount,
    required this.status,
  });

  final double amount;
  final String status;
}

/// แสดงรายได้จากออเดอร์ในกระเป๋าเงินเมื่อครบเวลาที่แอดมินกำหนดแล้วเท่านั้น
bool shouldShowShopOrderRevenueInWallet(Map<String, dynamic> orderData) {
  final now = DateTime.now();
  final settlement = _readMap(orderData['settlement']);
  final shopPayout = _readMap(settlement?['shopPayout']);
  final shopCreditRelease = _readMap(settlement?['shopCreditRelease']);
  final shopPayoutStatus =
      orderData['shopPayoutStatus']?.toString().trim().toLowerCase() ?? '';
  final shopCreditReleaseStatus =
      orderData['shopCreditReleaseStatus']?.toString().trim().toLowerCase() ??
          '';

  if (shopCreditReleaseStatus == 'released' ||
      shopCreditRelease?['status']?.toString().trim().toLowerCase() ==
          'released') {
    return true;
  }

  if (shopCreditReleaseStatus == 'scheduled') {
    return false;
  }

  if (shopPayout != null) {
    final status = shopPayout['status']?.toString().trim().toLowerCase() ?? '';
    if (status == 'available' || status == 'paid') {
      return true;
    }
    if (status == 'failed') {
      return false;
    }
    if (status == 'scheduled') {
      return false;
    }
    if (status == 'pending') {
      final availableAt = _toDateTime(shopPayout['availableForWithdrawAt']);
      if (availableAt != null) {
        return !availableAt.isAfter(now);
      }
      if (_toDateTime(shopPayout['promotedAt']) != null) {
        return true;
      }
      return false;
    }
  }

  if (shopPayoutStatus == 'scheduled') {
    return false;
  }
  if (shopPayoutStatus == 'pending' || shopPayoutStatus == 'available') {
    final releaseAt = _toDateTime(orderData['shopPayoutReleaseAt']);
    if (releaseAt != null && releaseAt.isAfter(now)) {
      return false;
    }
    return true;
  }

  if (shopPayout == null &&
      shopCreditRelease == null &&
      shopPayoutStatus.isEmpty &&
      shopCreditReleaseStatus.isEmpty) {
    return true;
  }

  return false;
}

/// เวลาที่ควรใช้เรียงประวัติ — หลังปล่อยเครดิต ไม่ใช่ตอนส่งสินค้า
DateTime? shopOrderRevenueWalletTimestamp(Map<String, dynamic> orderData) {
  final settlement = _readMap(orderData['settlement']);
  final shopPayout = _readMap(settlement?['shopPayout']);
  final shopCreditRelease = _readMap(settlement?['shopCreditRelease']);

  return _toDateTime(shopCreditRelease?['releasedAt']) ??
      _toDateTime(shopPayout?['promotedAt']) ??
      _toDateTime(shopPayout?['availableForWithdrawAt']) ??
      _toDateTime(orderData['shopPayoutReleaseAt']) ??
      _toDateTime(orderData['deliveredAt']) ??
      _toDateTime(orderData['deliveryCompletedAt']) ??
      _toDateTime(orderData['updatedAt']) ??
      _toDateTime(orderData['createdAt']);
}

SettlementPayoutInfo? readShopPayoutInfo(Map<String, dynamic> orderData) {
  final settlement = _readMap(orderData['settlement']);
  final payout = _readMap(settlement?['shopPayout']);
  final release = _readMap(settlement?['shopCreditRelease']);
  final status = payout?['status']?.toString() ??
      release?['status']?.toString() ??
      'pending';
  final amount = _readDouble(payout?['amount']) ??
      _readDouble(release?['amount']) ??
      MerchantPricingPolicy.readMerchantProductRevenue(orderData);
  if (amount <= 0) {
    return null;
  }

  return SettlementPayoutInfo(
    amount: amount,
    status: status,
  );
}

DateTime? _toDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  try {
    final dynamic converted = (value as dynamic).toDate();
    if (converted is DateTime) {
      return converted;
    }
  } catch (_) {
    // not a Firestore Timestamp
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

Map<String, dynamic>? _readMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
  return null;
}

double? _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}
