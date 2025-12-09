import 'package:flutter/material.dart';

import '../models/operating_hours.dart';

class OperatingHoursSheet extends StatefulWidget {
  const OperatingHoursSheet({
    super.key,
    required this.initial,
  });

  final OperatingHours initial;

  @override
  State<OperatingHoursSheet> createState() => _OperatingHoursSheetState();
}

class _OperatingHoursSheetState extends State<OperatingHoursSheet> {
  late Map<String, OperatingDaySchedule> _days;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _days = {
      for (final entry in widget.initial.days.entries) entry.key: entry.value,
    };
    _noteController = TextEditingController(text: widget.initial.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(String dayKey, {required bool isOpenTime}) async {
    final schedule = _days[dayKey]!;
    final initialTime = isOpenTime ? schedule.open : schedule.close;
    final picked = await showTimePicker(context: context, initialTime: initialTime);
    if (picked == null) return;
    setState(() {
      _days[dayKey] = isOpenTime
          ? schedule.copyWith(open: picked)
          : schedule.copyWith(close: picked);
    });
  }

  void _resetToDefault() {
    setState(() {
      _days = {
        for (final day in OperatingHours.dayOrder) day: OperatingHours.templateForDay(day),
      };
      _noteController.clear();
    });
  }

  void _save() {
    Navigator.of(context).pop(
      OperatingHours(
        days: _days,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      builder: (context, controller) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('ตั้งค่าเวลาเปิด-ปิดร้าน', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: OperatingHours.dayOrder.length,
                  itemBuilder: (context, index) {
                    final dayKey = OperatingHours.dayOrder[index];
                    final schedule = _days[dayKey]!;
                    final label = OperatingHours.dayLabels[dayKey] ?? dayKey;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(
                                        schedule.isOpen ? schedule.formattedRange() : 'ปิดทำการ',
                                        style: TextStyle(color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: schedule.isOpen,
                                  onChanged: (value) {
                                    setState(() {
                                      _days[dayKey] = schedule.copyWith(isOpen: value);
                                    });
                                  },
                                ),
                              ],
                            ),
                            if (schedule.isOpen) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _TimeField(
                                      label: 'เวลาเปิด',
                                      value: schedule.open,
                                      onTap: () => _pickTime(dayKey, isOpenTime: true),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _TimeField(
                                      label: 'เวลาปิด',
                                      value: schedule.close,
                                      onTap: () => _pickTime(dayKey, isOpenTime: false),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'บันทึกเพิ่มเติม (เช่น วันหยุดนักขัตฤกษ์)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _resetToDefault,
                    icon: const Icon(Icons.refresh),
                    label: const Text('ตั้งค่าเริ่มต้น'),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('บันทึก'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;

  String get _formatted => OperatingDaySchedule.formatTime(value);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(
            '$_formatted น.',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
