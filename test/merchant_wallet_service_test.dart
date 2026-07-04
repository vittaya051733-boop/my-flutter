import 'package:flutter_test/flutter_test.dart';
import 'package:van1/services/merchant_wallet_service.dart';

void main() {
  test('MerchantWalletSnapshot.fromMap parses cloud function payload', () {
    final snapshot = MerchantWalletSnapshot.fromMap(<String, dynamic>{
      'totalCredit': 1500,
      'withdrawableCredit': 0,
      'lockedCredit': 1500,
      'canWithdraw': false,
      'isContractCancelled': false,
      'securityDepositAmount': 1000,
      'contractStatus': 'active',
      'syncedBy': 'cloud_function',
    });

    expect(snapshot.totalCredit, 1500);
    expect(snapshot.canWithdraw, isFalse);
    expect(snapshot.syncedByCloudFunction, isTrue);
    expect(snapshot.contractStatus, 'active');
  });

  test('MerchantWalletSnapshot.fromMap handles cancelled contract', () {
    final snapshot = MerchantWalletSnapshot.fromMap(<String, dynamic>{
      'totalCredit': 1500,
      'withdrawableCredit': 1500,
      'lockedCredit': 0,
      'canWithdraw': true,
      'isContractCancelled': true,
      'securityDepositAmount': 1000,
      'contractStatus': 'cancelled',
    });

    expect(snapshot.canWithdraw, isTrue);
    expect(snapshot.withdrawableCredit, 1500);
    expect(snapshot.isContractCancelled, isTrue);
  });
}
