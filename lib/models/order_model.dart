import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_model.dart';

// โมเดลสำหรับข้อมูลลูกค้า
class Customer {
  final String name;
  final String address;
  final String phoneNumber;

  Customer({
    required this.name,
    required this.address,
    required this.phoneNumber,
  });
}

class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final String? imageUrl;
  final String? toppings;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.imageUrl,
    this.toppings,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'imageUrl': imageUrl,
      'toppings': toppings,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'],
      toppings: map['toppings'],
    );
  }
}

class NotificationStatus {
  final bool sent;
  final DateTime? sentAt;
  final double timeInMinutes;

  NotificationStatus({
    required this.sent,
    this.sentAt,
    required this.timeInMinutes,
  });

  Map<String, dynamic> toMap() {
    return {
      'sent': sent,
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'timeInMinutes': timeInMinutes,
    };
  }

  factory NotificationStatus.fromMap(Map<String, dynamic> map) {
    return NotificationStatus(
      sent: map['sent'] ?? false,
      sentAt: map['sentAt'] != null ? (map['sentAt'] as Timestamp).toDate() : null,
      timeInMinutes: (map['timeInMinutes'] ?? 0).toDouble(),
    );
  }
}

// โมเดลสำหรับข้อมูลออเดอร์
class Order {
  final String id;
  final Customer customer;
  final List<Product> items;
  final double totalPrice;
  final DateTime orderDate;
  final String status;

  Order({
    required this.id,
    required this.customer,
    required this.items,
    required this.totalPrice,
    required this.orderDate,
    required this.status,
  });
}

class DetailedOrder {
  final String orderId;
  final String customerId;
  final String shopId;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  final List<OrderItem> items;
  final double totalAmount;
  final int totalItems;
  
  final String status; // pending, accepted, preparing, ready, delivering, delivered, cancelled
  final DateTime? acceptedAt;
  final DateTime? preparingStartTime;
  final int preparingDuration; // milliseconds (default 10 min = 600000)
  final DateTime? readyAt;
  final DateTime? deliveryStartTime;
  final DateTime? deliveredAt;
  
  final Map<String, NotificationStatus> notifications;
  final double penalty;
  
  final GeoPoint? customerLocation;
  final String customerAddress;
  final GeoPoint? shopLocation;
  final String shopAddress;
  final double distance; // meters
  final int estimatedDeliveryTime; // minutes
  
  final String orderQRCode;
  final String locationQRCode;
  final String? scannedByDriverId;
  final DateTime? scannedAt;
  
  final String customerName;
  final String customerPhone;
  final String? driverId;
  final String? driverName;
  
  final String? shopFCMToken;
  final String? customerFCMToken;
  final String? driverFCMToken;

  DetailedOrder({
    required this.orderId,
    required this.customerId,
    required this.shopId,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    required this.totalAmount,
    required this.totalItems,
    required this.status,
    this.acceptedAt,
    this.preparingStartTime,
    this.preparingDuration = 600000,
    this.readyAt,
    this.deliveryStartTime,
    this.deliveredAt,
    required this.notifications,
    this.penalty = 0,
    this.customerLocation,
    required this.customerAddress,
    this.shopLocation,
    required this.shopAddress,
    this.distance = 0,
    this.estimatedDeliveryTime = 0,
    required this.orderQRCode,
    required this.locationQRCode,
    this.scannedByDriverId,
    this.scannedAt,
    required this.customerName,
    required this.customerPhone,
    this.driverId,
    this.driverName,
    this.shopFCMToken,
    this.customerFCMToken,
    this.driverFCMToken,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'customerId': customerId,
      'shopId': shopId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'totalItems': totalItems,
      'status': status,
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'preparingStartTime': preparingStartTime != null ? Timestamp.fromDate(preparingStartTime!) : null,
      'preparingDuration': preparingDuration,
      'readyAt': readyAt != null ? Timestamp.fromDate(readyAt!) : null,
      'deliveryStartTime': deliveryStartTime != null ? Timestamp.fromDate(deliveryStartTime!) : null,
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'notifications': notifications.map((key, value) => MapEntry(key, value.toMap())),
      'penalty': penalty,
      'customerLocation': customerLocation,
      'customerAddress': customerAddress,
      'shopLocation': shopLocation,
      'shopAddress': shopAddress,
      'distance': distance,
      'estimatedDeliveryTime': estimatedDeliveryTime,
      'orderQRCode': orderQRCode,
      'locationQRCode': locationQRCode,
      'scannedByDriverId': scannedByDriverId,
      'scannedAt': scannedAt != null ? Timestamp.fromDate(scannedAt!) : null,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'driverId': driverId,
      'driverName': driverName,
      'shopFCMToken': shopFCMToken,
      'customerFCMToken': customerFCMToken,
      'driverFCMToken': driverFCMToken,
    };
  }

  factory DetailedOrder.fromMap(Map<String, dynamic> map) {
    return DetailedOrder(
      orderId: map['orderId'] ?? '',
      customerId: map['customerId'] ?? '',
      shopId: map['shopId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      items: (map['items'] as List<dynamic>?)
          ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList() ?? [],
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      totalItems: map['totalItems'] ?? 0,
      status: map['status'] ?? 'pending',
      acceptedAt: map['acceptedAt'] != null ? (map['acceptedAt'] as Timestamp).toDate() : null,
      preparingStartTime: map['preparingStartTime'] != null ? (map['preparingStartTime'] as Timestamp).toDate() : null,
      preparingDuration: map['preparingDuration'] ?? 600000,
      readyAt: map['readyAt'] != null ? (map['readyAt'] as Timestamp).toDate() : null,
      deliveryStartTime: map['deliveryStartTime'] != null ? (map['deliveryStartTime'] as Timestamp).toDate() : null,
      deliveredAt: map['deliveredAt'] != null ? (map['deliveredAt'] as Timestamp).toDate() : null,
      notifications: (map['notifications'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, NotificationStatus.fromMap(value as Map<String, dynamic>)),
      ) ?? {},
      penalty: (map['penalty'] ?? 0).toDouble(),
      customerLocation: map['customerLocation'] as GeoPoint?,
      customerAddress: map['customerAddress'] ?? '',
      shopLocation: map['shopLocation'] as GeoPoint?,
      shopAddress: map['shopAddress'] ?? '',
      distance: (map['distance'] ?? 0).toDouble(),
      estimatedDeliveryTime: map['estimatedDeliveryTime'] ?? 0,
      orderQRCode: map['orderQRCode'] ?? '',
      locationQRCode: map['locationQRCode'] ?? '',
      scannedByDriverId: map['scannedByDriverId'],
      scannedAt: map['scannedAt'] != null ? (map['scannedAt'] as Timestamp).toDate() : null,
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      driverId: map['driverId'],
      driverName: map['driverName'],
      shopFCMToken: map['shopFCMToken'],
      customerFCMToken: map['customerFCMToken'],
      driverFCMToken: map['driverFCMToken'],
    );
  }

  factory DetailedOrder.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return DetailedOrder.fromMap(snapshot.data()!);
  }

  DetailedOrder copyWith({
    String? status,
    DateTime? acceptedAt,
    DateTime? preparingStartTime,
    DateTime? readyAt,
    DateTime? deliveryStartTime,
    DateTime? deliveredAt,
    Map<String, NotificationStatus>? notifications,
    double? penalty,
    String? scannedByDriverId,
    DateTime? scannedAt,
    String? driverId,
    String? driverName,
  }) {
    return DetailedOrder(
      orderId: orderId,
      customerId: customerId,
      shopId: shopId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      items: items,
      totalAmount: totalAmount,
      totalItems: totalItems,
      status: status ?? this.status,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      preparingStartTime: preparingStartTime ?? this.preparingStartTime,
      preparingDuration: preparingDuration,
      readyAt: readyAt ?? this.readyAt,
      deliveryStartTime: deliveryStartTime ?? this.deliveryStartTime,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      notifications: notifications ?? this.notifications,
      penalty: penalty ?? this.penalty,
      customerLocation: customerLocation,
      customerAddress: customerAddress,
      shopLocation: shopLocation,
      shopAddress: shopAddress,
      distance: distance,
      estimatedDeliveryTime: estimatedDeliveryTime,
      orderQRCode: orderQRCode,
      locationQRCode: locationQRCode,
      scannedByDriverId: scannedByDriverId ?? this.scannedByDriverId,
      scannedAt: scannedAt ?? this.scannedAt,
      customerName: customerName,
      customerPhone: customerPhone,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      shopFCMToken: shopFCMToken,
      customerFCMToken: customerFCMToken,
      driverFCMToken: driverFCMToken,
    );
  }
}
