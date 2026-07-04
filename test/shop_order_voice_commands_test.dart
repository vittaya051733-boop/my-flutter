import 'package:flutter_test/flutter_test.dart';
import 'package:van1/services/shop_order_voice_commands.dart';

void main() {
  group('ShopOrderVoiceCommands', () {
    test('accepts explicit accept phrases', () {
      expect(ShopOrderVoiceCommands.matchAcceptReject('รับออเดอร์'), isTrue);
      expect(ShopOrderVoiceCommands.matchAcceptReject('รับออเดอร์เข้า'), isTrue);
      expect(
        ShopOrderVoiceCommands.matchAcceptReject('รับออเดอร์ด้วยเสียง'),
        isTrue,
      );
    });

    test('rejects explicit reject phrases', () {
      expect(ShopOrderVoiceCommands.matchAcceptReject('ปฏิเสธออเดอร์'), isFalse);
      expect(
        ShopOrderVoiceCommands.matchAcceptReject('ปฏิเสธออเดอร์ด้วยเสียง'),
        isFalse,
      );
      expect(
        ShopOrderVoiceCommands.matchAcceptReject('ปฏิเสธออเดอร์ออก'),
        isFalse,
      );
    });

    test('does not treat ไม่รับออเดอร์ as accept', () {
      expect(ShopOrderVoiceCommands.matchAcceptReject('ไม่รับออเดอร์'), isFalse);
      expect(ShopOrderVoiceCommands.matchAcceptReject('ไม่รับ'), isFalse);
    });

    test('accepts standalone รับ when spoken alone', () {
      expect(ShopOrderVoiceCommands.matchAcceptReject('รับ'), isTrue);
    });

    test('returns null for unrelated speech', () {
      expect(ShopOrderVoiceCommands.matchAcceptReject('สวัสดีครับ'), isNull);
    });
  });
}
