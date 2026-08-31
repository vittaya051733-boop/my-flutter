import 'package:cloud_firestore/cloud_firestore.dart';

import 'operating_hours.dart';

class ShopOperationsSettings {
  const ShopOperationsSettings({
    required this.autoAcceptOrders,
    required this.autoListenIncomingOrders,
    required this.notifyNewOrders,
    required this.notifyLowStock,
    required this.emailMonthlyReports,
    required this.pauseNewOrders,
    required this.operatingHours,
    this.pauseUntil,
    this.updatedAt,
    this.penaltyBlocked = false,
    this.penaltyBlockReason,
  });

  final bool autoAcceptOrders;
  final bool autoListenIncomingOrders;
  final bool notifyNewOrders;
  final bool notifyLowStock;
  final bool emailMonthlyReports;
  final bool pauseNewOrders;
  final OperatingHours operatingHours;
  final DateTime? pauseUntil;
  final DateTime? updatedAt;
  final bool penaltyBlocked;
  final String? penaltyBlockReason;

  static ShopOperationsSettings defaults() {
    return ShopOperationsSettings(
      autoAcceptOrders: false,
      autoListenIncomingOrders: true,
      notifyNewOrders: true,
      notifyLowStock: true,
      emailMonthlyReports: false,
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
      autoListenIncomingOrders:
          map['autoListenIncomingOrders'] as bool? ?? true,
      notifyNewOrders: map['notifyNewOrders'] as bool? ?? true,
      notifyLowStock: map['notifyLowStock'] as bool? ?? true,
      emailMonthlyReports:
          map['emailMonthlyReports'] as bool? ??
          map['emailDailyReports'] as bool? ??
          false,
      pauseNewOrders: map['pauseNewOrders'] as bool? ?? false,
      operatingHours: OperatingHours.fromMap(map['operatingHours'] as Map<String, dynamic>?),
      pauseUntil: (map['pauseUntil'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      penaltyBlocked: map['penaltyBlocked'] as bool? ?? false,
      penaltyBlockReason: map['penaltyBlockReason'] as String?,
    );
  }

  ShopOperationsSettings copyWith({
    bool? autoAcceptOrders,
    bool? autoListenIncomingOrders,
    bool? notifyNewOrders,
    bool? notifyLowStock,
    bool? emailMonthlyReports,
    bool? pauseNewOrders,
    OperatingHours? operatingHours,
    DateTime? pauseUntil,
    DateTime? updatedAt,
    bool? penaltyBlocked,
    String? penaltyBlockReason,
  }) {
    return ShopOperationsSettings(
      autoAcceptOrders: autoAcceptOrders ?? this.autoAcceptOrders,
      autoListenIncomingOrders:
          autoListenIncomingOrders ?? this.autoListenIncomingOrders,
      notifyNewOrders: notifyNewOrders ?? this.notifyNewOrders,
      notifyLowStock: notifyLowStock ?? this.notifyLowStock,
      emailMonthlyReports: emailMonthlyReports ?? this.emailMonthlyReports,
      pauseNewOrders: pauseNewOrders ?? this.pauseNewOrders,
      operatingHours: operatingHours ?? this.operatingHours,
      pauseUntil: pauseUntil ?? this.pauseUntil,
      updatedAt: updatedAt ?? this.updatedAt,
      penaltyBlocked: penaltyBlocked ?? this.penaltyBlocked,
      penaltyBlockReason: penaltyBlockReason ?? this.penaltyBlockReason,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'autoAcceptOrders': autoAcceptOrders,
      'autoListenIncomingOrders': autoListenIncomingOrders,
      'notifyNewOrders': notifyNewOrders,
      'notifyLowStock': notifyLowStock,
      'emailMonthlyReports': emailMonthlyReports,
      'emailDailyReports': emailMonthlyReports,
      'pauseNewOrders': pauseNewOrders,
      'operatingHours': operatingHours.toMap(),
      if (pauseUntil != null) 'pauseUntil': Timestamp.fromDate(pauseUntil!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}
