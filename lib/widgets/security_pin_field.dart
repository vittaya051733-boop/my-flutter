import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SecurityPinField extends StatelessWidget {
  const SecurityPinField({
    super.key,
    required this.controller,
    this.label = 'รหัส PIN 6 หลัก',
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock_outline),
      ),
      onSubmitted: onSubmitted,
    );
  }
}
