import '../merchant_pricing_policy.dart';

class SettlementPayoutInfo {
  const SettlementPayoutInfo({
    required this.amount,
    required this.status,
    required this.displayStatus,
  });

  final double amount;
  final String status;
  final String displayStatus;
}

String formatSettlementPayoutDisplayStatus(String? rawStatus) {
  final status = rawStatus?.trim().toLowerCase() ?? '';
  switch (status) {
    case 'paid':
      return 'จ่ายแล้ว';
    case 'failed':
      return 'โอนไม่สำเร็จ';
    case 'pending':
    case 'exported':
    case '':
      return 'รอชำระ';
    default:
      return 'รอชำระ';
  }
}

SettlementPayoutInfo? readShopPayoutInfo(Map<String, dynamic> orderData) {
  final settlement = _readMap(orderData['settlement']);
  final payout = _readMap(settlement?['shopPayout']);
  final status = payout?['status']?.toString() ?? 'pending';
  final amount = _readDouble(payout?['amount']) ??
      MerchantPricingPolicy.readMerchantProductRevenue(orderData);
  if (amount <= 0) {
    return null;
  }
  return SettlementPayoutInfo(
    amount: amount,
    status: status,
    displayStatus: formatSettlementPayoutDisplayStatus(status),
  );
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
