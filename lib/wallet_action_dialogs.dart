import 'package:flutter/material.dart';

class ReceiveMoneyDialog extends StatelessWidget {
  final String uid;
  const ReceiveMoneyDialog({required this.uid});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('รับเงิน'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('ให้ลูกค้าสแกน QR หรือกรอก UID ของคุณ'),
          // ...future: show QR, copy UID, etc.
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
      ],
    );
  }
}

class PayMoneyDialog extends StatelessWidget {
  final String uid;
  const PayMoneyDialog({required this.uid});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('จ่ายเงิน'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('กรอก UID ปลายทางและจำนวนเงิน'),
          // ...future: form for pay
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
      ],
    );
  }
}

class TransferMoneyDialog extends StatelessWidget {
  final String uid;
  const TransferMoneyDialog({required this.uid});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('โอนเงิน'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('กรอก UID ปลายทางและจำนวนเงิน'),
          // ...future: form for transfer
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
      ],
    );
  }
}