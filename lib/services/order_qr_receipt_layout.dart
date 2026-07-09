import 'package:intl/intl.dart';

import '../models/order_model.dart';

class OrderQrReceiptItemLine {
  const OrderQrReceiptItemLine({
    required this.name,
    required this.quantity,
    required this.lineTotal,
    this.toppings,
  });

  final String name;
  final int quantity;
  final double lineTotal;
  final String? toppings;
}

class OrderQrReceiptLayout {
  const OrderQrReceiptLayout({
    required this.orderId,
    required this.orderCode,
    required this.dateTimeText,
    required this.items,
    required this.productSubtotal,
    required this.shippingFee,
    required this.grandTotal,
  });

  final String orderId;
  final String orderCode;
  final String dateTimeText;
  final List<OrderQrReceiptItemLine> items;
  final double productSubtotal;
  final double shippingFee;
  final double grandTotal;
}

String formatOrderQrMoney(double amount) {
  return '${amount.toStringAsFixed(2)} บาท';
}

String formatOrderQrDateTime(DateTime value) {
  try {
    return DateFormat('d MMM yyyy HH:mm', 'th_TH').format(value.toLocal());
  } catch (_) {
    return DateFormat('d MMM yyyy HH:mm').format(value.toLocal());
  }
}

double orderQrProductSubtotal(DetailedOrder order) {
  final itemTotal = order.items.fold<double>(
    0,
    (runningTotal, item) => runningTotal + (item.price * item.quantity),
  );
  if (itemTotal > 0) return itemTotal;
  final fromGrandTotal = order.totalAmount - order.shippingFee;
  return fromGrandTotal > 0 ? fromGrandTotal : order.totalAmount;
}

OrderQrReceiptLayout buildOrderQrReceiptLayout(DetailedOrder order) {
  final orderCode = order.orderCode?.trim() ?? '';
  final items = order.items.map((item) {
    final name = item.productName.trim().isEmpty ? '-' : item.productName.trim();
    final toppings = item.toppings?.trim();
    return OrderQrReceiptItemLine(
      name: name,
      quantity: item.quantity,
      lineTotal: item.price * item.quantity,
      toppings: toppings != null && toppings.isNotEmpty ? toppings : null,
    );
  }).toList();

  return OrderQrReceiptLayout(
    orderId: order.orderId,
    orderCode: orderCode,
    dateTimeText: formatOrderQrDateTime(order.createdAt),
    items: items,
    productSubtotal: orderQrProductSubtotal(order),
    shippingFee: order.shippingFee,
    grandTotal: order.totalAmount,
  );
}
