import 'package:cloud_firestore/cloud_firestore.dart';

import 'operating_hours.dart';

class ShopOperationsSettings {
  const ShopOperationsSettings({
    required this.autoAcceptOrders,
    required this.pauseNewOrders,
    required this.operatingHours,
    this.pauseUntil,
    this.updatedAt,
  });

  final bool autoAcceptOrders;
  final bool pauseNewOrders;
  final OperatingHours operatingHours;
  final DateTime? pauseUntil;
  final DateTime? updatedAt;

  static ShopOperationsSettings defaults() {
    return ShopOperationsSettings(
      autoAcceptOrders: false,
      pauseNewOrders: false,
      operatingHours: OperatingHours.defaultWeek(),
    );
  }

  factory ShopOperationsSettings.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!snapshot.exists) {
      return ShopOperationsSettings.defaults();
    }
    return ShopOperationsSettings.fromMap(snapshot.data());
  }

  factory ShopOperationsSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return ShopOperationsSettings.defaults();
    }
    return ShopOperationsSettings(
      autoAcceptOrders: map['autoAcceptOrders'] as bool? ?? false,
      pauseNewOrders: map['pauseNewOrders'] as bool? ?? false,
      operatingHours: OperatingHours.fromMap(map['operatingHours'] as Map<String, dynamic>?),
      pauseUntil: (map['pauseUntil'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  ShopOperationsSettings copyWith({
    bool? autoAcceptOrders,
    bool? pauseNewOrders,
    OperatingHours? operatingHours,
    DateTime? pauseUntil,
    DateTime? updatedAt,
  }) {
    return ShopOperationsSettings(
      autoAcceptOrders: autoAcceptOrders ?? this.autoAcceptOrders,
      pauseNewOrders: pauseNewOrders ?? this.pauseNewOrders,
      operatingHours: operatingHours ?? this.operatingHours,
      pauseUntil: pauseUntil ?? this.pauseUntil,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'autoAcceptOrders': autoAcceptOrders,
      'pauseNewOrders': pauseNewOrders,
      'operatingHours': operatingHours.toMap(),
      if (pauseUntil != null) 'pauseUntil': Timestamp.fromDate(pauseUntil!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}
