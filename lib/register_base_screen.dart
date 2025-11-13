import 'package:flutter/material.dart';

abstract class RegisterBaseScreen extends StatelessWidget {
  final String serviceType;
  const RegisterBaseScreen({required this.serviceType, super.key});
}
