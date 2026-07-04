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
    final selectedToppings = _readStringList(map['selectedToppings']);
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? map['name'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: _readDouble(map['price'] ?? map['unitPrice']) ?? 0,
      imageUrl: _readOrderItemImageUrl(map),
      toppings: selectedToppings.isNotEmpty
          ? selectedToppings.join(', ')
          : _readToppingsText(map['toppings']),
    );
  }

  static String? _readOrderItemImageUrl(Map<String, dynamic> map) {
    for (final key in <String>['imageUrl', 'productImage']) {
      final direct = map[key]?.toString().trim();
      if (direct != null && direct.isNotEmpty) {
        return direct;
      }
    }
    final fromArray =
        _firstNonEmptyUrl(map['imageUrls']) ??
        _firstNonEmptyUrl(map['thumbnailUrls']);
    if (fromArray != null) {
      return fromArray;
    }
    for (final key in <String>['photoUrl', 'thumbnailUrl']) {
      final fallback = map[key]?.toString().trim();
      if (fallback != null && fallback.isNotEmpty) {
        return fallback;
      }
    }
    return null;
  }

  static String? _firstNonEmptyUrl(dynamic raw) {
    if (raw is! List) {
      return null;
    }
    for (final entry in raw) {
      final url = entry?.toString().trim();
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }
    return null;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String && value.trim().isNotEmpty) {
      return <String>[value.trim()];
    }
    return const <String>[];
  }

  static String? _readToppingsText(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    final values = _readStringList(value);
    return values.isEmpty ? null : values.join(', ');
  }

  static double? _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
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
      sentAt: map['sentAt'] != null
          ? (map['sentAt'] as Timestamp).toDate()
          : null,
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
  final String? orderCode;
  final String customerId;
  final String shopId;
  final DateTime createdAt;
  final DateTime updatedAt;

  final List<OrderItem> items;
  final double totalAmount;
  final int totalItems;
  final double shippingFee;
  final String orderType;
  final String fulfillmentType;
  final String shippingProvider;
  final String shippingProviderLabel;
  final String shippingStatus;
  final String shippingStatusLabel;
  final Map<String, dynamic> deliveryAddress;

  final String
  status; // pending, accepted, preparing, ready, delivering, delivered, cancelled
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
  final String? driverPhone;

  final String? shopFCMToken;
  final String? customerFCMToken;
  final String? driverFCMToken;

  DetailedOrder({
    required this.orderId,
    this.orderCode,
    required this.customerId,
    required this.shopId,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    required this.totalAmount,
    required this.totalItems,
    this.shippingFee = 0,
    this.orderType = '',
    this.fulfillmentType = '',
    this.shippingProvider = '',
    this.shippingProviderLabel = '',
    this.shippingStatus = '',
    this.shippingStatusLabel = '',
    this.deliveryAddress = const <String, dynamic>{},
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
    this.driverPhone,
    this.shopFCMToken,
    this.customerFCMToken,
    this.driverFCMToken,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      if (orderCode != null) 'orderCode': orderCode,
      'customerId': customerId,
      'shopId': shopId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'totalItems': totalItems,
      'shippingFee': shippingFee,
      if (orderType.isNotEmpty) 'orderType': orderType,
      if (fulfillmentType.isNotEmpty) 'fulfillmentType': fulfillmentType,
      if (shippingProvider.isNotEmpty) 'shippingProvider': shippingProvider,
      if (shippingProviderLabel.isNotEmpty)
        'shippingProviderLabel': shippingProviderLabel,
      if (shippingStatus.isNotEmpty) 'shippingStatus': shippingStatus,
      if (shippingStatusLabel.isNotEmpty)
        'shippingStatusLabel': shippingStatusLabel,
      if (deliveryAddress.isNotEmpty) 'deliveryAddress': deliveryAddress,
      'status': status,
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'preparingStartTime': preparingStartTime != null
          ? Timestamp.fromDate(preparingStartTime!)
          : null,
      'preparingDuration': preparingDuration,
      'readyAt': readyAt != null ? Timestamp.fromDate(readyAt!) : null,
      'deliveryStartTime': deliveryStartTime != null
          ? Timestamp.fromDate(deliveryStartTime!)
          : null,
      'deliveredAt': deliveredAt != null
          ? Timestamp.fromDate(deliveredAt!)
          : null,
      'notifications': notifications.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
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
      'driverPhone': driverPhone,
      'shopFCMToken': shopFCMToken,
      'customerFCMToken': customerFCMToken,
      'driverFCMToken': driverFCMToken,
    };
  }

  factory DetailedOrder.fromMap(Map<String, dynamic> map) {
    final rawItems = (map['items'] ?? map['products']) as List<dynamic>?;
    final subtotal = _readDouble(map['subtotal'] ?? map['totalPrice']) ?? 0;
    final grandTotal =
        _readDouble(
          map['totalAmount'] ?? map['grandTotal'] ?? map['totalPrice'],
        ) ??
        0;
    final shippingFee = _readShippingFee(
      map,
      subtotal: subtotal,
      grandTotal: grandTotal,
    );
    return DetailedOrder(
      orderId: map['orderId'] ?? '',
      orderCode: (map['orderCode'] ?? map['orderNumber'])?.toString(),
      customerId: map['customerId'] ?? '',
      shopId: map['shopId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      items:
          rawItems
              ?.whereType<Map>()
              .map((item) => OrderItem.fromMap(Map<String, dynamic>.from(item)))
              .toList() ??
          [],
      totalAmount: grandTotal,
      totalItems:
          map['totalItems'] ?? map['totalQuantity'] ?? map['itemCount'] ?? 0,
      shippingFee: shippingFee,
      orderType: (map['orderType'] ?? '').toString(),
      fulfillmentType: (map['fulfillmentType'] ?? '').toString(),
      shippingProvider: (map['shippingProvider'] ?? '').toString(),
      shippingProviderLabel: (map['shippingProviderLabel'] ?? '').toString(),
      shippingStatus: (map['shippingStatus'] ?? '').toString(),
      shippingStatusLabel: (map['shippingStatusLabel'] ?? '').toString(),
      deliveryAddress: map['deliveryAddress'] is Map
          ? Map<String, dynamic>.from(map['deliveryAddress'] as Map)
          : const <String, dynamic>{},
      status: map['status'] ?? 'pending',
      acceptedAt: map['acceptedAt'] != null
          ? (map['acceptedAt'] as Timestamp).toDate()
          : null,
      preparingStartTime: map['preparingStartTime'] != null
          ? (map['preparingStartTime'] as Timestamp).toDate()
          : null,
      preparingDuration: map['preparingDuration'] ?? 600000,
      readyAt: map['readyAt'] != null
          ? (map['readyAt'] as Timestamp).toDate()
          : null,
      deliveryStartTime: map['deliveryStartTime'] != null
          ? (map['deliveryStartTime'] as Timestamp).toDate()
          : null,
      deliveredAt: map['deliveredAt'] != null
          ? (map['deliveredAt'] as Timestamp).toDate()
          : null,
      notifications:
          (map['notifications'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              NotificationStatus.fromMap(value as Map<String, dynamic>),
            ),
          ) ??
          {},
      penalty: (map['penalty'] ?? 0).toDouble(),
      customerLocation: _readGeoPoint(map['customerLocation']),
      customerAddress: _readCustomerAddress(map),
      shopLocation: _readGeoPoint(map['shopLocation']),
      shopAddress: map['shopAddress'] ?? '',
      distance: (map['distance'] ?? 0).toDouble(),
      estimatedDeliveryTime: map['estimatedDeliveryTime'] ?? 0,
      orderQRCode: map['orderQRCode'] ?? '',
      locationQRCode: map['locationQRCode'] ?? '',
      scannedByDriverId: map['scannedByDriverId'],
      scannedAt: map['scannedAt'] != null
          ? (map['scannedAt'] as Timestamp).toDate()
          : null,
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      driverId: map['driverId'],
      driverName: map['driverName'],
      driverPhone: map['driverPhone'] as String?,
      shopFCMToken: map['shopFCMToken'],
      customerFCMToken: map['customerFCMToken'],
      driverFCMToken: map['driverFCMToken'],
    );
  }

  static GeoPoint? _readGeoPoint(dynamic value) {
    if (value is GeoPoint) {
      return value;
    }
    if (value is Map) {
      final lat = _readDouble(
        value['latitude'] ?? value['lat'] ?? value['_latitude'],
      );
      final lng = _readDouble(
        value['longitude'] ??
            value['lng'] ??
            value['lon'] ??
            value['_longitude'],
      );
      if (lat != null && lng != null) {
        return GeoPoint(lat, lng);
      }
    }
    return null;
  }

  static double? _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static double _readShippingFee(
    Map<String, dynamic> map, {
    required double subtotal,
    required double grandTotal,
  }) {
    final direct =
        _readDouble(map['shippingFee']) ??
        _readDouble(map['deliveryFee']) ??
        _readDouble(map['deliveryCharge']) ??
        _readDouble(map['shipping']);
    if (direct != null) {
      return direct;
    }
    final delta = grandTotal - subtotal;
    return delta > 0 ? delta : 0;
  }

  static String _readCustomerAddress(Map<String, dynamic> map) {
    final direct = (map['customerAddress'] as String?)?.trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final deliverySnapshot = map['deliverySnapshot'];
    if (deliverySnapshot is Map) {
      final label = (deliverySnapshot['locationLabel'] as String?)?.trim();
      if (label != null && label.isNotEmpty) {
        return label;
      }
    }
    final deliveryAddress = map['deliveryAddress'];
    if (deliveryAddress is Map) {
      final label = (deliveryAddress['label'] as String?)?.trim();
      if (label != null && label.isNotEmpty) {
        return label;
      }
      final parts = <String>[
        (deliveryAddress['addressLine'] ?? '').toString().trim(),
        (deliveryAddress['subDistrict'] ?? '').toString().trim(),
        (deliveryAddress['district'] ?? '').toString().trim(),
        (deliveryAddress['province'] ?? '').toString().trim(),
        (deliveryAddress['postalCode'] ?? '').toString().trim(),
      ].where((part) => part.isNotEmpty).toList(growable: false);
      if (parts.isNotEmpty) {
        return parts.join(' ');
      }
    }
    final customerLocation = map['customerLocation'];
    if (customerLocation is Map) {
      final label = (customerLocation['label'] as String?)?.trim();
      if (label != null && label.isNotEmpty) {
        return label;
      }
    }
    return '';
  }

  factory DetailedOrder.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return DetailedOrder.fromMap(snapshot.data()!);
  }

  DetailedOrder copyWith({
    String? orderCode,
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
    String? driverPhone,
  }) {
    return DetailedOrder(
      orderId: orderId,
      orderCode: orderCode ?? this.orderCode,
      customerId: customerId,
      shopId: shopId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      items: items,
      totalAmount: totalAmount,
      totalItems: totalItems,
      shippingFee: shippingFee,
      orderType: orderType,
      fulfillmentType: fulfillmentType,
      shippingProvider: shippingProvider,
      shippingProviderLabel: shippingProviderLabel,
      shippingStatus: shippingStatus,
      shippingStatusLabel: shippingStatusLabel,
      deliveryAddress: deliveryAddress,
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
      driverPhone: driverPhone ?? this.driverPhone,
      shopFCMToken: shopFCMToken,
      customerFCMToken: customerFCMToken,
      driverFCMToken: driverFCMToken,
    );
  }
}
