import 'package:flutter/material.dart';

class OrderManagementScreen extends StatelessWidget {
  const OrderManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการออเดอร์'),
      ),
      body: const Center(
        child: Text('ยังไม่มีออเดอร์ในขณะนี้', style: TextStyle(fontSize: 18, color: Colors.grey)),
      ),
    );
  }
}