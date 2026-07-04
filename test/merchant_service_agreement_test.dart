import 'package:flutter_test/flutter_test.dart';
import 'package:van1/data/merchant_service_agreement.dart';

void main() {
  test('merchant agreement has 16 sections and no company wording', () {
    final text = MerchantServiceAgreement.buildTemplate(
      day: '27',
      monthName: 'มิถุนายน',
      monthNumber: '06',
      year: '2569',
    );

    expect(text, contains('ผู้ให้บริการแพลตฟอร์มแว๊นตลาด'));
    expect(text, isNot(contains('บริษัท')));
    expect(text, isNot(contains('จำกัด')));

    for (var i = 1; i <= 16; i++) {
      expect(text, contains('หมวดที่ $i :'));
    }

    expect(text, contains('27/06/2569'));
    expect(text, contains('สัญญาการให้บริการแพลตฟอร์ม Van Merchant'));
  });
}
