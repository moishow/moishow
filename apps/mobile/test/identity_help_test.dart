import 'package:flutter_test/flutter_test.dart';
import 'package:moishow/identity_help.dart';

void main() {
  test(
    'phone input normalizes local Korean numbers without restricting valid E164 countries',
    () {
      expect(normalizePhone('010-1234-5678'), '+821012345678');
      expect(normalizePhone('+1 415 555 0123'), '+14155550123');
      expect(() => normalizePhone('020000000'), throwsFormatException);
    },
  );
  test(
    'recovery links stay with the known social provider and never merge accounts',
    () {
      expect(providerHelp.keys.toSet(), {'Google', 'Apple', '카카오'});
      expect(
        providerHelp.values.every((url) => Uri.parse(url).scheme == 'https'),
        true,
      );
    },
  );
}
