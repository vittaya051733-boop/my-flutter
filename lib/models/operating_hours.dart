import 'package:flutter/material.dart';

/// Represents operating hours for a single weekday.
class OperatingDaySchedule {
  const OperatingDaySchedule({
    required this.dayKey,
    required this.isOpen,
    required this.open,
    required this.close,
  });

  final String dayKey;
  final bool isOpen;
  final TimeOfDay open;
  final TimeOfDay close;

  OperatingDaySchedule copyWith({
    bool? isOpen,
    TimeOfDay? open,
    TimeOfDay? close,
  }) {
    return OperatingDaySchedule(
      dayKey: dayKey,
      isOpen: isOpen ?? this.isOpen,
      open: open ?? this.open,
      close: close ?? this.close,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'isOpen': isOpen,
      'open': formatTime(open),
      'close': formatTime(close),
    };
  }

  static OperatingDaySchedule fromMap(String dayKey, Map<String, dynamic>? map) {
    final defaults = OperatingHours.templateForDay(dayKey);
    if (map == null) {
      return defaults;
    }
    return OperatingDaySchedule(
      dayKey: dayKey,
      isOpen: map['isOpen'] as bool? ?? defaults.isOpen,
      open: _parseTime(map['open'] as String?) ?? defaults.open,
      close: _parseTime(map['close'] as String?) ?? defaults.close,
    );
  }

  static TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String formatTime(TimeOfDay time) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(time.hour)}:${twoDigits(time.minute)}';
  }

  String formattedRange() => '${formatTime(open)} - ${formatTime(close)}';
}

class OperatingHours {
  OperatingHours({
    required this.days,
    this.note,
  });

  final Map<String, OperatingDaySchedule> days;
  final String? note;

  static const List<String> dayOrder = <String>['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const Map<String, String> dayLabels = <String, String>{
    'mon': 'จันทร์',
    'tue': 'อังคาร',
    'wed': 'พุธ',
    'thu': 'พฤหัส',
    'fri': 'ศุกร์',
    'sat': 'เสาร์',
    'sun': 'อาทิตย์',
  };

  factory OperatingHours.defaultWeek() {
    return OperatingHours(
      days: {
        for (final day in dayOrder) day: templateForDay(day),
      },
    );
  }

  OperatingHours copyWith({
    Map<String, OperatingDaySchedule>? days,
    String? note,
  }) {
    return OperatingHours(
      days: days ?? this.days,
      note: note ?? this.note,
    );
  }

  static OperatingHours fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return OperatingHours.defaultWeek();
    }
    return OperatingHours(
      days: {
        for (final day in dayOrder)
          day: OperatingDaySchedule.fromMap(day, map[day] as Map<String, dynamic>?),
      },
      note: map['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      for (final entry in dayOrder) entry: days[entry]?.toMap(),
      if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
    };
  }

  static OperatingDaySchedule templateForDay(String dayKey) {
    final bool weekend = dayKey == 'sat' || dayKey == 'sun';
    final TimeOfDay start = weekend ? const TimeOfDay(hour: 9, minute: 0) : const TimeOfDay(hour: 8, minute: 0);
    final TimeOfDay end = weekend ? const TimeOfDay(hour: 18, minute: 0) : const TimeOfDay(hour: 20, minute: 0);
    return OperatingDaySchedule(
      dayKey: dayKey,
      isOpen: true,
      open: start,
      close: end,
    );
  }

  String toReadableSummary() {
    final buffer = <String>[];
    String? activeSlot;
    final List<String> activeDays = <String>[];

    void flush() {
      if (activeSlot == null || activeDays.isEmpty) return;
      final label = _formatDayRange(activeDays);
      buffer.add('$label $activeSlot');
      activeSlot = null;
      activeDays.clear();
    }

    for (final day in dayOrder) {
      final schedule = days[day];
      if (schedule == null || !schedule.isOpen) {
        flush();
        continue;
      }
      final slotLabel = schedule.formattedRange();
      if (activeSlot == null || activeSlot != slotLabel) {
        flush();
        activeSlot = slotLabel;
      }
      activeDays.add(day);
    }
    flush();

    if (buffer.isEmpty) {
      return 'ปิดให้บริการทุกวัน';
    }

    if (note != null && note!.trim().isNotEmpty) {
      buffer.add('• ${note!.trim()}');
    }
    return buffer.join('  ');
  }

  static String _formatDayRange(List<String> dayKeys) {
    if (dayKeys.isEmpty) return '';
    if (dayKeys.length == 1) {
      return dayLabels[dayKeys.first] ?? dayKeys.first;
    }
    final firstLabel = dayLabels[dayKeys.first] ?? dayKeys.first;
    final lastLabel = dayLabels[dayKeys.last] ?? dayKeys.last;
    return '$firstLabel-${lastLabel}';
  }
}
