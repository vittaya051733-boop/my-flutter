class MerchantPricingPolicy {
  MerchantPricingPolicy._();

  static const double gpRate = 0.18;

  static double parseNumber(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim().replaceAll(',', '')) ?? 0;
    }
    return 0;
  }

  static double parseDiscountPercent(Object? value) {
    final parsed = parseNumber(value);
    if (parsed <= 0) {
      return 0;
    }
    if (parsed > 100) {
      return 100;
    }
    return parsed;
  }

  static double applyDiscount(double basePrice, double discountPercent) {
    final pct = parseDiscountPercent(discountPercent);
    if (pct <= 0 || basePrice <= 0) {
      return basePrice;
    }
    return basePrice * (1 - pct / 100);
  }

  static double resolveMerchantUnitPayout({
    required double merchantBasePrice,
    required double discountPercent,
  }) {
    final listed = applyDiscount(merchantBasePrice, discountPercent);
    if (listed <= 0) {
      return 0;
    }
    return listed * (1 - gpRate);
  }

  static String formatDiscountPercent(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  static double? readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim().replaceAll(',', ''));
    }
    return null;
  }

  static Map<String, dynamic>? readMap(Object? value) {
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

  static double readMerchantProductRevenue(Map<String, dynamic> data) {
    final merchantSubtotal = readDouble(data['merchantSubtotal']);
    if (merchantSubtotal != null && merchantSubtotal > 0) {
      return merchantSubtotal;
    }

    final items = data['items'] ?? data['products'];
    if (items is List) {
      final itemTotal = items.whereType<Map>().fold<double>(0, (
        runningTotal,
        item,
      ) {
        final product = readMap(item);
        if (product == null) {
          return runningTotal;
        }

        final quantity = readDouble(product['quantity']) ?? 0;
        final merchantLinePayout = readDouble(product['merchantLinePayout']);
        if (merchantLinePayout != null && merchantLinePayout > 0) {
          return runningTotal + merchantLinePayout;
        }

        final merchantUnitPayout = readDouble(product['merchantUnitPayout']);
        if (merchantUnitPayout != null && merchantUnitPayout > 0) {
          return runningTotal + (merchantUnitPayout * quantity);
        }

        final merchantBasePrice = readDouble(product['merchantBasePrice']);
        if (merchantBasePrice != null && merchantBasePrice > 0) {
          final discountPercent = parseDiscountPercent(product['discountPercent']);
          return runningTotal +
              (resolveMerchantUnitPayout(
                    merchantBasePrice: merchantBasePrice,
                    discountPercent: discountPercent,
                  ) *
                  quantity);
        }

        final legacyPrice =
            readDouble(product['price'] ?? product['unitPrice']) ?? 0;
        return runningTotal + (legacyPrice * quantity);
      });
      if (itemTotal > 0) {
        return itemTotal;
      }
    }

    final direct =
        readDouble(data['subtotal']) ?? readDouble(data['productTotal']);
    if (direct != null && direct > 0) {
      return direct;
    }

    final total =
        readDouble(data['totalAmount']) ??
        readDouble(data['grandTotal']) ??
        readDouble(data['totalPrice']) ??
        0;
    final shipping =
        readDouble(data['shippingFee']) ??
        readDouble(data['deliveryFee']) ??
        readDouble(data['deliveryCharge']) ??
        0;
    final fallback = total - shipping;
    return fallback > 0 ? fallback : total;
  }
}
